-- BƯỚC 7: Tạm hoãn khi bệnh nhân chưa có mặt; chỉ tính vắng mặt khi ca đã kết thúc;
-- kết quả khám bị khoá sau khi hoàn tất. Chạy lại được nhiều lần.

alter table luot_kham drop constraint if exists luot_kham_trang_thai_hop_le;
alter table luot_kham
  add constraint luot_kham_trang_thai_hop_le
  check (trang_thai in ('cho_kham', 'dang_kham', 'tam_hoan', 'da_kham', 'da_huy', 'vang_mat'));

-- Vắng mặt giờ do hệ thống tự chốt khi hết ca, bác sĩ không bấm tay nữa
drop function if exists public.danh_dau_vang_mat(int);

-- Hàm phụ: giờ Việt Nam
create or replace function public.gio_vn() returns timestamp
language sql stable as $$ select now() at time zone 'Asia/Ho_Chi_Minh' $$;

-- Kiểm tra ca thuộc bác sĩ đang đăng nhập và đang diễn ra (hôm nay, chưa hết giờ)
create or replace function public._ca_dang_dien_ra(p_ca_kham_id int)
returns ca_kham
language plpgsql security definer set search_path = public as $$
declare v_ca ca_kham;
begin
  select * into v_ca from ca_kham where id = p_ca_kham_id and bac_si_id = auth.uid() for update;
  if not found then raise exception 'Không tìm thấy ca khám của bạn'; end if;
  if v_ca.ngay_kham <> gio_vn()::date then raise exception 'Chỉ thao tác trong ngày khám của ca'; end if;
  if v_ca.ngay_kham + v_ca.gio_ket_thuc <= gio_vn() then raise exception 'Ca khám đã kết thúc'; end if;
  return v_ca;
end $$;
revoke all on function public._ca_dang_dien_ra(int) from public, anon, authenticated;

-- Gọi số tiếp theo (người chờ có số nhỏ nhất)
create or replace function public.goi_so_tiep_theo(p_ca_kham_id int)
returns luot_kham
language plpgsql security definer set search_path = public as $$
declare
  v_dang luot_kham;
  v_kq   luot_kham;
begin
  perform _ca_dang_dien_ra(p_ca_kham_id);

  select * into v_dang from luot_kham where ca_kham_id = p_ca_kham_id and trang_thai = 'dang_kham' limit 1;
  if found then
    raise exception 'Hãy hoàn tất hoặc tạm hoãn số % trước', lpad(v_dang.so_thu_tu::text, 2, '0');
  end if;

  update luot_kham set trang_thai = 'dang_kham', ngay_cap_nhat = now()
  where id = (select id from luot_kham
              where ca_kham_id = p_ca_kham_id and trang_thai = 'cho_kham'
              order by so_thu_tu limit 1)
  returning * into v_kq;

  if v_kq.id is null then raise exception 'Không còn bệnh nhân chờ trong ca này'; end if;
  return v_kq;
end $$;

-- Mời một bệnh nhân cụ thể vào khám (người tạm hoãn vừa đến, hoặc gọi vượt số)
create or replace function public.bat_dau_kham(p_luot_kham_id int)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_luot luot_kham;
  v_dang luot_kham;
begin
  select * into v_luot from luot_kham where id = p_luot_kham_id for update;
  if not found then raise exception 'Không tìm thấy lượt khám'; end if;
  perform _ca_dang_dien_ra(v_luot.ca_kham_id);   -- kiểm tra quyền + thời gian

  if v_luot.trang_thai not in ('cho_kham', 'tam_hoan') then
    raise exception 'Bệnh nhân này không ở trạng thái chờ';
  end if;
  select * into v_dang from luot_kham
  where ca_kham_id = v_luot.ca_kham_id and trang_thai = 'dang_kham' limit 1;
  if found then
    raise exception 'Hãy hoàn tất hoặc tạm hoãn số % trước', lpad(v_dang.so_thu_tu::text, 2, '0');
  end if;

  update luot_kham set trang_thai = 'dang_kham', ngay_cap_nhat = now() where id = p_luot_kham_id;
end $$;

-- Tạm hoãn: bệnh nhân chưa có mặt, vẫn giữ số đến hết ca
create or replace function public.tam_hoan_kham(p_luot_kham_id int)
returns void
language plpgsql security definer set search_path = public as $$
declare v_luot luot_kham;
begin
  select * into v_luot from luot_kham where id = p_luot_kham_id for update;
  if not found then raise exception 'Không tìm thấy lượt khám'; end if;
  perform _ca_dang_dien_ra(v_luot.ca_kham_id);

  if v_luot.trang_thai not in ('cho_kham', 'dang_kham') then
    raise exception 'Lượt khám này không thể tạm hoãn';
  end if;
  update luot_kham set trang_thai = 'tam_hoan', ngay_cap_nhat = now() where id = p_luot_kham_id;
end $$;

-- Hoàn tất khám: chỉ khi đang khám; sau đó kết quả bị khoá
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

-- Chốt các ca đã hết giờ của bác sĩ: người còn chờ/tạm hoãn -> vắng mặt
create or replace function public.chot_ca_qua_han()
returns int
language plpgsql security definer set search_path = public as $$
declare v_so int;
begin
  update luot_kham lk set trang_thai = 'vang_mat', ngay_cap_nhat = now()
  from ca_kham c
  where c.id = lk.ca_kham_id
    and c.bac_si_id = auth.uid()
    and lk.trang_thai in ('cho_kham', 'tam_hoan')
    and c.ngay_kham + c.gio_ket_thuc <= gio_vn();
  get diagnostics v_so = row_count;
  return v_so;
end $$;

revoke all on function public.goi_so_tiep_theo(int)            from public, anon;
revoke all on function public.bat_dau_kham(int)                from public, anon;
revoke all on function public.tam_hoan_kham(int)               from public, anon;
revoke all on function public.hoan_tat_kham(int, text, text)   from public, anon;
revoke all on function public.chot_ca_qua_han()                from public, anon;
grant execute on function public.goi_so_tiep_theo(int)          to authenticated;
grant execute on function public.bat_dau_kham(int)              to authenticated;
grant execute on function public.tam_hoan_kham(int)             to authenticated;
grant execute on function public.hoan_tat_kham(int, text, text) to authenticated;
grant execute on function public.chot_ca_qua_han()              to authenticated;
