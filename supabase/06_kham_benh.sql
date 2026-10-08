-- BƯỚC 6: Bác sĩ gọi số, hoàn tất khám, đánh dấu vắng mặt. Chạy lại được nhiều lần.

-- Thêm trạng thái "vang_mat"
alter table luot_kham drop constraint if exists luot_kham_trang_thai_hop_le;
alter table luot_kham
  add constraint luot_kham_trang_thai_hop_le
  check (trang_thai in ('cho_kham', 'dang_kham', 'da_kham', 'da_huy', 'vang_mat'));

-- Hàm phụ cũ (nếu đã tạo) không dùng nữa
drop function if exists public._luot_cua_bac_si(int);

-- Gọi số tiếp theo trong một ca (chỉ trong ngày khám)
create or replace function public.goi_so_tiep_theo(p_ca_kham_id int)
returns luot_kham
language plpgsql security definer set search_path = public as $$
declare
  v_ca  ca_kham;
  v_dang luot_kham;
  v_kq  luot_kham;
begin
  select * into v_ca from ca_kham where id = p_ca_kham_id and bac_si_id = auth.uid() for update;
  if not found then raise exception 'Không tìm thấy ca khám của bạn'; end if;
  if v_ca.ngay_kham <> (now() at time zone 'Asia/Ho_Chi_Minh')::date then
    raise exception 'Chỉ gọi số trong ngày khám của ca';
  end if;

  select * into v_dang from luot_kham where ca_kham_id = p_ca_kham_id and trang_thai = 'dang_kham' limit 1;
  if found then
    raise exception 'Hãy hoàn tất số % trước khi gọi số tiếp theo', lpad(v_dang.so_thu_tu::text, 2, '0');
  end if;

  update luot_kham set trang_thai = 'dang_kham', ngay_cap_nhat = now()
  where id = (select id from luot_kham
              where ca_kham_id = p_ca_kham_id and trang_thai = 'cho_kham'
              order by so_thu_tu limit 1)
  returning * into v_kq;

  if v_kq.id is null then raise exception 'Không còn bệnh nhân chờ trong ca này'; end if;
  return v_kq;
end $$;

-- Hoàn tất khám (hoặc sửa kết quả đã nhập)
create or replace function public.hoan_tat_kham(p_luot_kham_id int, p_chan_doan text, p_loi_dan text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_luot luot_kham;
  v_ca   ca_kham;
begin
  select * into v_luot from luot_kham where id = p_luot_kham_id for update;
  if not found then raise exception 'Không tìm thấy lượt khám'; end if;
  select * into v_ca from ca_kham where id = v_luot.ca_kham_id;
  if v_ca.bac_si_id is distinct from auth.uid() then
    raise exception 'Lượt khám này không thuộc ca của bạn';
  end if;
  if v_luot.trang_thai not in ('cho_kham', 'dang_kham', 'da_kham') then
    raise exception 'Lượt khám này không thể nhập kết quả';
  end if;
  if v_ca.ngay_kham > (now() at time zone 'Asia/Ho_Chi_Minh')::date then
    raise exception 'Chưa đến ngày khám của ca này';
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

-- Bệnh nhân không đến
create or replace function public.danh_dau_vang_mat(p_luot_kham_id int)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_luot luot_kham;
  v_ca   ca_kham;
begin
  select * into v_luot from luot_kham where id = p_luot_kham_id for update;
  if not found then raise exception 'Không tìm thấy lượt khám'; end if;
  select * into v_ca from ca_kham where id = v_luot.ca_kham_id;
  if v_ca.bac_si_id is distinct from auth.uid() then
    raise exception 'Lượt khám này không thuộc ca của bạn';
  end if;
  if v_luot.trang_thai not in ('cho_kham', 'dang_kham') then
    raise exception 'Lượt khám này không thể đánh dấu vắng mặt';
  end if;
  if v_ca.ngay_kham > (now() at time zone 'Asia/Ho_Chi_Minh')::date then
    raise exception 'Chưa đến ngày khám của ca này';
  end if;
  update luot_kham set trang_thai = 'vang_mat', ngay_cap_nhat = now() where id = p_luot_kham_id;
end $$;

revoke all on function public.goi_so_tiep_theo(int)            from public, anon;
revoke all on function public.hoan_tat_kham(int, text, text)   from public, anon;
revoke all on function public.danh_dau_vang_mat(int)           from public, anon;
grant execute on function public.goi_so_tiep_theo(int)          to authenticated;
grant execute on function public.hoan_tat_kham(int, text, text) to authenticated;
grant execute on function public.danh_dau_vang_mat(int)         to authenticated;
