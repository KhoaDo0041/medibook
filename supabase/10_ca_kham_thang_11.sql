-- BƯỚC 10: Thêm ca khám cho mọi bác sĩ đang làm việc từ hôm nay đến hết 30/11/2026.
-- Cùng quy tắc với file 02b: ca sáng 07:30-11:30 (20 chỗ), ca chiều 13:30-16:30 (15 chỗ),
-- nghỉ Chủ nhật, mỗi bác sĩ nghỉ thêm khoảng 1/3 số ngày. Phòng/tầng giữ như cũ.
-- Ca nào đã có thì bỏ qua (on conflict) nên chạy lại nhiều lần không bị trùng.
-- Bác sĩ đã nghỉ việc (trang_thai = 'nghi_viec') không được thêm ca.

insert into ca_kham (bac_si_id, khoa_benh_vien_id, ngay_kham, gio_bat_dau, gio_ket_thuc, so_luong_toi_da, tang, so_phong)
select b.id, k.id, d::date, ca.bd, ca.kt, ca.sl,
       1 + (b.chuyen_khoa_id % 4),
       ((1 + (b.chuyen_khoa_id % 4)) * 100 + 1 + abs(hashtext(b.id::text)) % 20)::text
from bac_si b
join khoa_benh_vien k
  on k.benh_vien_id = b.benh_vien_id and k.chuyen_khoa_id = b.chuyen_khoa_id
cross join generate_series(current_date, date '2026-11-30', interval '1 day') as d
cross join (values ('07:30'::time, '11:30'::time, 20),
                   ('13:30'::time, '16:30'::time, 15)) as ca(bd, kt, sl)
where b.trang_thai = 'da_duyet'
  and extract(isodow from d) <> 7
  and (extract(doy from d)::int + abs(hashtext(b.id::text))) % 3 <> 0
on conflict (bac_si_id, ngay_kham, gio_bat_dau) do nothing;

-- Kiểm tra: số ca của từng bác sĩ trong tháng 11 và ngày khám xa nhất
select h.ho_ten, ck.ten_khoa, bv.ten_benh_vien,
       count(ca.id) filter (where ca.ngay_kham between date '2026-11-01' and date '2026-11-30') as so_ca_thang_11,
       max(ca.ngay_kham) as ngay_xa_nhat
from bac_si b
join ho_so h        on h.id = b.id
join benh_vien bv   on bv.id = b.benh_vien_id
join chuyen_khoa ck on ck.id = b.chuyen_khoa_id
left join ca_kham ca on ca.bac_si_id = b.id
where b.trang_thai = 'da_duyet'
group by h.ho_ten, ck.ten_khoa, bv.ten_benh_vien
order by bv.ten_benh_vien, ck.ten_khoa;
