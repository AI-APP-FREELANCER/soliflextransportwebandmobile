-- Soliflex Transport: PostgreSQL schema (baseline)
-- Run this against your database (DigitalOcean managed Postgres) once.

create table if not exists users (
  user_id serial primary key,
  full_name text not null,
  password_hash text not null,
  department text not null,
  role text not null
);

create unique index if not exists users_full_name_department_uq
  on users (lower(full_name), lower(department));

create table if not exists vendors (
  vendor_id int primary key,
  name text not null,
  kl text,
  pick_up_by_sol_below_3000_kgs text default '0',
  dropped_by_vendor_below_3000_kgs text default '0',
  pick_up_by_sol_between_3000_to_5999_kgs text default '0',
  dropped_by_vendor_below_5999_kgs text default '0',
  pick_up_by_sol_above_6000_kgs text default '0',
  dropped_by_vendor_above_6000_kgs text default '0',
  toll_charges text default '0'
);

create table if not exists vehicles (
  vehicle_id int primary key,
  vehicle_number text not null,
  type text,
  capacity_kg int default 0,
  vehicle_type text,
  vendor_vehicle text,
  status text default 'Free'
);

create table if not exists rfqs (
  rfq_id serial primary key,
  user_id int not null references users(user_id) on delete cascade,
  source text not null,
  destination text not null,
  material_weight int not null,
  material_type text not null,
  vehicle_id int null references vehicles(vehicle_id),
  vehicle_number text default '',
  status text not null,
  total_cost int default 0,
  created_at text,
  approved_by int null references users(user_id),
  approved_at text,
  rejected_at text,
  rejection_reason text,
  started_at text,
  completed_at text
);

create index if not exists rfqs_user_id_idx on rfqs(user_id);
create index if not exists rfqs_status_idx on rfqs(status);

create table if not exists orders (
  order_id text primary key,
  user_id int not null references users(user_id) on delete restrict,
  source text,
  destination text,
  material_weight int default 0,
  material_type text,
  trip_type text,
  vehicle_id int null references vehicles(vehicle_id),
  vehicle_number text default '',
  order_status text,
  created_at text,
  creator_department text,
  creator_user_id int null references users(user_id),
  creator_name text,
  trip_segments text,
  is_amended text default 'No',
  original_trip_type text,
  order_category text,
  total_weight int default 0,
  total_invoice_amount int default 0,
  total_toll_charges int default 0,
  amendment_requested_by text,
  amendment_requested_department text,
  amendment_requested_at text,
  last_amended_by_user_id int null references users(user_id),
  last_amended_timestamp text,
  amendment_history text,
  original_total_weight text,
  original_total_invoice_amount text,
  original_total_toll_charges text,
  original_segment_count text,
  approved_timestamp text,
  approved_by_member text,
  approved_by_department text,
  vehicle_started_at_timestamp text,
  vehicle_started_from_location text,
  security_entry_timestamp text,
  security_entry_member_name text,
  security_entry_checkpoint_location text,
  stores_validation_timestamp text,
  vehicle_exited_timestamp text,
  exit_approved_by_timestamp text,
  exit_approved_by_member_name text
);

create index if not exists orders_created_at_idx on orders(created_at);
create index if not exists orders_user_id_idx on orders(user_id);

create table if not exists notifications (
  notification_id serial primary key,
  order_id text,
  recipient_department text not null,
  notification_type text not null,
  message text not null,
  status text default 'unread',
  created_at text,
  related_user_id int null references users(user_id)
);

create index if not exists notifications_dept_idx on notifications(recipient_department);
create index if not exists notifications_status_idx on notifications(status);

