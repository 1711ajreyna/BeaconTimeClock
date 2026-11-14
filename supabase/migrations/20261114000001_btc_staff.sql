-- STAGING STARTER ONLY. Review migrations and run integration/security tests
-- before applying to a production database with real payroll data.
create table if not exists public.btc_staff_profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  employee_id uuid,
  name text not null check (length(btrim(name)) between 1 and 120),
  email text not null,
  employee_number text not null,
  role text not null check (role in ('employee','supervisor','hr','admin')),
  department text check (department in ('electrical','machine_shop','metals','plastics','litho')),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint btc_role_department check (
    (role in ('employee','supervisor') and department is not null)
    or (role in ('hr','admin') and department is null)
  ),
  constraint btc_employee_id_check check (
    (role='employee' and employee_id is not null)
    or role != 'employee'
  )
);
create unique index if not exists btc_staff_email_unique
  on public.btc_staff_profiles (lower(email));
create unique index if not exists btc_staff_number_unique
  on public.btc_staff_profiles (upper(employee_number));
create index if not exists btc_staff_department_idx
  on public.btc_staff_profiles (department) where is_active;

alter table public.btc_staff_profiles enable row level security;
-- No client-side write policy. All writes require a trusted Edge Function
-- which verifies the user's JWT and checks staff role/department on EVERY call.
revoke all on public.btc_staff_profiles from anon;
revoke all on public.btc_staff_profiles from authenticated;
grant select on public.btc_staff_profiles to authenticated;
-- Self profile is the only direct authenticated read; staff rosters are served
-- by staff-list after verifying permissions (no cross-department leakage).
create policy btc_read_self_only on public.btc_staff_profiles
  for select to authenticated
  using ((select auth.uid()) = id);
