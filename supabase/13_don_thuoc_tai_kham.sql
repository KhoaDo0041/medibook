-- BƯỚC 13: Kê đơn thuốc (danh mục THUỐC MẪU dùng cho demo) và đặt ngày tái khám.
-- Chạy lại được nhiều lần.
--
-- Lưu ý chuyên môn: dùng tên thuốc giả định (Thuốc A, B, C…) để tránh kê thuốc thật
-- sai chuyên môn. Đơn được lưu cùng lúc với "Hoàn tất khám" và bị khoá sau đó.

-- ===== 1. Danh mục thuốc mẫu =====
create table if not exists danh_muc_thuoc (
  id      serial primary key,
  ten     text not null unique,
  don_vi  text not null default 'viên',
  mo_ta   text
);

insert into danh_muc_thuoc (ten, don_vi, mo_ta) values
  ('Thuốc A', 'viên', 'Thuốc mẫu dùng cho demo'),
  ('Thuốc B', 'viên', 'Thuốc mẫu dùng cho demo'),
  ('Thuốc C', 'viên', 'Thuốc mẫu dùng cho demo'),
  ('Thuốc D', 'gói',  'Thuốc mẫu dùng cho demo (dạng gói pha nước)'),
  ('Thuốc E', 'ml',   'Thuốc mẫu dùng cho demo (dạng siro)')
on conflict (ten) do nothing;

alter table danh_muc_thuoc enable row level security;
drop policy if exists doc_danh_muc_thuoc on danh_muc_thuoc;
create policy doc_danh_muc_thuoc on danh_muc_thuoc for select to authenticated using (true);

-- ===== 2. Chi tiết đơn thuốc của một lượt khám =====
create table if not exists don_thuoc_chi_tiet (
  id            bigserial primary key,
  luot_kham_id  int not null references luot_kham(id) on delete cascade,
  thuoc_id      int not null references danh_muc_thuoc(id),
  lieu_moi_lan  numeric(5,1) not null check (lieu_moi_lan > 0 and lieu_moi_lan <= 20),
  so_lan_ngay   int not null check (so_lan_ngay between 1 and 4),
  thoi_diem     text not null check (thoi_diem in ('truoc_an', 'sau_an', 'khong_phu_thuoc')),
  so_ngay       int not null check (so_ngay between 1 and 90),
  ghi_chu       text
);
create index if not exists don_thuoc_theo_luot on don_thuoc_chi_tiet (luot_kham_id);

alter table don_thuoc_chi_tiet enable row level security;
-- Chỉ đọc: bệnh nhân của lượt khám hoặc bác sĩ của ca. Ghi qua hàm hoan_tat_kham.
drop policy if exists doc_don_thuoc on don_thuoc_chi_tiet;
create policy doc_don_thuoc on don_thuoc_chi_tiet for select to authenticated using (
  exists (
    select 1 from luot_kham lk join ca_kham c on c.id = lk.ca_kham_id
    where lk.id = don_thuoc_chi_tiet.luot_kham_id
      and (lk.benh_nhan_id = auth.uid() or c.bac_si_id = auth.uid())
  )
);

-- ===== 3. Ngày tái khám =====
alter table luot_kham add column if not exists ngay_tai_kham date;

-- ===== 4. Hoàn tất khám: nhận thêm đơn thuốc (jsonb) và ngày tái khám =====
-- p_don: [ { "thuoc_id": 1, "lieu_moi_lan": 1, "so_lan_ngay": 2,
--            "thoi_diem": "sau_an", "so_ngay": 5, "ghi_chu": "" }, ... ]
drop function if exists public.hoan_tat_kham(int, text, text);

create or replace function public.hoan_tat_kham(
  p_luot_kham_id int,
  p_chan_doan text,
  p_loi_dan text default null,
  p_don jsonb default null,
  p_ngay_tai_kham date default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_luot luot_kham;
  v_ca   ca_kham;
  v_dong jsonb;
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
  if p_don is not null and jsonb_typeof(p_don) <> 'array' then
    raise exception 'Đơn thuốc không hợp lệ';
  end if;
  if p_don is not null and jsonb_array_length(p_don) > 10 then
    raise exception 'Đơn thuốc tối đa 10 loại';
  end if;
  if p_ngay_tai_kham is not null
     and (p_ngay_tai_kham <= v_ca.ngay_kham or p_ngay_tai_kham > v_ca.ngay_kham + 180) then
    raise exception 'Ngày tái khám phải sau ngày khám và trong vòng 6 tháng';
  end if;

  update luot_kham set
    trang_thai = 'da_kham',
    chan_doan = trim(p_chan_doan),
    ghi_chu_bac_si = nullif(trim(p_loi_dan), ''),
    ngay_tai_kham = p_ngay_tai_kham,
    ngay_cap_nhat = now()
  where id = p_luot_kham_id;

  delete from don_thuoc_chi_tiet where luot_kham_id = p_luot_kham_id;
  for v_dong in select * from jsonb_array_elements(coalesce(p_don, '[]'::jsonb)) loop
    -- ràng buộc check của bảng tự báo lỗi nếu liều / số lần / số ngày sai
    insert into don_thuoc_chi_tiet (luot_kham_id, thuoc_id, lieu_moi_lan, so_lan_ngay, thoi_diem, so_ngay, ghi_chu)
    values (
      p_luot_kham_id,
      (v_dong->>'thuoc_id')::int,
      (v_dong->>'lieu_moi_lan')::numeric,
      (v_dong->>'so_lan_ngay')::int,
      v_dong->>'thoi_diem',
      (v_dong->>'so_ngay')::int,
      nullif(trim(v_dong->>'ghi_chu'), '')
    );
  end loop;
end $$;

revoke all on function public.hoan_tat_kham(int, text, text, jsonb, date) from public, anon;
grant execute on function public.hoan_tat_kham(int, text, text, jsonb, date) to authenticated;
