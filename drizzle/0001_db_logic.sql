-- Logic trong database: phân quyền, trigger, view, dữ liệu khởi tạo.
-- Tham chiếu: docs/DESIGN.md §2.3, §2.4, §2.5, §4.3, §9.
-- Viết tay; drizzle-kit không sinh lại file này.

-- ===== Phân quyền (DESIGN §4.3) =====
-- Trình duyệt không truy vấn DB trực tiếp. Bật RLS, không tạo policy nào, và thu hồi quyền
-- mặc định mà Supabase cấp cho anon/authenticated. Server dùng role sở hữu bảng nên không bị ảnh hưởng.

alter table members            enable row level security;--> statement-breakpoint
alter table settings           enable row level security;--> statement-breakpoint
alter table collections        enable row level security;--> statement-breakpoint
alter table charges            enable row level security;--> statement-breakpoint
alter table payments           enable row level security;--> statement-breakpoint
alter table payment_items      enable row level security;--> statement-breakpoint
alter table expense_categories enable row level security;--> statement-breakpoint
alter table expenses           enable row level security;--> statement-breakpoint
alter table audit_logs         enable row level security;--> statement-breakpoint
alter table sync_state         enable row level security;--> statement-breakpoint

-- ===== updated_at =====

create function set_updated_at() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  new.updated_at := now();
  return new;
end $$;--> statement-breakpoint

create trigger members_updated_at  before update on members  for each row execute function set_updated_at();--> statement-breakpoint
create trigger expenses_updated_at before update on expenses for each row execute function set_updated_at();--> statement-breakpoint
create trigger settings_updated_at before update on settings for each row execute function set_updated_at();--> statement-breakpoint

-- ===== payment_items.pending luôn khớp payments.status (BR-13, DESIGN §2.4) =====

create function set_item_pending() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  new.pending := coalesce(
    (select p.status = 'pending' from payments p where p.id = new.payment_id),
    false
  );
  return new;
end $$;--> statement-breakpoint

create trigger payment_items_pending_on_write
  before insert or update on payment_items
  for each row execute function set_item_pending();--> statement-breakpoint

create function sync_payment_items_pending() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  -- Trigger before update ở trên sẽ tính lại pending từ trạng thái mới của payment.
  update payment_items set pending = (new.status = 'pending') where payment_id = new.id;
  return null;
end $$;--> statement-breakpoint

create trigger payments_status_to_items
  after update of status on payments
  for each row when (old.status is distinct from new.status)
  execute function sync_payment_items_pending();--> statement-breakpoint

-- ===== Đánh dấu cần đồng bộ Google Sheet (DESIGN §7) =====

create function mark_sheet_dirty() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  update sync_state
     set dirty = true, dirty_since = coalesce(dirty_since, now())
   where id = 1;
  return null;
end $$;--> statement-breakpoint

create trigger sheet_dirty after insert or update or delete on payments           for each statement execute function mark_sheet_dirty();--> statement-breakpoint
create trigger sheet_dirty after insert or update or delete on charges            for each statement execute function mark_sheet_dirty();--> statement-breakpoint
create trigger sheet_dirty after insert or update or delete on collections        for each statement execute function mark_sheet_dirty();--> statement-breakpoint
create trigger sheet_dirty after insert or update or delete on expenses           for each statement execute function mark_sheet_dirty();--> statement-breakpoint
create trigger sheet_dirty after insert or update or delete on expense_categories for each statement execute function mark_sheet_dirty();--> statement-breakpoint
create trigger sheet_dirty after insert or update or delete on members            for each statement execute function mark_sheet_dirty();--> statement-breakpoint

-- ===== Nhật ký (FR-AUD-01, DESIGN §9) =====

create function audit_row() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  insert into audit_logs (actor_id, action, entity, entity_id, before, after, reason)
  values (
    nullif(current_setting('app.actor_id', true), '')::uuid,
    coalesce(nullif(current_setting('app.action', true), ''), tg_table_name || '.' || lower(tg_op)),
    tg_table_name,
    coalesce(to_jsonb(new), to_jsonb(old)) ->> 'id',   -- OLD/NEW là NULL tùy thao tác
    to_jsonb(old),
    to_jsonb(new),
    nullif(current_setting('app.reason', true), '')
  );
  return null;
end $$;--> statement-breakpoint

create trigger audit after insert or update or delete on members            for each row execute function audit_row();--> statement-breakpoint
create trigger audit after insert or update or delete on collections        for each row execute function audit_row();--> statement-breakpoint
create trigger audit after insert or update or delete on charges            for each row execute function audit_row();--> statement-breakpoint
create trigger audit after insert or update or delete on payments           for each row execute function audit_row();--> statement-breakpoint
create trigger audit after insert or update or delete on expenses           for each row execute function audit_row();--> statement-breakpoint
create trigger audit after insert or update or delete on expense_categories for each row execute function audit_row();--> statement-breakpoint
create trigger audit after insert or update or delete on settings           for each row execute function audit_row();--> statement-breakpoint

-- BR-16: nhật ký chỉ được thêm mới
create function forbid_audit_change() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  raise exception 'audit_logs chỉ được thêm mới (BR-16)';
end $$;--> statement-breakpoint

create trigger audit_logs_append_only
  before update or delete on audit_logs
  for each row execute function forbid_audit_change();--> statement-breakpoint

create trigger audit_logs_no_truncate
  before truncate on audit_logs
  for each statement execute function forbid_audit_change();--> statement-breakpoint

-- ===== View tính toán (DESIGN §2.3) =====
-- security_invoker: view chạy với quyền của người gọi, nên RLS của bảng gốc vẫn áp dụng.
-- Nếu thiếu, view chạy bằng quyền chủ sở hữu và anon có thể đọc vòng qua RLS.

create view v_charge_status with (security_invoker = true) as
with agg as (
  select
    c.id as charge_id,
    coalesce(sum(pi.amount) filter (where p.status = 'confirmed'), 0)::bigint as paid,
    coalesce(bool_or(p.status = 'pending'), false)                            as has_pending
  from charges c
  left join payment_items pi on pi.charge_id = c.id
  left join payments p       on p.id = pi.payment_id
  group by c.id
)
select
  c.id as charge_id,
  c.collection_id,
  c.member_id,
  c.amount,
  a.paid,
  (case when c.waived_at is not null then 0 else c.amount - a.paid end)::bigint as remaining,
  a.has_pending,
  case
    when c.waived_at is not null then 'waived'
    when a.paid >= c.amount      then 'paid'
    when a.has_pending           then 'pending'
    when a.paid > 0              then 'partial'
    else                              'unpaid'
  end as status
from charges c
join agg a on a.charge_id = c.id;--> statement-breakpoint

create view v_collection_progress with (security_invoker = true) as
select
  col.id as collection_id,
  col.code,
  col.title,
  col.status,
  col.due_date,
  count(cs.charge_id)                                                       as member_count,
  count(cs.charge_id) filter (where cs.status in ('paid', 'waived'))        as done_count,
  coalesce(sum(cs.amount) filter (where cs.status <> 'waived'), 0)::bigint  as total_due,
  coalesce(sum(cs.paid), 0)::bigint                                         as total_paid
from collections col
left join v_charge_status cs on cs.collection_id = col.id
group by col.id;--> statement-breakpoint

create view v_member_debt with (security_invoker = true) as
select
  m.id as member_id,
  m.name,
  m.jersey_number,
  m.status,
  coalesce(sum(cs.remaining), 0)::bigint as debt
from members m
left join v_charge_status cs on cs.member_id = m.id
group by m.id;--> statement-breakpoint

create view v_fund_balance with (security_invoker = true) as
with t as (
  select
    (select coalesce(sum(total_amount), 0) from payments where status = 'confirmed')::bigint as total_in,
    (select coalesce(sum(amount), 0) from expenses where deleted_at is null)::bigint        as total_out
)
select total_in, total_out, (total_in - total_out)::bigint as balance from t;--> statement-breakpoint

-- ===== Thu hồi quyền mặc định của Supabase (DESIGN §4.3) =====

revoke all on all tables    in schema public from anon, authenticated;--> statement-breakpoint
revoke all on all sequences in schema public from anon, authenticated;--> statement-breakpoint

-- ===== Dữ liệu khởi tạo (DESIGN §2.5) =====

insert into settings (id) values (1);--> statement-breakpoint
insert into sync_state (id) values (1);--> statement-breakpoint
insert into expense_categories (name, sort_order) values
  ('Sân', 1), ('Nước', 2), ('Áo', 3), ('Khác', 99);
