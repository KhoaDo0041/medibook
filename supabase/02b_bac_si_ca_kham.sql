-- BƯỚC 2B: Chuẩn hoá dữ liệu cũ, gắn tài khoản bác sĩ mới, tạo ca khám 14 ngày tới.
-- Trước khi chạy: tạo bacsi5..bacsi12@medibook.test ở Authentication -> Users (tick Auto Confirm User).
-- Chạy lại được nhiều lần.

-- 1. Chuẩn hoá dữ liệu cũ cho thống nhất
update ho_so set ho_ten = regexp_replace(ho_ten, '^BS\.\s*', '')
where vai_tro = 'bac_si' and ho_ten ~ '^BS\.';

update bac_si set hoc_vi = case hoc_vi
    when 'Bác sĩ Chuyên khoa II' then 'BS.CKII'
    when 'Bác sĩ Chuyên khoa I'  then 'BS.CKI'
    when 'Tiến sĩ Y khoa'        then 'TS.BS'
    when 'Thạc sĩ Y khoa'        then 'ThS.BS'
    else hoc_vi end;

update bac_si set trang_thai = 'da_duyet' where trang_thai = 'cho_duyet';

-- Tên khoa hiển thị: chỉ "Khoa X" (app đã hiện tên bệnh viện riêng)
update khoa_benh_vien k set ten_hien_thi = 'Khoa ' || c.ten_khoa
from chuyen_khoa c where c.id = k.chuyen_khoa_id;

-- 2. Bác sĩ mới cho các bệnh viện chưa có bác sĩ (id bệnh viện / chuyên khoa theo bảng hiện tại)
with ds(email, ho_ten, hoc_vi, nam_kn, bv_id, khoa_id) as (values
  ('bacsi5@medibook.test', 'Đặng Quang Minh', 'TS.BS',   18,  1, 3),  -- Chợ Rẫy - Tim mạch
  ('bacsi6@medibook.test', 'Ngô Thanh Tâm',   'BS.CKI',   7,  6, 4),  -- Yersin - Da liễu
  ('bacsi7@medibook.test', 'Võ Thị Hà',       'BS.CKI',   6,  7, 7),  -- TP. Thủ Đức - Nội tổng quát
  ('bacsi8@medibook.test', 'Huỳnh Ngọc Lan',  'ThS.BS',  10,  7, 1),  -- TP. Thủ Đức - Nhi
  ('bacsi9@medibook.test', 'Trịnh Văn Phúc',  'BS.CKII', 16,  8, 7),  -- Nhân dân 115 - Nội tổng quát
  ('bacsi10@medibook.test', 'Lý Hoàng Nam',    'ThS.BS',   9,  8, 6),  -- Nhân dân 115 - Mắt
  ('bacsi11@medibook.test', 'Bùi Quốc Dũng',   'BS.CKI',   8,  9, 2),  -- Trưng Vương - Tai Mũi Họng
  ('bacsi12@medibook.test', 'Hoàng Gia Khánh', 'TS.BS',   20, 10, 5)   -- Lê Văn Thịnh - Răng Hàm Mặt
),
nguoi as (
  select u.id, ds.*, c.ten_khoa
  from ds
  join auth.users u  on lower(u.email) = ds.email
  join chuyen_khoa c on c.id = ds.khoa_id
),
cap_nhat_ho_so as (
  insert into ho_so (id, ho_ten, vai_tro)
  select id, ho_ten, 'bac_si' from nguoi
  on conflict (id) do update set ho_ten = excluded.ho_ten, vai_tro = 'bac_si'
)
insert into bac_si (id, chuyen_khoa_id, benh_vien_id, hoc_vi, so_nam_kinh_nghiem, trang_thai, gioi_thieu)
select id, khoa_id, bv_id, hoc_vi, nam_kn, 'da_duyet',
       nam_kn || ' năm kinh nghiệm khám và điều trị chuyên khoa ' || ten_khoa || '.'
from nguoi
on conflict (id) do update set
  chuyen_khoa_id = excluded.chuyen_khoa_id, benh_vien_id = excluded.benh_vien_id,
  hoc_vi = excluded.hoc_vi, so_nam_kinh_nghiem = excluded.so_nam_kinh_nghiem,
  trang_thai = 'da_duyet', gioi_thieu = excluded.gioi_thieu;

-- 3. Ca khám 14 ngày tới cho mọi bác sĩ đã duyệt (cả 4 bác sĩ cũ).
-- Ca sáng 07:30-11:30 (20 chỗ), ca chiều 13:30-16:30 (15 chỗ); nghỉ Chủ nhật;
-- mỗi bác sĩ nghỉ thêm khoảng 1/3 số ngày để có ngày "Đang trực" và ngày không trực.
insert into ca_kham (bac_si_id, khoa_benh_vien_id, ngay_kham, gio_bat_dau, gio_ket_thuc, so_luong_toi_da)
select b.id, k.id, d::date, ca.bd, ca.kt, ca.sl
from bac_si b
join khoa_benh_vien k
  on k.benh_vien_id = b.benh_vien_id and k.chuyen_khoa_id = b.chuyen_khoa_id
cross join generate_series(current_date, current_date + 13, interval '1 day') as d
cross join (values ('07:30'::time, '11:30'::time, 20),
                   ('13:30'::time, '16:30'::time, 15)) as ca(bd, kt, sl)
where b.trang_thai = 'da_duyet'
  and extract(isodow from d) <> 7
  and (extract(doy from d)::int + abs(hashtext(b.id::text))) % 3 <> 0
on conflict (bac_si_id, ngay_kham, gio_bat_dau) do nothing;

-- 4. Kiểm tra: mỗi bác sĩ một dòng
select h.ho_ten, b.hoc_vi, bv.ten_benh_vien, ck.ten_khoa, count(ca.id) as so_ca
from bac_si b
join ho_so h        on h.id = b.id
join benh_vien bv   on bv.id = b.benh_vien_id
join chuyen_khoa ck on ck.id = b.chuyen_khoa_id
left join ca_kham ca on ca.bac_si_id = b.id
group by h.ho_ten, b.hoc_vi, bv.ten_benh_vien, ck.ten_khoa
order by bv.ten_benh_vien;
