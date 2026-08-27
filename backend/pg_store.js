const { Pool } = require('pg');
const { ObjectId } = require('mongodb');
const {
  syncNamedTable,
  deleteNamedTable,
  backfillNamedTables,
} = require('./pg_sync');
const { namedRequestToDoc, loadNamedRequests } = require('./parking_listings');

function oidHex(value) {
  if (value == null) return '';
  if (typeof value === 'string') {
    const match = value.match(/[a-fA-F0-9]{24}/);
    return match ? match[0] : value;
  }
  if (typeof value === 'object') {
    if (typeof value.toHexString === 'function') return value.toHexString();
    if (typeof value.oid === 'string') return value.oid;
    if (typeof value.$oid === 'string') return value.$oid;
  }
  return String(value);
}

function newObjectId() {
  return new ObjectId();
}

function jsonId(value) {
  const hex = oidHex(value);
  return hex ? { $oid: hex } : value;
}

function getPath(doc, key) {
  if (!key.includes('.')) return doc[key];
  return key.split('.').reduce((cur, part) => (cur == null ? cur : cur[part]), doc);
}

function isObjectIdLike(value) {
  return (
    value instanceof ObjectId ||
    (value && typeof value === 'object' && (value.$oid || typeof value.toHexString === 'function'))
  );
}

function isPlainObject(value) {
  return (
    value != null &&
    typeof value === 'object' &&
    !Array.isArray(value) &&
    !(value instanceof Date) &&
    !(value instanceof RegExp) &&
    !isObjectIdLike(value)
  );
}

function looseEq(actual, expected) {
  if (expected instanceof RegExp) {
    return expected.test(actual == null ? '' : String(actual));
  }
  if (isObjectIdLike(expected) || isObjectIdLike(actual)) {
    return oidHex(actual) === oidHex(expected);
  }
  if (actual && typeof actual === 'object' && actual.$oid && typeof expected === 'string') {
    return oidHex(actual) === expected;
  }
  return actual === expected;
}

function matchValue(actual, expected) {
  if (expected instanceof RegExp) {
    return expected.test(actual == null ? '' : String(actual));
  }
  if (isObjectIdLike(expected)) {
    return oidHex(actual) === oidHex(expected);
  }
  if (isPlainObject(expected)) {
    if (Object.prototype.hasOwnProperty.call(expected, '$exists')) {
      const shouldExist = expected.$exists !== false;
      return shouldExist
        ? actual !== undefined && actual !== null
        : actual === undefined || actual === null;
    }
    if (Object.prototype.hasOwnProperty.call(expected, '$ne')) {
      if (actual == null && expected.$ne === true) return true;
      return !looseEq(actual, expected.$ne);
    }
    if (Object.prototype.hasOwnProperty.call(expected, '$in')) {
      return expected.$in.some((item) => looseEq(actual, item));
    }
    if (Object.prototype.hasOwnProperty.call(expected, '$oid')) {
      return oidHex(actual) === expected.$oid;
    }
    if (expected.$regex) {
      const flags = expected.$options || 'i';
      return new RegExp(expected.$regex, flags).test(String(actual || ''));
    }
  }
  return looseEq(actual, expected);
}

function jsonFieldExpr(key) {
  if (!key.includes('.')) {
    return `doc->>'${key.replace(/'/g, "''")}'`;
  }
  const parts = key.split('.');
  const head = parts.slice(0, -1).join("'->'");
  const tail = parts[parts.length - 1].replace(/'/g, "''");
  return `doc->'${head}'->>'${tail}'`;
}

function isSimpleEqualityFilter(filter) {
  if (!filter || typeof filter !== 'object') return false;
  for (const [key, expected] of Object.entries(filter)) {
    if (key.startsWith('$')) return false;
    if (expected && typeof expected === 'object') {
      if (expected.$oid) continue;
      if (expected.$ne === true && key === 'isDeleted') continue;
      return false;
    }
  }
  return Object.keys(filter).length > 0;
}

function buildSimpleSqlWhere(filter, startIndex = 2) {
  const conditions = [];
  const params = [];
  let index = startIndex;

  for (const [key, expected] of Object.entries(filter)) {
    if (key.startsWith('$')) continue;

    if (key === 'isDeleted' && expected && expected.$ne === true) {
      conditions.push(`(doc->>'isDeleted' is null or doc->>'isDeleted' = 'false')`);
      continue;
    }

    // mongo_documents.id is the hex ObjectId. Stored doc._id is {"$oid": "..."}.
    // Comparing doc->>'_id' to the hex string never matches.
    if (key === '_id') {
      conditions.push(`id = $${index}`);
      params.push(oidHex(expected));
      index += 1;
      continue;
    }

    const field = jsonFieldExpr(key);
    if (expected && typeof expected === 'object' && expected.$oid) {
      conditions.push(
        `(${field} = $${index} or doc->'${key.replace(/'/g, "''")}'->>'$oid' = $${index})`,
      );
      params.push(String(expected.$oid));
      index += 1;
      continue;
    }

    if (expected == null) {
      conditions.push(`${field} is null`);
      continue;
    }

    conditions.push(`${field} = $${index}`);
    params.push(String(expected));
    index += 1;
  }

  return { conditions, params };
}

function matchFilter(doc, filter) {
  if (!filter || typeof filter !== 'object') return true;
  if (filter.$and && !filter.$and.every((part) => matchFilter(doc, part))) {
    return false;
  }
  if (filter.$or && !filter.$or.some((part) => matchFilter(doc, part))) {
    return false;
  }

  for (const [key, expected] of Object.entries(filter)) {
    if (key.startsWith('$')) continue;
    const actual = getPath(doc, key);
    if (
      key === 'email' &&
      typeof actual === 'string' &&
      typeof expected === 'string'
    ) {
      if (actual.trim().toLowerCase() !== expected.trim().toLowerCase()) {
        return false;
      }
      continue;
    }
    if (!matchValue(actual, expected)) return false;
  }
  return true;
}

function applyUpdate(doc, update) {
  const next = structuredClone(doc);
  const setDoc = update.$set || {};
  const unsetDoc = update.$unset || {};
  if (!update.$set && !update.$unset) {
    Object.assign(next, update);
  }
  for (const [key, value] of Object.entries(setDoc)) {
    next[key] = value;
  }
  for (const key of Object.keys(unsetDoc)) {
    delete next[key];
  }
  return next;
}

function toStoredDoc(doc) {
  const stored = JSON.parse(JSON.stringify(serializeForStore(doc)));
  if (!stored._id) stored._id = jsonId(newObjectId());
  if (typeof stored._id === 'string') stored._id = { $oid: stored._id };
  return stored;
}

function serializeForStore(value) {
  if (value == null) return value;
  if (value instanceof ObjectId) return { $oid: value.toHexString() };
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(serializeForStore);
  if (typeof value === 'object') {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      out[key] = serializeForStore(nested);
    }
    return out;
  }
  return value;
}

class PgCursor {
  constructor(docs) {
    this._docs = docs;
  }

  sort() {
    return this;
  }

  skip(n) {
    this._docs = this._docs.slice(n);
    return this;
  }

  limit(n) {
    this._docs = this._docs.slice(0, n);
    return this;
  }

  async toArray() {
    return this._docs.map((d) => structuredClone(d));
  }
}

class PgCollection {
  constructor(pool, name) {
    this.pool = pool;
    this.name = name;
  }

  async _all() {
    if (this.name === 'land_owner_requests') {
      try {
        return await loadNamedRequests(this.pool);
      } catch (error) {
        console.error(`Named land_owner_requests read failed: ${error.message}`);
        return [];
      }
    }
    const result = await this.pool.query(
      'select doc from mongo_documents where collection = $1',
      [this.name],
    );
    return result.rows.map((row) => row.doc);
  }

  async _save(doc) {
    const stored = toStoredDoc(doc);
    const id = oidHex(stored._id);
    stored.updatedAt = stored.updatedAt || new Date().toISOString();
    if (this.name === 'land_owner_requests') {
      await syncNamedTable(this.pool, this.name, stored);
      return stored;
    }
    await this.pool.query(
      `insert into mongo_documents (collection, id, doc, updated_at)
       values ($1, $2, $3::jsonb, now())
       on conflict (collection, id)
       do update set doc = excluded.doc, updated_at = now()`,
      [this.name, id, JSON.stringify(stored)],
    );
    await syncNamedTable(this.pool, this.name, stored);
    return stored;
  }

  async _findManySql(filter = {}) {
    if (this.name === 'land_owner_requests') return null;
    if (!isSimpleEqualityFilter(filter)) return null;

    const { conditions, params } = buildSimpleSqlWhere(filter);
    if (!conditions.length) return null;

    const result = await this.pool.query(
      `select doc from mongo_documents
       where collection = $1 and ${conditions.join(' and ')}`,
      [this.name, ...params],
    );
    return result.rows.map((row) => row.doc);
  }

  async findOne(filter = {}) {
    const sqlDocs = await this._findManySql(filter);
    if (sqlDocs) {
      return sqlDocs[0] || null;
    }
    const docs = await this._all();
    return docs.find((doc) => matchFilter(doc, filter)) || null;
  }

  find(filter = {}) {
    const sqlPromise = this._findManySql(filter);
    const promise = sqlPromise.then((sqlDocs) => {
      if (sqlDocs) return sqlDocs;
      return this._all().then((docs) =>
        docs.filter((doc) => matchFilter(doc, filter)),
      );
    });
    const cursor = {
      _p: promise,
      sort() {
        return cursor;
      },
      skip(n) {
        cursor._p = cursor._p.then((docs) => docs.slice(n));
        return cursor;
      },
      limit(n) {
        cursor._p = cursor._p.then((docs) => docs.slice(0, n));
        return cursor;
      },
      async toArray() {
        const docs = await cursor._p;
        return docs.map((d) => structuredClone(d));
      },
    };
    return cursor;
  }

  async countDocuments(filter = {}) {
    const sqlDocs = await this._findManySql(filter);
    if (sqlDocs) return sqlDocs.length;
    const docs = await this._all();
    return docs.filter((doc) => matchFilter(doc, filter)).length;
  }

  async insertOne(doc) {
    const stored = await this._save({ isDeleted: false, ...doc });
    return {
      acknowledged: true,
      insertedId: stored._id,
      insertedCount: 1,
    };
  }

  async updateOne(filter, update, options = {}) {
    const existing = await this.findOne(filter);
    if (!existing) {
      if (options.upsert) {
        const inserted = {
          ...(update.$setOnInsert || {}),
          ...(update.$set || {}),
        };
        if (!inserted._id) inserted._id = jsonId(newObjectId());
        await this._save(inserted);
        return { matchedCount: 0, modifiedCount: 0, upsertedCount: 1 };
      }
      return { matchedCount: 0, modifiedCount: 0 };
    }
    const next = applyUpdate(existing, update);
    await this._save(next);
    return { matchedCount: 1, modifiedCount: 1 };
  }

  async deleteOne(filter) {
    const existing = await this.findOne(filter);
    if (!existing) return { deletedCount: 0 };
    const id = oidHex(existing._id);
    if (this.name === 'land_owner_requests') {
      await deleteNamedTable(this.pool, this.name, id);
      return { deletedCount: 1 };
    }
    await this.pool.query(
      'delete from mongo_documents where collection = $1 and id = $2',
      [this.name, id],
    );
    await deleteNamedTable(this.pool, this.name, id);
    return { deletedCount: 1 };
  }

  async createIndex(spec = {}) {
    const keys = spec.keys || spec;
    if (!keys || typeof keys !== 'object') {
      return `${this.name}_noop`;
    }
    const entries = Object.entries(keys);
    if (entries.length !== 1) return `${this.name}_noop`;
    const [field] = entries[0][0].split('.');
    const safeField = field.replace(/[^a-zA-Z0-9_]/g, '_');
    const indexName = spec.name || `idx_${this.name}_${safeField}`;
    await this.pool.query(
      `create index if not exists ${indexName}
       on mongo_documents (collection, (doc->>'${field.replace(/'/g, "''")}'))
       where collection = '${this.name.replace(/'/g, "''")}'`,
    );
    return indexName;
  }
}

class PgDb {
  constructor(pool) {
    this.pool = pool;
    this._cache = new Map();
  }

  get rawPool() {
    return this.pool;
  }

  collection(name) {
    if (!this._cache.has(name)) {
      this._cache.set(name, new PgCollection(this.pool, name));
    }
    return this._cache.get(name);
  }
}

async function createPgDb(connectionString) {
  const pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false },
    max: 8,
  });

  await pool.query(`
    create table if not exists mongo_documents (
      collection  text not null,
      id          text not null,
      doc         jsonb not null,
      created_at  timestamptz not null default now(),
      updated_at  timestamptz,
      primary key (collection, id)
    );
    create index if not exists idx_mongo_documents_collection
      on mongo_documents (collection);
    create index if not exists idx_mongo_documents_doc_gin
      on mongo_documents using gin (doc jsonb_path_ops);
    create index if not exists idx_mongo_documents_users_email
      on mongo_documents ((doc->>'email'))
      where collection = 'users';
    create index if not exists idx_mongo_documents_bookings_listing
      on mongo_documents ((doc->>'parkingListingId'))
      where collection = 'bookings';
    create index if not exists idx_mongo_documents_bookings_qr
      on mongo_documents ((doc->>'qrPayload'))
      where collection = 'bookings';
    create index if not exists idx_mongo_documents_bookings_ref
      on mongo_documents ((doc->>'bookingRef'))
      where collection = 'bookings';
    alter table mongo_documents disable row level security;
  `);

  await backfillNamedTables(pool);
  const pgDb = new PgDb(pool);
  pgDb.pool = pool;
  return pgDb;
}

module.exports = { createPgDb, PgCursor };
