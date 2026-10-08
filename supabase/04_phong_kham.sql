-- BƯỚC 4: Số phòng và tầng cho từng ca khám. Chạy lại được nhiều lần.
-- Đặt ở ca_kham (không phải bác sĩ) vì thực tế mỗi ca bác sĩ có thể ngồi phòng khác.

alter table ca_kham
  add column if not exists so_phong text,
  add column if not exists tang     smallint;

-- Dữ liệu mẫu: mỗi bác sĩ cố định một phòng; tầng theo chuyên khoa
update ca_kham c set
  tang     = 1 + (b.chuyen_khoa_id % 4),
  so_phong = ((1 + (b.chuyen_khoa_id % 4)) * 100 + 1 + abs(hashtext(b.id::text)) % 20)::text
from bac_si b
where b.id = c.bac_si_id and c.so_phong is null;

-- Kiểm tra: mỗi bác sĩ một phòng
select h.ho_ten, c.so_phong, c.tang, count(*) as so_ca
from ca_kham c join ho_so h on h.id = c.bac_si_id
group by h.ho_ten, c.so_phong, c.tang
order by c.tang, c.so_phong;
