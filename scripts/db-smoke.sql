-- Kiểm tra nhanh logic trong database sau khi migrate. Chạy trong một giao dịch rồi rollback,
-- không để lại dữ liệu. Cách chạy: npm run db:smoke
-- Lỗi ở bất kỳ assert nào sẽ dừng script với thông báo tương ứng.

\set ON_ERROR_STOP on
begin;

-- Dữ liệu mẫu
insert into members (id, name, email, jersey_number, member_type, role)
values ('00000000-0000-0000-0000-00000000000a', 'Đội Trưởng', 'cap@n88.test', 1, 'regular', 'captain'),
       ('00000000-0000-0000-0000-00000000000b', 'Minh', 'minh@n88.test', 10, 'regular', 'member'),
       ('00000000-0000-0000-0000-00000000000c', 'Hà', null, null, 'student', 'member');

select set_config('app.actor_id', '00000000-0000-0000-0000-00000000000a', true),
       set_config('app.action', 'collection.create', true);

insert into collections (id, code, title, pricing_mode, fee_regular, fee_student, created_by)
values ('00000000-0000-0000-0000-0000000000c1', 'Q1126', 'Quỹ T11/2026', 'by_type', 200000, 100000,
        '00000000-0000-0000-0000-00000000000a');

insert into charges (id, collection_id, member_id, amount) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000b', 200000),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000c', 100000);

do $$
begin
  -- Mã thành viên tự sinh
  assert (select code from members where email = 'minh@n88.test') ~ '^M\d{3}$', 'members.code tự sinh sai';

  -- BR-05: trùng số áo giữa người đang Hoạt động bị chặn
  begin
    insert into members (name, jersey_number) values ('Trùng số', 10);
    raise exception 'BR-05 không chặn trùng số áo';
  exception when unique_violation then null;
  end;

  -- Nhật ký ghi đúng người và hành động
  assert exists (
    select 1 from audit_logs
     where entity = 'collections' and action = 'collection.create'
       and actor_id = '00000000-0000-0000-0000-00000000000a'
  ), 'audit_row không ghi actor/action';

  -- Trạng thái ban đầu
  assert (select status from v_charge_status where charge_id = '00000000-0000-0000-0000-0000000000d1') = 'unpaid',
    'khoản mới phải là unpaid';
end $$;

-- Thanh toán một phần, đang chờ
insert into payments (id, member_id, total_amount, transfer_code, status, source, created_by)
values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000000b', 50000,
        'N88 10 Q1126', 'pending', 'member_report', '00000000-0000-0000-0000-00000000000b');
insert into payment_items (payment_id, charge_id, amount)
values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', 50000);

do $$
begin
  assert (select pending from payment_items where payment_id = '00000000-0000-0000-0000-0000000000e1'),
    'payment_items.pending phải là true khi payment đang chờ';
  assert (select status from v_charge_status where charge_id = '00000000-0000-0000-0000-0000000000d1') = 'pending',
    'khoản có thanh toán chờ phải là pending';

  -- BR-13: thanh toán chờ thứ hai cho cùng khoản bị chặn
  begin
    insert into payments (id, member_id, total_amount, transfer_code, status, source, created_by)
    values ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-00000000000b', 150000,
            'N88 10 Q1126', 'pending', 'member_report', '00000000-0000-0000-0000-00000000000b');
    insert into payment_items (payment_id, charge_id, amount)
    values ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000d1', 150000);
    raise exception 'BR-13 không chặn hai thanh toán chờ';
  exception when unique_violation then null;
  end;
end $$;

-- Xác nhận
update payments set status = 'confirmed', reviewed_by = '00000000-0000-0000-0000-00000000000a', reviewed_at = now()
 where id = '00000000-0000-0000-0000-0000000000e1';

do $$
begin
  assert not (select pending from payment_items where payment_id = '00000000-0000-0000-0000-0000000000e1'),
    'payment_items.pending phải về false sau khi xác nhận';
  assert (select status from v_charge_status where charge_id = '00000000-0000-0000-0000-0000000000d1') = 'partial',
    'khoản đã đóng 50k/200k phải là partial';
  assert (select remaining from v_charge_status where charge_id = '00000000-0000-0000-0000-0000000000d1') = 150000,
    'remaining sai';
  assert (select balance from v_fund_balance) = 50000, 'số dư quỹ sai';
  assert (select total_due from v_collection_progress where code = 'Q1126') = 300000, 'total_due sai';
  assert (select debt from v_member_debt where member_id = '00000000-0000-0000-0000-00000000000b') = 150000,
    'tổng nợ sai';
  assert (select dirty from sync_state where id = 1), 'sync_state.dirty phải được bật';
end $$;

-- Miễn khoản của Hà
update charges set waived_at = now(), waived_by = '00000000-0000-0000-0000-00000000000a'
 where id = '00000000-0000-0000-0000-0000000000d2';

do $$
begin
  assert (select status from v_charge_status where charge_id = '00000000-0000-0000-0000-0000000000d2') = 'waived',
    'khoản được miễn phải là waived';
  assert (select total_due from v_collection_progress where code = 'Q1126') = 200000,
    'total_due không được tính khoản miễn';
  assert (select done_count from v_collection_progress where code = 'Q1126') = 1, 'done_count sai';

  -- BR-16: nhật ký không sửa được
  begin
    update audit_logs set reason = 'sửa' where id = (select min(id) from audit_logs);
    raise exception 'BR-16 không chặn sửa nhật ký';
  exception when raise_exception then
    if sqlerrm not like '%BR-16%' or sqlerrm like '%không chặn%' then raise; end if;
  end;
end $$;

-- anon không đọc được bảng và view (DESIGN §4.3)
set local role anon;
do $$
begin
  begin
    perform 1 from v_member_debt;
    raise exception 'anon đọc được v_member_debt';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from members;
    raise exception 'anon đọc được members';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

\echo 'db-smoke: tất cả kiểm tra đều đạt'
rollback;
