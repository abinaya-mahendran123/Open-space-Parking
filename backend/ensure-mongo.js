const net = require('net');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

(function loadLocalEnv() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return;
  for (const raw of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq <= 0) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
})();

const HOST = '127.0.0.1';
const PORT = 27017;
const MONGOD =
  process.env.MONGOD_PATH ||
  'C:\\Users\\HP\\develop\\mongodb\\bin\\mongod.exe';
const CONFIG =
  process.env.MONGOD_CONFIG ||
  'C:\\Users\\HP\\develop\\mongodb\\mongod.cfg';

function canConnect() {
  return new Promise((resolve) => {
    const socket = net.connect({ host: HOST, port: PORT });
    socket.setTimeout(1500);
    socket.once('connect', () => {
      socket.destroy();
      resolve(true);
    });
    socket.once('timeout', () => {
      socket.destroy();
      resolve(false);
    });
    socket.once('error', () => {
      socket.destroy();
      resolve(false);
    });
  });
}

async function waitForMongo(timeoutMs = 20000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await canConnect()) return true;
    await new Promise((r) => setTimeout(r, 500));
  }
  return false;
}

async function main() {
  if (process.env.DATABASE_URL || process.env.SUPABASE_DB_URL) {
    console.log(
      'Using Supabase PostgreSQL — skipping local MongoDB (production path).',
    );
    return;
  }

  console.warn(
    'DATABASE_URL is not set. Falling back to local MongoDB for development only.\n' +
      'For production, set DATABASE_URL to your Supabase Postgres URI in backend/.env.',
  );

  if (await canConnect()) {
    console.log('MongoDB already running on 127.0.0.1:27017');
    return;
  }

  if (!fs.existsSync(MONGOD) || !fs.existsSync(CONFIG)) {
    console.error(
      'MongoDB is not running on 127.0.0.1:27017.\n' +
        'Start it first, then run npm start:\n' +
        `  ${MONGOD} --config ${CONFIG}`,
    );
    process.exit(1);
  }

  console.log('MongoDB is not running. Starting mongod...');
  const child = spawn(MONGOD, ['--config', CONFIG], {
    detached: true,
    stdio: 'ignore',
    windowsHide: true,
  });
  child.unref();

  if (!(await waitForMongo())) {
    console.error(
      'MongoDB did not start on 127.0.0.1:27017.\n' +
        `Check the log: ${path.join(path.dirname(CONFIG), 'log', 'mongod.log')}`,
    );
    process.exit(1);
  }

  console.log('MongoDB is listening on 127.0.0.1:27017');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
