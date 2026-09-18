-- Serge Finance — Supabase schema (SPEC §6)
-- Run in the Supabase SQL editor. Safe to re-run: drops nothing, uses "if not exists"
-- where possible. BEFORE running the SEED section at the bottom, create your user:
-- Dashboard → Authentication → Users → Add user (email + password, confirm email).

-- ============================================================
-- Tables
-- ============================================================

create table if not exists cuentas (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users (id),
  nombre        text not null,
  tipo          text not null check (tipo in ('efectivo', 'debito', 'credito')),
  saldo_inicial numeric(12,2) not null default 0,
  activa        boolean not null default true,
  creado        timestamptz not null default now(),
  unique (user_id, nombre)
);

create table if not exists categorias (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id),
  nombre       text not null,
  icono        text not null default 'help',  -- slug of an inline SVG icon in the app
  discrecional boolean not null default false,
  orden        int not null default 0,
  creado       timestamptz not null default now(),
  unique (user_id, nombre)
);

create table if not exists metas (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id),
  nombre         text not null,
  objetivo       numeric(12,2) not null,
  fecha_objetivo date,
  activa         boolean not null default true,
  creado         timestamptz not null default now()
);

create table if not exists movimientos (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id),
  fecha        date not null default (now() at time zone 'America/Chihuahua')::date,
  monto        numeric(12,2) not null,          -- negative = expense, positive = income
  cuenta_id    uuid references cuentas (id),
  categoria_id uuid references categorias (id), -- null = inbox
  nota         text,
  comercio     text,
  origen       text not null default 'app'
                 check (origen in ('apple_pay', 'sms', 'manual', 'app', 'recurrente')),
  tipo         text not null default 'gasto'
                 check (tipo in ('gasto', 'ingreso', 'ahorro', 'ajuste')),
  meta_id      uuid references metas (id),
  creado       timestamptz not null default now()
);

create table if not exists presupuestos (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id),
  mes          text not null check (mes ~ '^\d{4}-\d{2}$'),  -- YYYY-MM
  categoria_id uuid not null references categorias (id),
  limite       numeric(12,2) not null,
  creado       timestamptz not null default now(),
  unique (user_id, mes, categoria_id)
);

create table if not exists recurrentes (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id),
  nombre       text not null,
  monto        numeric(12,2) not null,
  dia          int not null check (dia between 1 and 31),
  categoria_id uuid references categorias (id),
  cuenta_id    uuid references cuentas (id),
  activa       boolean not null default true,
  creado       timestamptz not null default now()
);

create table if not exists semana_metas (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id),
  nombre         text not null,
  veces_objetivo int not null check (veces_objetivo > 0),
  activa         boolean not null default true,
  creado         timestamptz not null default now()
);

create table if not exists semana_registro (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id),
  semana         text not null check (semana ~ '^\d{4}-W\d{2}$'),  -- ISO week, e.g. 2026-W38
  semana_meta_id uuid not null references semana_metas (id),
  veces          int not null default 0 check (veces >= 0),
  creado         timestamptz not null default now(),
  unique (user_id, semana, semana_meta_id)
);

-- One row per user. umbral_candado: fraction of the checklist required to open
-- the lock (1.0 = strict, 0.8 = lenient). SPEC §5: value picked later with real data.
create table if not exists config (
  user_id        uuid primary key default auth.uid() references auth.users (id),
  umbral_candado numeric not null default 1.0 check (umbral_candado between 0 and 1),
  creado         timestamptz not null default now()
);

-- ============================================================
-- Row Level Security: every table, user_id = auth.uid()
-- ============================================================

do $$
declare t text;
begin
  foreach t in array array['cuentas','categorias','metas','movimientos',
                           'presupuestos','recurrentes','semana_metas',
                           'semana_registro','config']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists propio on %I', t);
    execute format(
      'create policy propio on %I for all to authenticated
         using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
  end loop;
end $$;

-- ============================================================
-- estado view (SPEC §6): lock state, current/previous ISO week, and the
-- discretionary limit/spent/remaining for the month.
-- security_invoker so RLS on the underlying tables applies to the caller.
-- ============================================================

create or replace view estado
with (security_invoker = true) as
with hoy as (
  select (now() at time zone 'America/Chihuahua')::date as d
),
semanas as (
  select to_char(d, 'IYYY-"W"IW')     as semana_actual,
         to_char(d - 7, 'IYYY-"W"IW') as semana_pasada,
         to_char(d, 'YYYY-MM')        as mes_actual
  from hoy
),
checklist as (
  -- fraction of last week's checklist fulfilled (each goal capped at 100%)
  select sm.user_id,
         count(*)::numeric as metas_activas,
         sum(least(coalesce(sr.veces, 0)::numeric / sm.veces_objetivo, 1)) as cumplido
  from semana_metas sm
  left join semana_registro sr
         on sr.semana_meta_id = sm.id
        and sr.semana = (select semana_pasada from semanas)
  where sm.activa
  group by sm.user_id
),
disc_limite as (
  select p.user_id, sum(p.limite) as limite
  from presupuestos p
  join categorias c on c.id = p.categoria_id
  where p.mes = (select mes_actual from semanas) and c.discrecional
  group by p.user_id
),
disc_gastado as (
  select m.user_id, sum(m.monto) as gastado   -- expenses are negative
  from movimientos m
  join categorias c on c.id = m.categoria_id
  where c.discrecional
    and to_char(m.fecha, 'YYYY-MM') = (select mes_actual from semanas)
  group by m.user_id
)
select
  cfg.user_id,
  (select semana_actual from semanas) as semana,
  (select semana_pasada from semanas) as semana_pasada,
  cfg.umbral_candado,
  case
    when ch.metas_activas is null then 'abierto'  -- no checklist defined yet
    when ch.cumplido / ch.metas_activas >= cfg.umbral_candado then 'abierto'
    else 'cerrado'
  end as candado,
  coalesce(dl.limite, 0)                           as discrecional_limite,
  -coalesce(dg.gastado, 0)                         as discrecional_gastado,
  coalesce(dl.limite, 0) + coalesce(dg.gastado, 0) as discrecional_restante,
  now() as actualizado
from config cfg
left join checklist   ch on ch.user_id = cfg.user_id
left join disc_limite dl on dl.user_id = cfg.user_id
left join disc_gastado dg on dg.user_id = cfg.user_id;

grant select on estado to authenticated;

-- ============================================================
-- gasto_mensual_categoria: spending per category per month, for the
-- budget history columns on the Mac Presupuestos screen.
-- ============================================================

create or replace view gasto_mensual_categoria
with (security_invoker = true) as
select m.user_id,
       to_char(m.fecha, 'YYYY-MM') as mes,
       m.categoria_id,
       -sum(m.monto) as gastado
from movimientos m
where m.tipo = 'gasto' and m.categoria_id is not null
group by m.user_id, to_char(m.fecha, 'YYYY-MM'), m.categoria_id;

grant select on gasto_mensual_categoria to authenticated;

-- ============================================================
-- saldos view (SPEC §5 Cuentas): balance = saldo_inicial + sum(movimientos).
-- Aggregated server-side so the app never pages through the whole ledger.
-- ============================================================

create or replace view saldos
with (security_invoker = true) as
select c.user_id, c.id, c.nombre, c.tipo,
       c.saldo_inicial + coalesce(sum(m.monto), 0) as saldo
from cuentas c
left join movimientos m on m.cuenta_id = c.id
where c.activa
group by c.id
order by min(c.creado);

grant select on saldos to authenticated;

-- ============================================================
-- metas_progreso view (SPEC §5 Metas): abonado = sum of tipo='ahorro'
-- movements linked to the meta. Contributions are stored negative
-- (money leaves spendable funds), so the sum is negated for display.
-- ============================================================

create or replace view metas_progreso
with (security_invoker = true) as
select mt.user_id, mt.id, mt.nombre, mt.objetivo, mt.fecha_objetivo,
       coalesce(-sum(m.monto), 0) as abonado
from metas mt
left join movimientos m on m.meta_id = mt.id and m.tipo = 'ahorro'
where mt.activa
group by mt.id
order by min(mt.creado);

grant select on metas_progreso to authenticated;

-- ============================================================
-- agregar_movimiento: insert helper for Shortcuts (SPEC §4).
-- Takes category and account by NAME ("Súper", "Santander TDC") so the
-- shortcut never handles UUIDs; unknown/empty category -> null -> inbox.
-- SECURITY INVOKER (default): runs as the caller, RLS applies.
-- ============================================================

create or replace function agregar_movimiento(
  p_monto     numeric,
  p_categoria text default null,
  p_nota      text default null,
  p_comercio  text default null,
  p_origen    text default 'manual',
  p_tipo      text default 'gasto',
  p_cuenta    text default null
) returns uuid
language plpgsql as $$
declare
  v_cat uuid;
  v_cta uuid;
  v_id  uuid;
begin
  select id into v_cat
    from categorias
   where user_id = auth.uid()
     and nombre = p_categoria;

  select id into v_cta
    from cuentas
   where user_id = auth.uid()
     and nombre = p_cuenta;

  insert into movimientos (monto, categoria_id, cuenta_id, nota, comercio, origen, tipo)
  values (p_monto, v_cat, v_cta, nullif(trim(p_nota), ''), p_comercio, p_origen, p_tipo)
  returning id into v_id;

  return v_id;
end $$;

revoke execute on function agregar_movimiento from public, anon;
grant execute on function agregar_movimiento to authenticated;

-- ============================================================
-- SEED (SPEC §9, resolved 2026-09-16). Create your auth user FIRST,
-- then run this block. It seeds for the first (only) user in auth.users.
-- ============================================================

do $$
declare uid uuid;
begin
  select id into uid from auth.users order by created_at limit 1;
  if uid is null then
    raise exception 'No user found: create it in Authentication → Users first.';
  end if;

  insert into config (user_id) values (uid)
  on conflict (user_id) do nothing;

  insert into cuentas (user_id, nombre, tipo) values
    (uid, 'Efectivo',         'efectivo'),
    (uid, 'Santander débito', 'debito'),
    (uid, 'Santander TDC',    'credito')
  on conflict (user_id, nombre) do nothing;

  insert into categorias (user_id, nombre, icono, discrecional, orden) values
    (uid, 'Súper',          'cart',     false, 1),
    (uid, 'Comida fuera',   'utensils', true,  2),
    (uid, 'Café/antojos',   'coffee',   true,  3),
    (uid, 'Transporte',     'car',      false, 4),
    (uid, 'Renta/servicios','home',     false, 5),
    (uid, 'Salud',          'health',   false, 6),
    (uid, 'Ropa',           'shirt',    true,  7),
    (uid, 'Ocio/salidas',   'ticket',   true,  8),
    (uid, 'Suscripciones',  'tv',       false, 9),
    (uid, 'Regalos',        'gift',     true, 10),
    (uid, 'Viajes',         'plane',    true, 11),
    (uid, 'Ahorro',         'coin',     false, 12),
    (uid, 'Ingreso',        'cash',     false, 13)
  on conflict (user_id, nombre) do nothing;
end $$;
