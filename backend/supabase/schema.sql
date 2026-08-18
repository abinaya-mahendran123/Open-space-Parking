-- Open Space Parking — Supabase PostgreSQL schema
-- Paste this entire file into Supabase: SQL Editor → New query → Run
--
-- IDs stay TEXT (Mongo ObjectId hex, 24 chars) so the Flutter app
-- does not need new IDs or a rewrite. Nested Mongo objects use jsonb.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1. USERS  (login: email/password, phone OTP, Google)
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id              text primary key,
  email           text not null,
  phone           text,
  display_name    text not null default '',
  role            text not null,
  -- admin | landOwner | vehicleOwner | employee | security
  auth_provider   text,                 -- password | phone | google
  google_id       text,
  password_hash   text,
  password_salt   text,
  is_deleted      boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz,
  deleted_at      timestamptz
);

create unique index if not exists idx_users_email
  on public.users (lower(email));
create unique index if not exists idx_users_phone
  on public.users (phone)
  where phone is not null and phone <> '';
create index if not exists idx_users_role on public.users (role);

-- ---------------------------------------------------------------------------
-- 2. EMPLOYEES  (field staff portal)
-- ---------------------------------------------------------------------------
create table if not exists public.employees (
  id                    text primary key,
  full_name             text not null,
  email                 text not null,
  phone                 text not null default '',
  role_title            text not null default 'Field Employee',
  is_active             boolean not null default true,
  assigned_ticket_count integer not null default 0,
  password_hash         text,
  password_salt         text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz
);

create unique index if not exists idx_employees_email
  on public.employees (lower(email));
create index if not exists idx_employees_active on public.employees (is_active);

-- ---------------------------------------------------------------------------
-- 3. VEHICLE OWNER PROFILES
-- ---------------------------------------------------------------------------
create table if not exists public.vehicle_owner_profiles (
  id               text primary key,
  vehicle_owner_id text not null,
  profile          jsonb not null default '{}'::jsonb,
  -- { fullName, phone, email, address, vehicleNumber, vehicleModel }
  created_at       timestamptz not null default now(),
  updated_at       timestamptz
);

create unique index if not exists idx_vehicle_owner_profiles_user
  on public.vehicle_owner_profiles (vehicle_owner_id);

-- ---------------------------------------------------------------------------
-- 4. LAND OWNER PROFILES + PAYOUT
-- ---------------------------------------------------------------------------
create table if not exists public.land_owner_profiles (
  id             text primary key,
  owner_id       text not null,
  owner_details  jsonb not null default '{}'::jsonb,
  -- { fullName, phone, email, address, aadhaarNumber }
  payout         jsonb,
  -- { accountHolderName, upiId, bankAccountNumber, ifscCode, razorpayLinkedAccountId }
  created_at     timestamptz not null default now(),
  updated_at     timestamptz
);

create unique index if not exists idx_land_owner_profiles_owner
  on public.land_owner_profiles (owner_id);

-- ---------------------------------------------------------------------------
-- 5. LAND OWNER REQUESTS / TICKETS / PARKING LISTINGS
--    (verified tickets are the public parking list)
-- ---------------------------------------------------------------------------
create table if not exists public.land_owner_requests (
  id                      text primary key,
  ticket_id               text not null,
  owner_id                text not null,
  request_type            text not null,
  -- buildParking | existingParking
  status                  text not null default 'submitted',
  -- submitted | assigned | inProgress | completed | rejected | approved
  owner_details           jsonb not null default '{}'::jsonb,
  documents               jsonb not null default '{}'::jsonb,
  land_details            jsonb not null default '{}'::jsonb,
  -- gpsLatitude, gpsLongitude, areaSqFt, roadAccess, drainage, flood, boundary, cctv, landAddress
  parking_preferences     jsonb,
  -- priority, parkingType, numberOfCars, hourlyRate
  assigned_employee_id    text,
  assigned_employee_name  text,
  documents_verified      boolean not null default false,
  admin_notes             text,
  reviewed_at             timestamptz,
  reviewed_by             text,
  construction_progress   integer not null default 0,
  navigation_notes        text,
  submitted_at            timestamptz not null default now(),
  completed_at            timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz,
  is_deleted              boolean not null default false
);

create unique index if not exists idx_land_owner_requests_ticket
  on public.land_owner_requests (ticket_id);
create index if not exists idx_land_owner_requests_owner
  on public.land_owner_requests (owner_id);
create index if not exists idx_land_owner_requests_status
  on public.land_owner_requests (status);
create index if not exists idx_land_owner_requests_employee
  on public.land_owner_requests (assigned_employee_id);

-- ---------------------------------------------------------------------------
-- 6. BOOKINGS / QR SESSIONS
-- ---------------------------------------------------------------------------
create table if not exists public.bookings (
  id                     text primary key,
  booking_ref            text not null,
  vehicle_owner_id       text not null,
  parking_listing_id     text not null,
  ticket_id              text not null,
  parking_type           text not null,
  vehicle_number         text not null,
  vehicle_model          text,
  start_date_time        timestamptz not null,
  end_date_time          timestamptz not null,
  duration_hours         numeric not null default 0,
  hourly_rate            numeric not null default 0,
  total_price            numeric not null default 0,
  status                 text not null,
  -- confirmed | active | completed | cancelled
  parking_address        text,
  parking_name           text,
  assigned_slot          integer,
  qr_payload             text,
  session_id             text,
  checked_in_at          timestamptz,
  checked_out_at         timestamptz,
  actual_duration_hours  numeric,
  amount_due             numeric,
  paid_amount            numeric,
  payment_id             text,
  paid_at                timestamptz,
  payment_method         text,
  razorpay_order_id      text,
  split                  jsonb,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz
);

create unique index if not exists idx_bookings_ref on public.bookings (booking_ref);
create unique index if not exists idx_bookings_qr
  on public.bookings (qr_payload)
  where qr_payload is not null and qr_payload <> '';
create index if not exists idx_bookings_owner on public.bookings (vehicle_owner_id);
create index if not exists idx_bookings_listing on public.bookings (parking_listing_id);
create index if not exists idx_bookings_status on public.bookings (status);

-- ---------------------------------------------------------------------------
-- 7. PAYMENTS (Razorpay)
-- ---------------------------------------------------------------------------
create table if not exists public.payments (
  id                   text primary key,
  booking_id           text not null,
  booking_ref          text,
  vehicle_owner_id     text,
  amount               numeric not null,
  method               text,
  status               text not null default 'paid',
  split                jsonb,
  razorpay_order_id    text,
  razorpay_payment_id  text,
  razorpay_signature   text,
  created_at           timestamptz not null default now()
);

create index if not exists idx_payments_booking on public.payments (booking_id);
create unique index if not exists idx_payments_razorpay
  on public.payments (razorpay_payment_id)
  where razorpay_payment_id is not null;

-- ---------------------------------------------------------------------------
-- 8. REVIEWS
-- ---------------------------------------------------------------------------
create table if not exists public.parking_reviews (
  id                 text primary key,
  parking_listing_id text not null,
  vehicle_owner_id   text not null,
  reviewer_name      text not null default '',
  rating             integer not null check (rating between 1 and 5),
  comment            text not null default '',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz
);

create unique index if not exists idx_reviews_owner_listing
  on public.parking_reviews (parking_listing_id, vehicle_owner_id);

-- ---------------------------------------------------------------------------
-- 9. FAVORITES
-- ---------------------------------------------------------------------------
create table if not exists public.vehicle_owner_favorites (
  id                 text primary key,
  vehicle_owner_id   text not null,
  parking_listing_id text not null,
  created_at         timestamptz not null default now()
);

create unique index if not exists idx_favorites_unique
  on public.vehicle_owner_favorites (vehicle_owner_id, parking_listing_id);

-- ---------------------------------------------------------------------------
-- 10. NOTIFICATIONS (role-specific tables match current Mongo collections)
-- ---------------------------------------------------------------------------
create table if not exists public.vehicle_owner_notifications (
  id                text primary key,
  vehicle_owner_id  text not null,
  title             text not null,
  message           text not null,
  booking_ref       text,
  is_read           boolean not null default false,
  created_at        timestamptz not null default now()
);
create index if not exists idx_vo_notifications_owner
  on public.vehicle_owner_notifications (vehicle_owner_id, created_at desc);

create table if not exists public.land_owner_notifications (
  id          text primary key,
  owner_id    text not null,
  title       text not null,
  message     text not null,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists idx_lo_notifications_owner
  on public.land_owner_notifications (owner_id, created_at desc);

create table if not exists public.employee_notifications (
  id           text primary key,
  employee_id  text not null,
  title        text not null,
  message      text not null,
  ticket_id    text,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);
create index if not exists idx_emp_notifications_employee
  on public.employee_notifications (employee_id, created_at desc);

-- Razorpay / backend also writes a generic notifications collection
create table if not exists public.notifications (
  id             text primary key,
  recipient_id   text,
  recipient_type text,
  title          text not null,
  message        text not null,
  is_read        boolean not null default false,
  created_at     timestamptz not null default now(),
  doc            jsonb
);

-- ---------------------------------------------------------------------------
-- 11. EMPLOYEE CONSTRUCTION
-- ---------------------------------------------------------------------------
create table if not exists public.quotations (
  id             text primary key,
  ticket_id      text not null,
  request_id     text not null,
  employee_id    text not null,
  amount         numeric not null default 0,
  materials_cost numeric not null default 0,
  labor_cost     numeric not null default 0,
  timeline_days  integer not null default 0,
  description    text not null default '',
  created_at     timestamptz not null default now()
);
create index if not exists idx_quotations_ticket on public.quotations (ticket_id);

create table if not exists public.construction_progress (
  id                text primary key,
  ticket_id         text not null,
  request_id        text not null,
  employee_id       text not null,
  progress_percent  integer not null check (progress_percent between 0 and 100),
  notes             text not null default '',
  created_at        timestamptz not null default now()
);
create index if not exists idx_construction_progress_request
  on public.construction_progress (request_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 12. OPTIONAL CANONICAL TABLES (exist in registry; keep empty if unused)
-- ---------------------------------------------------------------------------
create table if not exists public.documents (
  id          text primary key,
  owner_id    text,
  url         text,
  category    text,
  created_at  timestamptz not null default now(),
  doc         jsonb
);

create table if not exists public.parking_spaces (
  id          text primary key,
  created_at  timestamptz not null default now(),
  doc         jsonb
);

-- ---------------------------------------------------------------------------
-- 13. ROW LEVEL SECURITY
-- Express uses the database password (postgres role), not the Flutter anon key.
-- Keep named tables readable in the Supabase Table Editor.
alter table public.users disable row level security;
alter table public.employees disable row level security;
alter table public.vehicle_owner_profiles disable row level security;
alter table public.land_owner_profiles disable row level security;
alter table public.land_owner_requests disable row level security;
alter table public.bookings disable row level security;
alter table public.payments disable row level security;
alter table public.parking_reviews disable row level security;
alter table public.vehicle_owner_favorites disable row level security;
alter table public.vehicle_owner_notifications disable row level security;
alter table public.land_owner_notifications disable row level security;
alter table public.employee_notifications disable row level security;
alter table public.notifications disable row level security;
alter table public.quotations disable row level security;
alter table public.construction_progress disable row level security;
alter table public.documents disable row level security;
alter table public.parking_spaces disable row level security;

revoke all on all tables in schema public from anon, authenticated;
grant all on all tables in schema public to postgres, service_role;
