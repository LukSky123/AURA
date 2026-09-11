-- Migration: 202609110001_monetization_schema.sql
-- Description: Monetization schema for AURA (Free, Pro, Family tiers, Termii SMS protection, Paystack & RevenueCat tracking, sponsorships)

create type public.subscription_tier as enum ('free', 'pro', 'family');
create type public.subscription_status as enum ('active', 'past_due', 'canceled', 'incomplete', 'trialing', 'expired');
create type public.payment_provider as enum ('revenuecat', 'paystack', 'free', 'sponsorship');

-- 1. Subscriptions table
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  tier public.subscription_tier not null default 'free',
  status public.subscription_status not null default 'active',
  provider public.payment_provider not null default 'free',
  provider_sub_id text,
  current_period_start timestamptz not null default now(),
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index subscriptions_user_status_idx on public.subscriptions(user_id, status);

-- 2. Family members table (up to 5 linked accounts for Family tier)
create table public.family_members (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  member_user_id uuid references public.profiles(id) on delete set null,
  member_phone_e164 text not null,
  invitation_accepted boolean not null default false,
  created_at timestamptz not null default now(),
  unique(owner_id, member_phone_e164)
);
create index family_members_owner_idx on public.family_members(owner_id);
create index family_members_phone_idx on public.family_members(member_phone_e164);

-- Trigger to limit family members to max 4 additional members (total 5 circle members)
create or replace function public.enforce_family_member_limit() returns trigger language plpgsql as $$
begin
  if (select count(*) from public.family_members where owner_id = new.owner_id and id <> coalesce(new.id, gen_random_uuid())) >= 4 then
    raise exception 'AURA Family tier allows up to 4 additional linked members (5 total)';
  end if;
  return new;
end; $$;
create trigger family_members_max_four before insert on public.family_members for each row execute function public.enforce_family_member_limit();

-- 3. SMS Usage tracking (for Free tier 2 promotional SMS/month guard)
create table public.sms_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  incident_id uuid references public.incidents(id) on delete set null,
  period_month text not null default to_char(now(), 'YYYY-MM'),
  dispatched_at timestamptz not null default now()
);
create index sms_usage_user_month_idx on public.sms_usage(user_id, period_month);

-- 4. Payment transactions table
create table public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  reference text unique not null,
  amount_kobo bigint not null,
  currency text not null default 'NGN',
  channel text,
  provider public.payment_provider not null,
  status text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index payment_transactions_user_idx on public.payment_transactions(user_id);
create index payment_transactions_ref_idx on public.payment_transactions(reference);

-- 5. Sponsorships ("Protect a Loved One")
create table public.sponsorships (
  id uuid primary key default gen_random_uuid(),
  sponsor_email text,
  sponsor_name text,
  target_phone_e164 text not null,
  tier public.subscription_tier not null default 'pro',
  duration_months integer not null default 1,
  payment_reference text unique not null,
  applied_user_id uuid references public.profiles(id) on delete set null,
  applied_at timestamptz,
  created_at timestamptz not null default now()
);
create index sponsorships_target_phone_idx on public.sponsorships(target_phone_e164);

-- 6. Helper function: Get effective user tier
create or replace function public.get_effective_user_tier(p_user_id uuid)
returns public.subscription_tier language plpgsql security definer set search_path = public as $$
declare
  v_tier public.subscription_tier;
  v_user_phone text;
begin
  -- 1. Check direct active subscription
  select tier into v_tier
  from public.subscriptions
  where user_id = p_user_id
    and status = 'active'
    and (current_period_end is null or current_period_end > now())
  order by case when tier = 'family' then 1 when tier = 'pro' then 2 else 3 end
  limit 1;

  if v_tier is not null and v_tier in ('pro', 'family') then
    return v_tier;
  end if;

  -- 2. Check family link (if user is part of an active family plan)
  select phone_e164 into v_user_phone from public.profiles where id = p_user_id;

  if v_user_phone is not null then
    if exists (
      select 1
      from public.family_members fm
      join public.subscriptions s on s.user_id = fm.owner_id
      where (fm.member_user_id = p_user_id or fm.member_phone_e164 = v_user_phone)
        and s.tier = 'family'
        and s.status = 'active'
        and (s.current_period_end is null or s.current_period_end > now())
    ) then
      return 'family'::public.subscription_tier;
    end if;
  end if;

  return 'free'::public.subscription_tier;
end; $$;

-- 7. Helper function: Get contact limit
create or replace function public.get_user_contact_limit(p_user_id uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_tier public.subscription_tier;
begin
  v_tier := public.get_effective_user_tier(p_user_id);
  if v_tier in ('pro', 'family') then
    return 5;
  else
    return 2;
  end if;
end; $$;

-- 8. Updated contact limit enforcement trigger
create or replace function public.enforce_contact_limit() returns trigger language plpgsql as $$
declare
  v_limit integer;
  v_current_count integer;
begin
  if new.enabled then
    v_limit := public.get_user_contact_limit(new.owner_id);
    select count(*) into v_current_count
    from public.trusted_contacts
    where owner_id = new.owner_id
      and enabled
      and id <> coalesce(new.id, gen_random_uuid());

    if v_current_count >= v_limit then
      if v_limit = 2 then
        raise exception 'AURA Free tier supports at most 2 enabled trusted contacts. Upgrade to AURA Pro or Family to add up to 5.';
      else
        raise exception 'AURA supports at most 5 enabled trusted contacts.';
      end if;
    end if;
  end if;
  return new;
end; $$;

-- 9. Helper function: Check cloud SMS allowance
create or replace function public.check_cloud_sms_allowance(p_user_id uuid)
returns table(can_send_cloud_sms boolean, remaining_credits integer, current_tier public.subscription_tier)
language plpgsql security definer set search_path = public as $$
declare
  v_tier public.subscription_tier;
  v_month text;
  v_used integer;
begin
  v_tier := public.get_effective_user_tier(p_user_id);
  if v_tier in ('pro', 'family') then
    return query select true, 999999, v_tier;
    return;
  end if;

  v_month := to_char(now(), 'YYYY-MM');
  select count(*)::integer into v_used
  from public.sms_usage
  where user_id = p_user_id and period_month = v_month;

  if v_used < 2 then
    return query select true, (2 - v_used), v_tier;
  else
    return query select false, 0, v_tier;
  end if;
end; $$;

-- 10. Record cloud SMS usage
create or replace function public.record_cloud_sms_usage(p_user_id uuid, p_incident_id uuid)
returns void language sql security definer set search_path = public as $$
  insert into public.sms_usage (user_id, incident_id, period_month)
  values (p_user_id, p_incident_id, to_char(now(), 'YYYY-MM'));
$$;

-- 11. Row Level Security
alter table public.subscriptions enable row level security;
alter table public.family_members enable row level security;
alter table public.sms_usage enable row level security;
alter table public.payment_transactions enable row level security;
alter table public.sponsorships enable row level security;

create policy "subscriptions read owner" on public.subscriptions
  for select using (auth.uid() = user_id);

create policy "family members read owner and members" on public.family_members
  for select using (
    auth.uid() = owner_id or
    auth.uid() = member_user_id or
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.phone_e164 = member_phone_e164)
  );

create policy "family members modify owner only" on public.family_members
  for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

create policy "sms usage read owner" on public.sms_usage
  for select using (auth.uid() = user_id);

create policy "transactions read owner" on public.payment_transactions
  for select using (auth.uid() = user_id);

create policy "sponsorships read public target or sponsor" on public.sponsorships
  for select using (
    sponsor_email = auth.jwt()->>'email' or
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.phone_e164 = target_phone_e164)
  );

-- Function to apply any pending sponsorships upon profile creation or phone update
create or replace function public.claim_pending_sponsorships() returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_sponsor record;
begin
  for v_sponsor in
    select * from public.sponsorships
    where target_phone_e164 = new.phone_e164 and applied_at is null
  loop
    -- Create subscription for the user
    insert into public.subscriptions (
      user_id,
      tier,
      status,
      provider,
      provider_sub_id,
      current_period_start,
      current_period_end
    ) values (
      new.id,
      v_sponsor.tier,
      'active',
      'sponsorship',
      v_sponsor.payment_reference,
      now(),
      now() + (v_sponsor.duration_months || ' months')::interval
    );

    update public.sponsorships
    set applied_user_id = new.id, applied_at = now()
    where id = v_sponsor.id;
  end loop;
  return new;
end; $$;

create trigger profiles_claim_sponsorship after insert or update of phone_e164 on public.profiles
  for each row execute function public.claim_pending_sponsorships();
