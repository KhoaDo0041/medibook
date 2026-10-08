-- BƯỚC 1: Chỉnh bảng cho luồng đặt lịch (đã chạy trên Supabase). Chạy lại nhiều lần không lỗi.

alter table ca_kham
  add column if not exists bac_si_id uuid references bac_si(id) on delete cascade;

alter table ca_kham drop constraint if exists ca_kham_khong_trung;
alter table ca_kham
  add constraint ca_kham_khong_trung unique (bac_si_id, ngay_kham, gio_bat_dau);

alter table ca_kham drop constraint if exists ca_kham_hop_le;
alter table ca_kham
  add constraint ca_kham_hop_le check (
    gio_ket_thuc > gio_bat_dau
    and so_luong_toi_da > 0
    and so_da_dang_ky between 0 and so_luong_toi_da
  );

alter table luot_kham
  add column if not exists trieu_chung    text,
  add column if not exists chan_doan      text,
  add column if not exists ghi_chu_bac_si text,
  add column if not exists ngay_cap_nhat  timestamptz;

alter table luot_kham drop constraint if exists luot_kham_trang_thai_hop_le;
alter table luot_kham
  add constraint luot_kham_trang_thai_hop_le
  check (trang_thai in ('cho_kham', 'dang_kham', 'da_kham', 'da_huy'));

alter table luot_kham drop constraint if exists luot_kham_stt_duy_nhat;
alter table luot_kham
  add constraint luot_kham_stt_duy_nhat unique (ca_kham_id, so_thu_tu);

drop index if exists luot_kham_mot_lan_moi_ca;
create unique index luot_kham_mot_lan_moi_ca
  on luot_kham (benh_nhan_id, ca_kham_id)
  where trang_thai <> 'da_huy';

create index if not exists ca_kham_theo_bac_si_ngay on ca_kham (bac_si_id, ngay_kham);
create index if not exists luot_kham_theo_benh_nhan on luot_kham (benh_nhan_id);
