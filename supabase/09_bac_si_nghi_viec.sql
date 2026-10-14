-- BƯỚC 9: Bác sĩ nghỉ việc. Chạy lại được nhiều lần.
-- Phần A: cấu trúc + chặn thao tác (chạy 1 lần).
-- Phần B (cuối file): cách dùng — cho một bác sĩ nghỉ việc / làm lại.

-- ===================== PHẦN A =====================

-- Lý do huỷ để bệnh nhân biết vì sao lịch bị huỷ
alter table luot_kham add column if not exists ly_do_huy text;

-- Bác sĩ đang đăng nhập còn làm việc không
create or replace function public.bac_si_con_hoat_dong()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from bac_si where id = auth.uid() and trang_thai = 'da_duyet');
$$;
grant execute on function public.bac_si_con_hoat_dong() to authenticated;

-- Chặn gọi số / mời vào khám / tạm hoãn: thêm kiểm tra vào hàm dùng chung
create or replace function public._ca_dang_dien_ra(p_ca_kham_id int)
returns ca_kham
language plpgsql security definer set search_path = public as $$
declare v_ca ca_kham;
begin
  if not bac_si_con_hoat_dong() then
    raise exception 'Tài khoản bác sĩ đã ngừng hoạt động';
  end if;
  select * into v_ca from ca_kham where id = p_ca_kham_id and bac_si_id = auth.uid() for update;
  if not found then raise exception 'Không tìm thấy ca khám của bạn'; end if;
  if v_ca.ngay_kham <> gio_vn()::date then raise exception 'Chỉ thao tác trong ngày khám của ca'; end if;
  if v_ca.ngay_kham + v_ca.gio_ket_thuc <= gio_vn() then raise exception 'Ca khám đã kết thúc'; end if;
  return v_ca;
end $$;
revoke all on function public._ca_dang_dien_ra(int) from public, anon, authenticated;

-- Chặn hoàn tất khám
create or replace function public.hoan_tat_kham(p_luot_kham_id int, p_chan_doan text, p_loi_dan text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_luot luot_kham;
  v_ca   ca_kham;
begin
  if not bac_si_con_hoat_dong() then
    raise exception 'Tài khoản bác sĩ đã ngừng hoạt động';
  end if;
  select * into v_luot from luot_kham where id = p_luot_kham_id for update;
  if not found then raise exception 'Không tìm thấy lượt khám'; end if;
  select * into v_ca from ca_kham where id = v_luot.ca_kham_id;
  if v_ca.bac_si_id is distinct from auth.uid() then
    raise exception 'Lượt khám này không thuộc ca của bạn';
  end if;
  if v_luot.trang_thai = 'da_kham' then
    raise exception 'Kết quả đã được chốt, không thể chỉnh sửa';
  end if;
  if v_luot.trang_thai <> 'dang_kham' then
    raise exception 'Hãy mời bệnh nhân vào khám trước khi nhập kết quả';
  end if;
  if nullif(trim(p_chan_doan), '') is null then
    raise exception 'Vui lòng nhập chẩn đoán';
  end if;
  update luot_kham set
    trang_thai = 'da_kham',
    chan_doan = trim(p_chan_doan),
    ghi_chu_bac_si = nullif(trim(p_loi_dan), ''),
    ngay_cap_nhat = now()
  where id = p_luot_kham_id;
end $$;

-- Cho một bác sĩ nghỉ việc (chỉ chạy trong SQL Editor, app không gọi được)
create or replace function public.cho_bac_si_nghi_viec(p_email text)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_id      uuid;
  v_so_huy  int;
  v_so_xoa  int;
begin
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then raise exception 'Không có tài khoản %', p_email; end if;

  update bac_si set trang_thai = 'nghi_viec' where id = v_id;

  -- Huỷ các lượt chưa khám ở những ca chưa bắt đầu, trả lại chỗ
  with huy as (
    update luot_kham lk
    set trang_thai = 'da_huy', ly_do_huy = 'Bác sĩ nghỉ việc', ngay_cap_nhat = now()
    from ca_kham c
    where c.id = lk.ca_kham_id and c.bac_si_id = v_id
      and lk.trang_thai in ('cho_kham', 'tam_hoan')
      and c.ngay_kham + c.gio_bat_dau > gio_vn()
    returning lk.ca_kham_id
  ), dem as (
    select ca_kham_id, count(*) as n from huy group by ca_kham_id
  ), tra_cho as (
    update ca_kham c set so_da_dang_ky = greatest(c.so_da_dang_ky - dem.n, 0)
    from dem where c.id = dem.ca_kham_id
    returning 1
  )
  select coalesce(sum(n), 0) into v_so_huy from dem;

  -- Xoá các ca tương lai chưa từng có ai đặt
  delete from ca_kham c
  where c.bac_si_id = v_id
    and c.ngay_kham + c.gio_bat_dau > gio_vn()
    and not exists (select 1 from luot_kham lk where lk.ca_kham_id = c.id);
  get diagnostics v_so_xoa = row_count;

  return format('Đã cho nghỉ việc. Huỷ %s lượt khám, xoá %s ca trống.', v_so_huy, v_so_xoa);
end $$;
revoke all on function public.cho_bac_si_nghi_viec(text) from public, anon, authenticated;

-- Cho bác sĩ làm lại (không khôi phục các lượt đã huỷ; ca mới tạo bằng file 02b)
create or replace function public.cho_bac_si_lam_lai(p_email text)
returns text
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then raise exception 'Không có tài khoản %', p_email; end if;
  update bac_si set trang_thai = 'da_duyet' where id = v_id;
  return 'Bác sĩ đã hoạt động lại. Chạy phần tạo ca của file 02b để có lịch mới.';
end $$;
revoke all on function public.cho_bac_si_lam_lai(text) from public, anon, authenticated;

notify pgrst, 'reload schema';

-- ===================== PHẦN B: CÁCH DÙNG =====================
-- select cho_bac_si_nghi_viec('bacsi2@medibook.test');
-- select cho_bac_si_lam_lai('bacsi2@medibook.test');
