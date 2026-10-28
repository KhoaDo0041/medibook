-- BƯỚC 11: Theo dõi hàng chờ theo thời gian thực. Chạy lại được nhiều lần.
--
-- Ý tưởng: bệnh nhân không được đọc lượt khám của người khác (RLS), nên không thể
-- tự đếm hàng chờ. Vì vậy:
--   1. Bảng ca_kham (ai cũng đọc được) có thêm cột so_dang_kham = số đang được khám.
--      Trigger tự cập nhật cột này mỗi khi một lượt khám trong ca đổi trạng thái.
--   2. Bật Supabase Realtime cho ca_kham: dòng ca đổi → app bệnh nhân nhận sự kiện ngay.
--   3. Hàm hang_cho_cua_toi() trả về số người còn chờ trước MÌNH (chỉ xem được lượt của mình).

alter table ca_kham add column if not exists so_dang_kham int;
alter table ca_kham add column if not exists cap_nhat_hang_cho timestamptz;

-- ===== 1. Trigger: lượt khám đổi trạng thái → cập nhật dòng ca =====
create or replace function public._cap_nhat_hang_cho()
returns trigger
language plpgsql security definer set search_path = public as $$
declare v_ca int := coalesce(new.ca_kham_id, old.ca_kham_id);
begin
  update ca_kham set
    so_dang_kham = (select so_thu_tu from luot_kham
                    where ca_kham_id = v_ca and trang_thai = 'dang_kham'
                    order by ngay_cap_nhat desc nulls last limit 1),
    cap_nhat_hang_cho = now()      -- luôn đổi để Realtime phát sự kiện
  where id = v_ca;
  return null;
end $$;
revoke all on function public._cap_nhat_hang_cho() from public, anon, authenticated;

drop trigger if exists luot_kham_cap_nhat_hang_cho on luot_kham;
create trigger luot_kham_cap_nhat_hang_cho
  after insert or delete or update of trang_thai on luot_kham
  for each row execute function public._cap_nhat_hang_cho();

-- Điền giá trị ban đầu cho các ca đang có người khám
update ca_kham c set so_dang_kham = (
  select so_thu_tu from luot_kham
  where ca_kham_id = c.id and trang_thai = 'dang_kham' limit 1
);

-- ===== 2. Hàng chờ của một lượt khám (chỉ chủ lượt khám xem được) =====
create or replace function public.hang_cho_cua_toi(p_luot_kham_id int)
returns table (trang_thai text, so_thu_tu int, so_dang_kham int, so_nguoi_truoc int)
language sql stable security definer set search_path = public as $$
  select lk.trang_thai,
         lk.so_thu_tu,
         c.so_dang_kham,
         (select count(*)::int from luot_kham x
          where x.ca_kham_id = lk.ca_kham_id
            and x.trang_thai = 'cho_kham'
            and x.so_thu_tu < lk.so_thu_tu)
  from luot_kham lk
  join ca_kham c on c.id = lk.ca_kham_id
  where lk.id = p_luot_kham_id
    and lk.benh_nhan_id = auth.uid();
$$;
revoke all on function public.hang_cho_cua_toi(int) from public, anon;
grant execute on function public.hang_cho_cua_toi(int) to authenticated;

-- ===== 3. Bật Realtime cho bảng ca_kham =====
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ca_kham') then
    alter publication supabase_realtime add table public.ca_kham;
  end if;
end $$;
