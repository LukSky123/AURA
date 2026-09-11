create extension if not exists pgcrypto;
create extension if not exists postgis;

create type public.incident_kind as enum ('gunshot', 'glass_break', 'collision', 'explosion', 'manual_sos');
create type public.incident_status as enum ('countdown', 'dispatched', 'acknowledged', 'resolved', 'cancelled', 'expired');
create type public.contact_action as enum ('acknowledged', 'confirmed');

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  phone_e164 text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  push_token text,
  model_version text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table public.trusted_contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  display_name text not null,
  phone_e164 text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique(owner_id, phone_e164)
);
create unique index trusted_contacts_limit on public.trusted_contacts(owner_id, id) where enabled;

create or replace function public.enforce_contact_limit() returns trigger language plpgsql as $$
begin
  if new.enabled and (select count(*) from public.trusted_contacts where owner_id = new.owner_id and enabled and id <> coalesce(new.id, gen_random_uuid())) >= 5 then
    raise exception 'AURA supports at most five enabled trusted contacts';
  end if;
  return new;
end; $$;
create trigger trusted_contacts_max_five before insert or update of enabled, owner_id on public.trusted_contacts for each row execute function public.enforce_contact_limit();

create table public.incidents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  kind public.incident_kind not null,
  status public.incident_status not null default 'countdown',
  confidence numeric(4,3) check (confidence is null or confidence between 0 and 1),
  model_version text,
  started_at timestamptz not null default now(),
  dispatched_at timestamptz,
  resolved_at timestamptz,
  expires_at timestamptz not null default now() + interval '24 hours',
  confirmed_for_routing boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index incidents_owner_created_idx on public.incidents(owner_id, created_at desc);

create table public.incident_events (
  id bigint generated always as identity primary key,
  incident_id uuid not null references public.incidents(id) on delete cascade,
  actor_user_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.location_points (
  id bigint generated always as identity primary key,
  incident_id uuid not null references public.incidents(id) on delete cascade,
  recorded_at timestamptz not null default now(),
  position geography(point, 4326) not null,
  accuracy_m numeric check (accuracy_m is null or accuracy_m >= 0)
);
create index location_points_incident_time_idx on public.location_points(incident_id, recorded_at desc);

create or replace function public.insert_location_point(p_incident_id uuid, p_longitude numeric, p_latitude numeric, p_accuracy_m numeric, p_recorded_at timestamptz) returns void language sql security definer set search_path = public as $$
  insert into public.location_points (incident_id, position, accuracy_m, recorded_at)
  values (p_incident_id, st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography, p_accuracy_m, p_recorded_at);
$$;
revoke all on function public.insert_location_point(uuid, numeric, numeric, numeric, timestamptz) from public;
grant execute on function public.insert_location_point(uuid, numeric, numeric, numeric, timestamptz) to service_role;

create table public.incident_contact_links (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.incidents(id) on delete cascade,
  contact_id uuid not null references public.trusted_contacts(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique(incident_id, contact_id)
);

create table public.contact_actions (
  id bigint generated always as identity primary key,
  incident_id uuid not null references public.incidents(id) on delete cascade,
  contact_id uuid not null references public.trusted_contacts(id) on delete cascade,
  action public.contact_action not null,
  created_at timestamptz not null default now()
);

create table public.training_samples (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  incident_id uuid references public.incidents(id) on delete set null,
  storage_path text not null unique,
  model_version text not null,
  confidence numeric(4,3) check (confidence between 0 and 1),
  consented_at timestamptz not null,
  encrypted boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.route_risk_cells (
  cell_id text primary key,
  observed_on date not null,
  confirmed_incident_count integer not null check (confirmed_incident_count >= 0),
  risk_score numeric not null check (risk_score >= 0),
  updated_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.trusted_contacts enable row level security;
alter table public.incidents enable row level security;
alter table public.incident_events enable row level security;
alter table public.location_points enable row level security;
alter table public.training_samples enable row level security;
alter table public.route_risk_cells enable row level security;

create policy "profile owner" on public.profiles for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "device owner" on public.devices for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "contact owner" on public.trusted_contacts for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "incident owner" on public.incidents for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "event incident owner" on public.incident_events for select using (exists (select 1 from public.incidents i where i.id = incident_id and i.owner_id = auth.uid()));
create policy "location incident owner" on public.location_points for all using (exists (select 1 from public.incidents i where i.id = incident_id and i.owner_id = auth.uid())) with check (exists (select 1 from public.incidents i where i.id = incident_id and i.owner_id = auth.uid()));
create policy "sample owner" on public.training_samples for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "authenticated aggregate risk only" on public.route_risk_cells for select to authenticated using (true);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
create trigger profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
create trigger incidents_updated before update on public.incidents for each row execute function public.set_updated_at();

-- Called by a scheduled Supabase job. Training samples are not deleted here;
-- their explicit consent lifecycle is handled separately.
create or replace function public.purge_expired_safety_data() returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.location_points where recorded_at < now() - interval '90 days';
  delete from public.incident_events where created_at < now() - interval '90 days';
  delete from public.incidents where created_at < now() - interval '90 days';
  update public.incidents set status = 'expired' where status not in ('resolved', 'cancelled', 'expired') and expires_at < now();
  update public.incident_contact_links set revoked_at = coalesce(revoked_at, now()) where expires_at < now();
end; $$;

-- Scheduled daily. It publishes only 250 m cells, never raw incident points.
create or replace function public.rebuild_route_risk_cells() returns void language plpgsql security definer set search_path = public as $$
begin
  truncate public.route_risk_cells;
  insert into public.route_risk_cells (cell_id, observed_on, confirmed_incident_count, risk_score, updated_at)
  select
    floor(st_x(st_transform(lp.position::geometry, 3857)) / 250)::text || ':' || floor(st_y(st_transform(lp.position::geometry, 3857)) / 250)::text,
    current_date,
    count(distinct i.id),
    sum(exp(-extract(epoch from (now() - i.started_at)) / 2592000.0)),
    now()
  from public.location_points lp
  join public.incidents i on i.id = lp.incident_id
  where i.confirmed_for_routing and i.started_at >= now() - interval '30 days'
  group by 1;
end; $$;
