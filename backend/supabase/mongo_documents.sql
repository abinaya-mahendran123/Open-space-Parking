-- Runtime document store so Express can replace Mongo without rewriting Flutter.
-- Run this in Supabase SQL Editor after schema.sql.

create table if not exists public.mongo_documents (
  collection  text not null,
  id          text not null,
  doc         jsonb not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz,
  primary key (collection, id)
);

create index if not exists idx_mongo_documents_collection
  on public.mongo_documents (collection);

create index if not exists idx_mongo_documents_gin
  on public.mongo_documents using gin (doc jsonb_path_ops);

-- Express uses the database password (postgres role), not the Flutter anon key.
-- RLS with no policies would hide nearby parking from some pooler roles.
alter table public.mongo_documents disable row level security;
revoke all on public.mongo_documents from anon, authenticated;
grant all on public.mongo_documents to postgres, service_role;
