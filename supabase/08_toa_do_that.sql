-- BƯỚC 8: Sửa toạ độ bệnh viện cho đúng thực tế (toạ độ mẫu trước đây chỉ gần đúng).
-- Cách lấy: Google Maps trên máy tính → chuột phải đúng cổng/toà nhà bệnh viện
-- → bấm vào dòng số đầu tiên (VD "10.77, 106.65") để copy. Số trước là vi_do, số sau là kinh_do.
-- Thay 0, 0 bằng số thật rồi chạy. Dòng nào chưa thay sẽ tự bỏ qua (where vi_do_moi <> 0).

with moi(ten, vi_do_moi, kinh_do_moi) as (values
  ('Bệnh viện Chợ Rẫy',                   10.757278232451926, 106.66065059599822),
  ('Bệnh viện Nhi Đồng 1',                 10.769402357727945, 106.67332754092388),
  ('Bệnh viện Tai Mũi Họng TP.HCM',        10.784823839479932, 106.68390676768473),
  ('Bệnh viện Tim Tâm Đức',                10.733497597825828, 106.7179601288789),
  ('Bệnh viện Da Liễu TP.HCM',             10.776906652220823, 106.68658838177353),
  ('Phòng khám Đa khoa Quốc tế Yersin',    10.7785, 106.6974),
  ('Bệnh viện TP. Thủ Đức',                10.864603495473952, 106.74578961397269),
  ('Bệnh viện Nhân dân 115',               10.774969981504197, 106.66704575909463),
  ('Bệnh viện Trưng Vương',                10.76978575835938, 106.65850677120206),
  ('Bệnh viện Lê Văn Thịnh',               10.782483417910916, 106.76801646155901)
)
update benh_vien b
set vi_do = m.vi_do_moi, kinh_do = m.kinh_do_moi
from moi m
where b.ten_benh_vien = m.ten and m.vi_do_moi <> 0;

-- Kiểm tra
select id, ten_benh_vien, vi_do, kinh_do from benh_vien order by id;
