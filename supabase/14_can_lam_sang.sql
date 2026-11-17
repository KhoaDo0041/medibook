-- BƯỚC 14: Cận lâm sàng (X-quang, xét nghiệm…) và sơ đồ bệnh viện để chỉ đường trong viện.
-- Chạy lại được nhiều lần.
--
-- Luồng: bác sĩ gửi chỉ định  -> lượt khám chuyển 'lam_cls'
--        bệnh nhân thanh toán trong app -> đi từng khu, bấm "Tôi đã đến" (app mô phỏng thực hiện,
--        gắn KẾT QUẢ MẪU) -> quay lại phòng khám -> lượt khám chuyển 'cho_doc_kq'
--        bác sĩ "Gọi số tiếp theo" ưu tiên người đã có kết quả -> đọc kết quả, kê đơn, hoàn tất.
-- Lưu ý: kết quả cận lâm sàng là KẾT QUẢ MẪU dùng cho demo, không phải kết quả y khoa thật.

-- ===== 1. Thêm 2 trạng thái lượt khám =====
--   lam_cls    : bệnh nhân đang đi làm cận lâm sàng
--   cho_doc_kq : đã làm xong, quay lại phòng chờ bác sĩ đọc kết quả
do $$
declare r record;
begin
  for r in
    select conname from pg_constraint
    where conrelid = 'public.luot_kham'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) like '%trang_thai%'
  loop
    execute format('alter table luot_kham drop constraint %I', r.conname);
  end loop;
end $$;
alter table luot_kham
  add constraint luot_kham_trang_thai_hop_le
  check (trang_thai in ('cho_kham', 'dang_kham', 'tam_hoan', 'lam_cls', 'cho_doc_kq',
                        'da_kham', 'da_huy', 'vang_mat'));

alter table luot_kham add column if not exists da_thanh_toan_cls boolean not null default false;
alter table luot_kham add column if not exists thoi_diem_quay_lai timestamptz;

-- ===== 2. Sơ đồ bệnh viện (sơ đồ MẪU dùng chung cho mọi bệnh viện) =====
-- Mỗi khu là một nút của đồ thị, đặt tại cửa ra hành lang (x, y);
-- (hx, hy, hw, hh) là khung chữ nhật để vẽ. Toạ độ theo lưới 100 x 140, 1 ô = 0,5 m.
-- Nút 'hanh_lang' là ngã rẽ trên hành lang, không vẽ khung.
create table if not exists khu_vuc (
  ma     text primary key,
  ten    text not null,
  mo_ta  text,
  loai   text not null check (loai in ('cong', 'tiep_don', 'thu_ngan', 'phong_kham', 'cls',
                                       'nha_thuoc', 'thang_may', 'wc', 'khac', 'hanh_lang')),
  tang   smallint not null,
  x real not null, y real not null,
  hx real, hy real, hw real, hh real
);

-- Lối đi hai chiều giữa hai nút, độ dài tính bằng mét (thang máy quy đổi 10 m mỗi tầng)
create table if not exists loi_di (
  tu     text not null references khu_vuc(ma) on delete cascade,
  den    text not null references khu_vuc(ma) on delete cascade,
  do_dai real not null check (do_dai > 0),
  primary key (tu, den)
);

insert into khu_vuc (ma, ten, mo_ta, loai, tang, x, y, hx, hy, hw, hh) values
  ('KHU_A', 'Khu A · Chẩn đoán hình ảnh', 'Chụp X-quang, siêu âm', 'cls', 1, 44, 26, 4, 8, 40, 36),
  ('PK_1', 'Khu phòng khám tầng 1', 'Phòng 101 – 120', 'phong_kham', 1, 44, 71, 4, 50, 40, 42),
  ('TIEP_DON', 'Tiếp đón · Lấy số', 'Quầy hướng dẫn, quầy BHYT', 'tiep_don', 1, 44, 110, 4, 98, 40, 24),
  ('NHA_THUOC', 'Nhà thuốc', 'Quầy 1 – 4', 'nha_thuoc', 1, 56, 23, 56, 8, 40, 30),
  ('TM_1', 'Thang máy', 'Tầng 1', 'thang_may', 1, 56, 54, 56, 44, 22, 20),
  ('WC_1', 'Nhà vệ sinh', '', 'wc', 1, 56, 78, 56, 70, 22, 16),
  ('THU_NGAN', 'Thu ngân', 'Đóng tiền viện phí, cận lâm sàng', 'thu_ngan', 1, 56, 110, 56, 98, 40, 24),
  ('CONG', 'Cổng chính', '', 'cong', 1, 50, 128, 36, 128, 28, 10),
  ('PK_2', 'Khu phòng khám tầng 2', 'Phòng 201 – 220', 'phong_kham', 2, 44, 50, 4, 8, 40, 84),
  ('KHU_C', 'Khu C · Thăm dò chức năng', 'Điện tim, đo chức năng hô hấp', 'cls', 2, 56, 23, 56, 8, 40, 30),
  ('TM_2', 'Thang máy', 'Tầng 2', 'thang_may', 2, 56, 54, 56, 44, 22, 20),
  ('WC_2', 'Nhà vệ sinh', '', 'wc', 2, 56, 78, 56, 70, 22, 16),
  ('CHO_2', 'Sảnh chờ tầng 2', '', 'khac', 2, 44, 110, 4, 98, 40, 24),
  ('PK_3', 'Khu phòng khám tầng 3', 'Phòng 301 – 320', 'phong_kham', 3, 44, 50, 4, 8, 40, 84),
  ('KHU_B', 'Khu B · Xét nghiệm', 'Lấy máu, nước tiểu', 'cls', 3, 56, 23, 56, 8, 40, 30),
  ('TM_3', 'Thang máy', 'Tầng 3', 'thang_may', 3, 56, 54, 56, 44, 22, 20),
  ('WC_3', 'Nhà vệ sinh', '', 'wc', 3, 56, 78, 56, 70, 22, 16),
  ('CHO_3', 'Sảnh chờ tầng 3', '', 'khac', 3, 44, 110, 4, 98, 40, 24),
  ('PK_4', 'Khu phòng khám tầng 4', 'Phòng 401 – 420', 'phong_kham', 4, 44, 50, 4, 8, 40, 84),
  ('HANH_CHINH', 'Khu hành chính', 'Phòng giám đốc, kế hoạch tổng hợp', 'khac', 4, 56, 23, 56, 8, 40, 30),
  ('TM_4', 'Thang máy', 'Tầng 4', 'thang_may', 4, 56, 54, 56, 44, 22, 20),
  ('WC_4', 'Nhà vệ sinh', '', 'wc', 4, 56, 78, 56, 70, 22, 16),
  ('CHO_4', 'Sảnh chờ tầng 4', '', 'khac', 4, 44, 110, 4, 98, 40, 24),
  ('H1_23', 'Hành lang', '', 'hanh_lang', 1, 50, 23, null, null, null, null),
  ('H1_26', 'Hành lang', '', 'hanh_lang', 1, 50, 26, null, null, null, null),
  ('H1_54', 'Hành lang', '', 'hanh_lang', 1, 50, 54, null, null, null, null),
  ('H1_71', 'Hành lang', '', 'hanh_lang', 1, 50, 71, null, null, null, null),
  ('H1_78', 'Hành lang', '', 'hanh_lang', 1, 50, 78, null, null, null, null),
  ('H1_110', 'Hành lang', '', 'hanh_lang', 1, 50, 110, null, null, null, null),
  ('H2_23', 'Hành lang', '', 'hanh_lang', 2, 50, 23, null, null, null, null),
  ('H2_50', 'Hành lang', '', 'hanh_lang', 2, 50, 50, null, null, null, null),
  ('H2_54', 'Hành lang', '', 'hanh_lang', 2, 50, 54, null, null, null, null),
  ('H2_78', 'Hành lang', '', 'hanh_lang', 2, 50, 78, null, null, null, null),
  ('H2_110', 'Hành lang', '', 'hanh_lang', 2, 50, 110, null, null, null, null),
  ('H3_23', 'Hành lang', '', 'hanh_lang', 3, 50, 23, null, null, null, null),
  ('H3_50', 'Hành lang', '', 'hanh_lang', 3, 50, 50, null, null, null, null),
  ('H3_54', 'Hành lang', '', 'hanh_lang', 3, 50, 54, null, null, null, null),
  ('H3_78', 'Hành lang', '', 'hanh_lang', 3, 50, 78, null, null, null, null),
  ('H3_110', 'Hành lang', '', 'hanh_lang', 3, 50, 110, null, null, null, null),
  ('H4_23', 'Hành lang', '', 'hanh_lang', 4, 50, 23, null, null, null, null),
  ('H4_50', 'Hành lang', '', 'hanh_lang', 4, 50, 50, null, null, null, null),
  ('H4_54', 'Hành lang', '', 'hanh_lang', 4, 50, 54, null, null, null, null),
  ('H4_78', 'Hành lang', '', 'hanh_lang', 4, 50, 78, null, null, null, null),
  ('H4_110', 'Hành lang', '', 'hanh_lang', 4, 50, 110, null, null, null, null)
on conflict (ma) do update set ten = excluded.ten, mo_ta = excluded.mo_ta, loai = excluded.loai, tang = excluded.tang,
  x = excluded.x, y = excluded.y, hx = excluded.hx, hy = excluded.hy, hw = excluded.hw, hh = excluded.hh;

insert into loi_di (tu, den, do_dai) values
  ('CHO_2', 'H2_110', 3.0),
  ('CHO_3', 'H3_110', 3.0),
  ('CHO_4', 'H4_110', 3.0),
  ('CONG', 'H1_110', 9.0),
  ('H1_110', 'H1_78', 16.0),
  ('H1_110', 'THU_NGAN', 3.0),
  ('H1_110', 'TIEP_DON', 3.0),
  ('H1_23', 'H1_26', 1.5),
  ('H1_23', 'NHA_THUOC', 3.0),
  ('H1_26', 'H1_54', 14.0),
  ('H1_26', 'KHU_A', 3.0),
  ('H1_54', 'H1_71', 8.5),
  ('H1_54', 'TM_1', 3.0),
  ('H1_71', 'H1_78', 3.5),
  ('H1_71', 'PK_1', 3.0),
  ('H1_78', 'WC_1', 3.0),
  ('H2_110', 'H2_78', 16.0),
  ('H2_23', 'H2_50', 13.5),
  ('H2_23', 'KHU_C', 3.0),
  ('H2_50', 'H2_54', 2.0),
  ('H2_50', 'PK_2', 3.0),
  ('H2_54', 'H2_78', 12.0),
  ('H2_54', 'TM_2', 3.0),
  ('H2_78', 'WC_2', 3.0),
  ('H3_110', 'H3_78', 16.0),
  ('H3_23', 'H3_50', 13.5),
  ('H3_23', 'KHU_B', 3.0),
  ('H3_50', 'H3_54', 2.0),
  ('H3_50', 'PK_3', 3.0),
  ('H3_54', 'H3_78', 12.0),
  ('H3_54', 'TM_3', 3.0),
  ('H3_78', 'WC_3', 3.0),
  ('H4_110', 'H4_78', 16.0),
  ('H4_23', 'H4_50', 13.5),
  ('H4_23', 'HANH_CHINH', 3.0),
  ('H4_50', 'H4_54', 2.0),
  ('H4_50', 'PK_4', 3.0),
  ('H4_54', 'H4_78', 12.0),
  ('H4_54', 'TM_4', 3.0),
  ('H4_78', 'WC_4', 3.0),
  ('TM_1', 'TM_2', 10),
  ('TM_2', 'TM_3', 10),
  ('TM_3', 'TM_4', 10)
on conflict (tu, den) do update set do_dai = excluded.do_dai;

-- ===== 3. Danh mục dịch vụ cận lâm sàng =====
create table if not exists dich_vu_cls (
  id           serial primary key,
  ma           text not null unique,
  ten          text not null,
  ma_khu       text not null references khu_vuc(ma),
  gia          int  not null check (gia >= 0),
  thoi_gian_phut int not null default 15,   -- thời gian chờ có kết quả (tham khảo)
  can_nhin_an  boolean not null default false,
  muc_dich     text,                        -- AI dùng để giải thích cho bệnh nhân
  chuan_bi     text,                        -- AI dùng để nhắc chuẩn bị
  ket_qua_mau  text                         -- kết quả mẫu gắn vào khi mô phỏng xong
);

insert into dich_vu_cls (ma, ten, ma_khu, gia, thoi_gian_phut, can_nhin_an, muc_dich, chuan_bi, ket_qua_mau) values
  ('XQ_NGUC', 'Chụp X-quang ngực thẳng', 'KHU_A', 120000, 15, false,
   'Xem phổi, tim và xương lồng ngực có tổn thương hay dấu hiệu viêm không.',
   'Tháo dây chuyền, kẹp tóc và đồ kim loại vùng ngực. Phụ nữ có thai cần báo trước cho kỹ thuật viên.',
   'Hai phế trường sáng đều, chưa thấy tổn thương nhu mô. Bóng tim không to. (Kết quả mẫu dùng cho demo)'),
  ('SA_BUNG', 'Siêu âm ổ bụng tổng quát', 'KHU_A', 180000, 20, true,
   'Quan sát gan, mật, tụy, thận, bàng quang để tìm nguyên nhân đau bụng.',
   'Nhịn ăn 6 – 8 tiếng. Uống nhiều nước và nhịn tiểu trước khi siêu âm.',
   'Gan, mật, tụy, lách, hai thận chưa ghi nhận bất thường. (Kết quả mẫu dùng cho demo)'),
  ('XN_MAU', 'Xét nghiệm công thức máu', 'KHU_B', 90000, 30, false,
   'Đếm hồng cầu, bạch cầu, tiểu cầu để biết có dấu hiệu nhiễm trùng hay thiếu máu không.',
   'Không cần nhịn ăn. Ngồi nghỉ vài phút trước khi lấy máu.',
   'Bạch cầu 11,2 G/L (tăng nhẹ); hồng cầu, tiểu cầu trong giới hạn. (Kết quả mẫu dùng cho demo)'),
  ('XN_DUONG', 'Xét nghiệm đường huyết lúc đói', 'KHU_B', 40000, 30, true,
   'Đo lượng đường trong máu để tầm soát đái tháo đường.',
   'Nhịn ăn ít nhất 8 tiếng, chỉ uống nước lọc.',
   'Glucose 5,4 mmol/L, trong giới hạn bình thường. (Kết quả mẫu dùng cho demo)'),
  ('XN_NUOC_TIEU', 'Tổng phân tích nước tiểu', 'KHU_B', 50000, 30, false,
   'Phát hiện nhiễm trùng đường tiểu và một số bệnh thận.',
   'Lấy nước tiểu giữa dòng vào lọ sạch được phát tại quầy.',
   'Các chỉ số trong giới hạn bình thường. (Kết quả mẫu dùng cho demo)'),
  ('DIEN_TIM', 'Đo điện tim (ECG)', 'KHU_C', 70000, 10, false,
   'Ghi lại hoạt động điện của tim để phát hiện rối loạn nhịp.',
   'Mặc áo dễ mở phần ngực, nằm yên và thở đều khi đo.',
   'Nhịp xoang đều, tần số 82 lần/phút. (Kết quả mẫu dùng cho demo)')
on conflict (ma) do update set ten = excluded.ten, ma_khu = excluded.ma_khu, gia = excluded.gia,
  thoi_gian_phut = excluded.thoi_gian_phut, can_nhin_an = excluded.can_nhin_an, muc_dich = excluded.muc_dich,
  chuan_bi = excluded.chuan_bi, ket_qua_mau = excluded.ket_qua_mau;

-- ===== 4. Chỉ định cận lâm sàng của một lượt khám =====
create table if not exists chi_dinh_cls (
  id             bigserial primary key,
  luot_kham_id   int not null references luot_kham(id) on delete cascade,
  dich_vu_id     int not null references dich_vu_cls(id),
  thu_tu         int not null,
  trang_thai     text not null default 'cho' check (trang_thai in ('cho', 'xong')),
  ket_qua        text,
  thoi_diem_xong timestamptz,
  unique (luot_kham_id, dich_vu_id)
);
create index if not exists chi_dinh_theo_luot on chi_dinh_cls (luot_kham_id);

-- ===== 5. Phân quyền =====
alter table khu_vuc enable row level security;
alter table loi_di enable row level security;
alter table dich_vu_cls enable row level security;
alter table chi_dinh_cls enable row level security;

drop policy if exists doc_khu_vuc on khu_vuc;
create policy doc_khu_vuc on khu_vuc for select to authenticated using (true);
drop policy if exists doc_loi_di on loi_di;
create policy doc_loi_di on loi_di for select to authenticated using (true);
drop policy if exists doc_dich_vu_cls on dich_vu_cls;
create policy doc_dich_vu_cls on dich_vu_cls for select to authenticated using (true);

-- Chỉ đọc: bệnh nhân của lượt khám hoặc bác sĩ của ca. Ghi qua các hàm bên dưới.
drop policy if exists doc_chi_dinh_cls on chi_dinh_cls;
create policy doc_chi_dinh_cls on chi_dinh_cls for select to authenticated using (
  exists (
    select 1 from luot_kham lk join ca_kham c on c.id = lk.ca_kham_id
    where lk.id = chi_dinh_cls.luot_kham_id
      and (lk.benh_nhan_id = auth.uid() or c.bac_si_id = auth.uid())
  )
);
revoke insert, update, delete on khu_vuc, loi_di, dich_vu_cls, chi_dinh_cls from anon, authenticated;

-- ===== 6. Bác sĩ gửi chỉ định =====
-- Thứ tự đi: dịch vụ cần nhịn ăn làm trước, sau đó theo tầng (đỡ phải lên xuống).
create or replace function public.gui_chi_dinh_cls(p_luot_kham_id int, p_dich_vu_ids int[])
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_luot luot_kham;
  v_ca   ca_kham;
  v_so   int;
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
  if v_luot.trang_thai <> 'dang_kham' then
    raise exception 'Chỉ gửi chỉ định khi bệnh nhân đang được khám';
  end if;
  if exists (select 1 from chi_dinh_cls where luot_kham_id = p_luot_kham_id) then
    raise exception 'Lượt khám này đã có chỉ định cận lâm sàng';
  end if;
  select count(*) into v_so from dich_vu_cls where id = any(coalesce(p_dich_vu_ids, '{}'));
  if v_so = 0 then raise exception 'Vui lòng chọn ít nhất một dịch vụ'; end if;
  if v_so > 6 then raise exception 'Chỉ định tối đa 6 dịch vụ'; end if;

  -- Gom theo khu (làm xong một khu mới sang khu khác); khu có dịch vụ cần nhịn ăn đi trước,
  -- còn lại đi theo tầng từ thấp lên cao.
  insert into chi_dinh_cls (luot_kham_id, dich_vu_id, thu_tu)
  select p_luot_kham_id, x.id,
         row_number() over (order by x.khu_nhin_an desc, x.tang, x.ma_khu, x.can_nhin_an desc, x.id)
  from (
    select d.id, d.ma_khu, d.can_nhin_an, k.tang,
           bool_or(d.can_nhin_an) over (partition by d.ma_khu) as khu_nhin_an
    from dich_vu_cls d join khu_vuc k on k.ma = d.ma_khu
    where d.id = any(p_dich_vu_ids)
  ) x;

  update luot_kham set trang_thai = 'lam_cls', da_thanh_toan_cls = false,
                       thoi_diem_quay_lai = null, ngay_cap_nhat = now()
  where id = p_luot_kham_id;
end $$;

-- ===== 7. Bệnh nhân thanh toán cận lâm sàng (mô phỏng, trả về số tiền) =====
create or replace function public.thanh_toan_cls(p_luot_kham_id int)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_luot luot_kham;
  v_tong int;
begin
  select * into v_luot from luot_kham where id = p_luot_kham_id and benh_nhan_id = auth.uid() for update;
  if not found then raise exception 'Không tìm thấy lượt khám của bạn'; end if;
  if v_luot.trang_thai <> 'lam_cls' then raise exception 'Lượt khám này không có chỉ định cần thanh toán'; end if;
  if v_luot.da_thanh_toan_cls then raise exception 'Bạn đã thanh toán rồi'; end if;

  select coalesce(sum(d.gia), 0) into v_tong
  from chi_dinh_cls cd join dich_vu_cls d on d.id = cd.dich_vu_id
  where cd.luot_kham_id = p_luot_kham_id;

  update luot_kham set da_thanh_toan_cls = true, ngay_cap_nhat = now() where id = p_luot_kham_id;
  return v_tong;
end $$;

-- ===== 8. Bệnh nhân đã đến khu và làm xong một chỉ định (mô phỏng: gắn kết quả mẫu) =====
create or replace function public.hoan_thanh_chi_dinh(p_chi_dinh_id bigint)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_cd   chi_dinh_cls;
  v_luot luot_kham;
begin
  select * into v_cd from chi_dinh_cls where id = p_chi_dinh_id for update;
  if not found then raise exception 'Không tìm thấy chỉ định'; end if;
  select * into v_luot from luot_kham where id = v_cd.luot_kham_id;
  if v_luot.benh_nhan_id is distinct from auth.uid() then
    raise exception 'Chỉ định này không phải của bạn';
  end if;
  if v_luot.trang_thai <> 'lam_cls' then raise exception 'Lượt khám không ở bước làm cận lâm sàng'; end if;
  if not v_luot.da_thanh_toan_cls then raise exception 'Vui lòng thanh toán trước khi làm cận lâm sàng'; end if;
  if v_cd.trang_thai = 'xong' then return; end if;

  update chi_dinh_cls set
    trang_thai = 'xong',
    ket_qua = (select ket_qua_mau from dich_vu_cls where id = v_cd.dich_vu_id),
    thoi_diem_xong = now()
  where id = p_chi_dinh_id;
end $$;

-- ===== 9. Bệnh nhân quay lại phòng khám =====
create or replace function public.quay_lai_phong_kham(p_luot_kham_id int)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_luot luot_kham;
  v_con  int;
begin
  select * into v_luot from luot_kham where id = p_luot_kham_id and benh_nhan_id = auth.uid() for update;
  if not found then raise exception 'Không tìm thấy lượt khám của bạn'; end if;
  if v_luot.trang_thai <> 'lam_cls' then raise exception 'Lượt khám không ở bước làm cận lâm sàng'; end if;
  select count(*) into v_con from chi_dinh_cls where luot_kham_id = p_luot_kham_id and trang_thai <> 'xong';
  if v_con > 0 then raise exception 'Bạn còn % chỉ định chưa làm', v_con; end if;

  update luot_kham set trang_thai = 'cho_doc_kq', thoi_diem_quay_lai = now(), ngay_cap_nhat = now()
  where id = p_luot_kham_id;
end $$;

-- ===== 10. Gọi số: ưu tiên người đã có kết quả cận lâm sàng quay lại =====
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
              where ca_kham_id = p_ca_kham_id and trang_thai in ('cho_doc_kq', 'cho_kham')
              order by (trang_thai = 'cho_doc_kq') desc, thoi_diem_quay_lai, so_thu_tu
              limit 1)
  returning * into v_kq;

  if v_kq.id is null then raise exception 'Không còn bệnh nhân chờ trong ca này'; end if;
  return v_kq;
end $$;

-- Mời một bệnh nhân cụ thể (người tạm hoãn vừa đến, người có kết quả CLS, hoặc gọi vượt số)
create or replace function public.bat_dau_kham(p_luot_kham_id int)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_luot luot_kham;
  v_dang luot_kham;
begin
  select * into v_luot from luot_kham where id = p_luot_kham_id for update;
  if not found then raise exception 'Không tìm thấy lượt khám'; end if;
  perform _ca_dang_dien_ra(v_luot.ca_kham_id);

  if v_luot.trang_thai not in ('cho_kham', 'tam_hoan', 'cho_doc_kq') then
    raise exception 'Bệnh nhân này không ở trạng thái chờ';
  end if;
  select * into v_dang from luot_kham
  where ca_kham_id = v_luot.ca_kham_id and trang_thai = 'dang_kham' limit 1;
  if found then
    raise exception 'Hãy hoàn tất hoặc tạm hoãn số % trước', lpad(v_dang.so_thu_tu::text, 2, '0');
  end if;

  update luot_kham set trang_thai = 'dang_kham', ngay_cap_nhat = now() where id = p_luot_kham_id;
end $$;

revoke all on function public.gui_chi_dinh_cls(int, int[])  from public, anon;
revoke all on function public.thanh_toan_cls(int)           from public, anon;
revoke all on function public.hoan_thanh_chi_dinh(bigint)   from public, anon;
revoke all on function public.quay_lai_phong_kham(int)      from public, anon;
revoke all on function public.goi_so_tiep_theo(int)         from public, anon;
revoke all on function public.bat_dau_kham(int)             from public, anon;
grant execute on function public.gui_chi_dinh_cls(int, int[]) to authenticated;
grant execute on function public.thanh_toan_cls(int)          to authenticated;
grant execute on function public.hoan_thanh_chi_dinh(bigint)  to authenticated;
grant execute on function public.quay_lai_phong_kham(int)     to authenticated;
grant execute on function public.goi_so_tiep_theo(int)        to authenticated;
grant execute on function public.bat_dau_kham(int)            to authenticated;
