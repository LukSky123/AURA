-- ============================================================================
-- AURA Migration: Real-Time Sync & Live Incident Subscriptions
-- Enables Supabase Realtime publication on incidents, live location streaming,
-- contact action events, and live status querying.
-- ============================================================================

-- 1. Add key tables to Supabase Realtime publication
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'incidents') then
      alter publication supabase_realtime add table public.incidents;
    end if;

    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'location_points') then
      alter publication supabase_realtime add table public.location_points;
    end if;

    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'incident_events') then
      alter publication supabase_realtime add table public.incident_events;
    end if;

    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'contact_actions') then
      alter publication supabase_realtime add table public.contact_actions;
    end if;
  end if;
end $$;

-- 2. Configure Full Replica Identity for rich real-time update payloads
alter table public.incidents replica identity full;
alter table public.location_points replica identity full;
alter table public.contact_actions replica identity full;

-- 3. Live Incident Status RPC
-- Efficiently packages incident state, acknowledgement metrics, and latest GPS fix
create or replace function public.get_incident_live_status(p_incident_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_incident jsonb;
  v_latest_location jsonb;
  v_ack_count int;
  v_confirm_count int;
begin
  select to_jsonb(i) into v_incident
  from public.incidents i
  where i.id = p_incident_id;

  if v_incident is null then
    return null;
  end if;

  select jsonb_build_object(
    'latitude', st_y(lp.position::geometry),
    'longitude', st_x(lp.position::geometry),
    'accuracy_m', lp.accuracy_m,
    'recorded_at', lp.recorded_at
  )
  into v_latest_location
  from public.location_points lp
  where lp.incident_id = p_incident_id
  order by lp.recorded_at desc
  limit 1;

  select count(*) into v_ack_count
  from public.contact_actions ca
  where ca.incident_id = p_incident_id and ca.action = 'acknowledged';

  select count(*) into v_confirm_count
  from public.contact_actions ca
  where ca.incident_id = p_incident_id and ca.action = 'confirmed';

  return jsonb_build_object(
    'incident', v_incident,
    'latest_location', v_latest_location,
    'acknowledged_count', coalesce(v_ack_count, 0),
    'confirmed_count', coalesce(v_confirm_count, 0)
  );
end;
$$;

grant execute on function public.get_incident_live_status(uuid) to authenticated, anon;
