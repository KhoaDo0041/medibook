-- BƯỚC 3: Bật RLS + chính sách cho mọi bảng, và các hàm đặt/huỷ lượt khám an toàn.
-- Chạy lại được nhiều lần. Khi Supabase hỏi về RLS: chọn "Run without RLS" (file này tự bật RLS).

-- ===== Hàm phụ: người đang đăng nhập có phải bác sĩ không =====
create or replace function public.la_bac_si()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from ho_so where id = auth.uid() and vai_tro = 'bac_si');
$$;

-- ===== Bật RLS =====
alter table ho_so           enable row level security;
alter table chuyen_khoa     enable row level security;
alter table benh_vien       enable row level security;
alter table khoa_benh_vien  enable row level security;
alter table bac_si          enable row level security;
alter table ca_kham         enable row level security;
alter table luot_kham       enable row level security;
alter table lich_su_chat_ai enable row level security;
alter table lich_hen        enable row level security;  -- bảng cũ, không có chính sách = khoá hoàn toàn

-- ===== Dữ liệu công khai cho người đã đăng nhập (chỉ đọc) =====
drop policy if exists doc_chuyen_khoa on chuyen_khoa;
create policy doc_chuyen_khoa on chuyen_khoa for select to authenticated using (true);

drop policy if exists doc_benh_vien on benh_vien;
create policy doc_benh_vien on benh_vien for select to authenticated using (true);

drop policy if exists doc_khoa_benh_vien on khoa_benh_vien;
create policy doc_khoa_benh_vien on khoa_benh_vien for select to authenticated using (true);

drop policy if exists doc_bac_si on bac_si;
create policy doc_bac_si on bac_si for select to authenticated
  using (trang_thai = 'da_duyet' or id = auth.uid());

drop policy if exists doc_ca_kham on ca_kham;
create policy doc_ca_kham on ca_kham for select to authenticated using (true);

-- ===== Hồ sơ =====
drop policy if exists doc_ho_so on ho_so;
create policy doc_ho_so on ho_so for select to authenticated using (
  id = auth.uid()                                         -- hồ sơ của mình
  or vai_tro = 'bac_si'                                   -- tên bác sĩ ai cũng xem được
  or exists (                                             -- bác sĩ xem bệnh nhân đã đặt ca của mình
    select 1 from luot_kham lk join ca_kham c on c.id = lk.ca_kham_id
    where lk.benh_nhan_id = ho_so.id and c.bac_si_id = auth.uid()
  )
);

drop policy if exists sua_ho_so on ho_so;
create policy sua_ho_so on ho_so for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Không cho tự đổi vai trò thành bác sĩ
create or replace function public.chan_doi_vai_tro()
returns trigger language plpgsql as $$
begin
  if new.vai_tro is distinct from old.vai_tro and auth.uid() is not null then
    raise exception 'Không được đổi vai trò';
  end if;
  return new;
end $$;
drop trigger if exists ho_so_chan_doi_vai_tro on ho_so;
create trigger ho_so_chan_doi_vai_tro before update on ho_so
  for each row execute function public.chan_doi_vai_tro();

-- ===== Lượt khám: chỉ đọc qua RLS; ghi qua các hàm bên dưới =====
drop policy if exists doc_luot_kham on luot_kham;
create policy doc_luot_kham on luot_kham for select to authenticated using (
  benh_nhan_id = auth.uid()
  or exists (select 1 from ca_kham c where c.id = luot_kham.ca_kham_id and c.bac_si_id = auth.uid())
);

-- ===== Lịch sử chat AI: chỉ của mình =====
drop policy if exists chat_cua_toi on lich_su_chat_ai;
create policy chat_cua_toi on lich_su_chat_ai for all to authenticated
  using (benh_nhan_id = auth.uid())
  with check (benh_nhan_id = auth.uid());

-- ===== Hàm đặt lượt khám: cấp số thứ tự an toàn khi nhiều người bấm cùng lúc =====
create or replace function public.dat_luot_kham(p_ca_kham_id int, p_trieu_chung text default null)
returns luot_kham
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_bay_gio timestamp := now() at time zone 'Asia/Ho_Chi_Minh';
  v_ca   ca_kham;
  v_stt  int;
  v_kq   luot_kham;
begin
  if v_uid is null then raise exception 'Bạn cần đăng nhập'; end if;
  if la_bac_si() then raise exception 'Tài khoản bác sĩ không thể đặt lịch'; end if;

  -- Khoá dòng ca khám: ai đến sau phải chờ người trước xong
  select * into v_ca from ca_kham where id = p_ca_kham_id for update;
  if not found then raise exception 'Ca khám không tồn tại'; end if;

  if (v_ca.ngay_kham + v_ca.gio_ket_thuc) <= v_bay_gio then
    raise exception 'Ca khám đã kết thúc';
  end if;
  if v_ca.so_da_dang_ky >= v_ca.so_luong_toi_da then
    raise exception 'Ca khám đã hết chỗ';
  end if;
  if exists (select 1 from luot_kham where benh_nhan_id = v_uid
             and ca_kham_id = p_ca_kham_id and trang_thai <> 'da_huy') then
    raise exception 'Bạn đã đặt ca này rồi';
  end if;

  -- Số tiếp theo (số của người đã huỷ không cấp lại)
  select coalesce(max(so_thu_tu), 0) + 1 into v_stt from luot_kham where ca_kham_id = p_ca_kham_id;

  insert into luot_kham (benh_nhan_id, ca_kham_id, so_thu_tu, trang_thai, trieu_chung)
  values (v_uid, p_ca_kham_id, v_stt, 'cho_kham', nullif(trim(p_trieu_chung), ''))
  returning * into v_kq;

  update ca_kham set so_da_dang_ky = so_da_dang_ky + 1 where id = p_ca_kham_id;
  return v_kq;
end $$;

-- ===== Hàm huỷ lượt khám: chỉ chủ lượt, chỉ khi đang chờ và ca chưa bắt đầu =====
create or replace function public.huy_luot_kham(p_luot_kham_id int)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_lk luot_kham;
  v_ca ca_kham;
begin
  select * into v_lk from luot_kham where id = p_luot_kham_id and benh_nhan_id = auth.uid() for update;
  if not found then raise exception 'Không tìm thấy lượt khám'; end if;
  if v_lk.trang_thai <> 'cho_kham' then raise exception 'Lượt khám này không thể huỷ'; end if;

  select * into v_ca from ca_kham where id = v_lk.ca_kham_id for update;
  if (v_ca.ngay_kham + v_ca.gio_bat_dau) <= (now() at time zone 'Asia/Ho_Chi_Minh') then
    raise exception 'Ca khám đã bắt đầu, không thể huỷ';
  end if;

  update luot_kham set trang_thai = 'da_huy', ngay_cap_nhat = now() where id = p_luot_kham_id;
  update ca_kham set so_da_dang_ky = greatest(so_da_dang_ky - 1, 0) where id = v_ca.id;
end $$;

-- Chỉ người đã đăng nhập được gọi
revoke all on function public.dat_luot_kham(int, text) from public, anon;
revoke all on function public.huy_luot_kham(int)       from public, anon;
grant execute on function public.dat_luot_kham(int, text) to authenticated;
grant execute on function public.huy_luot_kham(int)       to authenticated;
