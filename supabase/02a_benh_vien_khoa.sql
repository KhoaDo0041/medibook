-- BƯỚC 2A: Bệnh viện, chuyên khoa, khoa của từng bệnh viện. Chạy lại không bị trùng.
-- Toạ độ là gần đúng: kiểm tra lại trên Google Maps (chuột phải vào bệnh viện -> copy toạ độ).

insert into benh_vien (ten_benh_vien, dia_chi, vi_do, kinh_do)
select v.ten, v.dc, v.vd, v.kd
from (values
  ('Bệnh viện Nhân dân 115',  '527 Sư Vạn Hạnh, Phường 12, Quận 10, TP.HCM',          10.7744, 106.6664),
  ('Bệnh viện Trưng Vương',   '606 Đường 3 Tháng 2, Phường 14, Quận 10, TP.HCM',      10.7648, 106.6633),
  ('Bệnh viện TP. Thủ Đức',   '29 Phú Châu, Phường Tam Phú, TP. Thủ Đức, TP.HCM',      10.8585, 106.7466),
  ('Bệnh viện Lê Văn Thịnh',  '130 Lê Văn Thịnh, Phường Bình Trưng Tây, TP. Thủ Đức', 10.7853, 106.7604)
) as v(ten, dc, vd, kd)
where not exists (select 1 from benh_vien b where b.ten_benh_vien = v.ten);

insert into chuyen_khoa (ten_khoa)
select v.ten
from (values ('Nội tổng quát'), ('Nhi'), ('Da liễu'), ('Tai Mũi Họng'), ('Răng Hàm Mặt'), ('Mắt')) as v(ten)
where not exists (select 1 from chuyen_khoa c where c.ten_khoa = v.ten);

-- Bệnh viện nào có khoa nào
insert into khoa_benh_vien (benh_vien_id, chuyen_khoa_id, ten_hien_thi)
select b.id, c.id, 'Khoa ' || c.ten_khoa
from (values
  ('Bệnh viện Nhân dân 115', 'Nội tổng quát'), ('Bệnh viện Nhân dân 115', 'Da liễu'),
  ('Bệnh viện Nhân dân 115', 'Mắt'),
  ('Bệnh viện Trưng Vương',  'Nhi'),           ('Bệnh viện Trưng Vương',  'Tai Mũi Họng'),
  ('Bệnh viện Trưng Vương',  'Nội tổng quát'),
  ('Bệnh viện TP. Thủ Đức',  'Nội tổng quát'), ('Bệnh viện TP. Thủ Đức',  'Nhi'),
  ('Bệnh viện Lê Văn Thịnh', 'Răng Hàm Mặt'),  ('Bệnh viện Lê Văn Thịnh', 'Da liễu')
) as v(bv, khoa)
join benh_vien b   on b.ten_benh_vien = v.bv
join chuyen_khoa c on c.ten_khoa = v.khoa
where not exists (
  select 1 from khoa_benh_vien k where k.benh_vien_id = b.id and k.chuyen_khoa_id = c.id
);
