-- BƯỚC 12: Phiếu tiền khám do Trợ lý AI (Qwen cục bộ) tổng hợp, lưu dạng có cấu trúc.
-- Chạy lại được nhiều lần.
--
-- luot_kham.phieu_tien_kham (jsonb), ví dụ:
--   { "nguoi_benh": "3 tuổi", "trieu_chung_chinh": "sốt, ho", "bat_dau_tu": "2 ngày",
--     "dien_bien": "sốt 38,5°C, ho khan", "trieu_chung_kem": "không khó thở",
--     "tien_su": "", "mo_ta_anh": "", "muc_do": "nen_kham_som",
--     "khoa_goi_y": ["Nhi"], "nguon": "Qwen3-VL cục bộ" }
-- Cột trieu_chung giữ vai trò: lời bệnh nhân tự ghi thêm.
-- Quyền xem: dùng chung RLS của luot_kham (bệnh nhân đó + bác sĩ của ca đó).

alter table luot_kham add column if not exists phieu_tien_kham jsonb;

alter table luot_kham drop constraint if exists luot_kham_phieu_hop_le;
alter table luot_kham add constraint luot_kham_phieu_hop_le check (
  phieu_tien_kham is null
  or (jsonb_typeof(phieu_tien_kham) = 'object' and length(phieu_tien_kham::text) <= 4000)
);

-- Hàm đặt lịch nhận thêm phiếu (tuỳ chọn). Bỏ bản cũ 2 tham số để không bị trùng tên.
drop function if exists public.dat_luot_kham(int, text);

create or replace function public.dat_luot_kham(
  p_ca_kham_id int,
  p_trieu_chung text default null,
  p_phieu jsonb default null
)
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
  if p_phieu is not null and jsonb_typeof(p_phieu) <> 'object' then
    raise exception 'Phiếu tiền khám không hợp lệ';
  end if;

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

  insert into luot_kham (benh_nhan_id, ca_kham_id, so_thu_tu, trang_thai, trieu_chung, phieu_tien_kham)
  values (v_uid, p_ca_kham_id, v_stt, 'cho_kham', nullif(trim(p_trieu_chung), ''), p_phieu)
  returning * into v_kq;

  update ca_kham set so_da_dang_ky = so_da_dang_ky + 1 where id = p_ca_kham_id;
  return v_kq;
end $$;

revoke all on function public.dat_luot_kham(int, text, jsonb) from public, anon;
grant execute on function public.dat_luot_kham(int, text, jsonb) to authenticated;
