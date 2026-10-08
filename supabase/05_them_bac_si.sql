-- BƯỚC 5: Mỗi khoa của mỗi bệnh viện có ít nhất 2 bác sĩ (tự tạo tài khoản bacsiN@medibook.test).
-- CÁCH CHẠY: dán vào SQL Editor, thay NHAP_MAT_KHAU_TAI_DAY bằng mật khẩu chung của bác sĩ
-- NGAY TRONG SQL EDITOR (đừng sửa trong file này — repo đang Public). Chạy lại được nhiều lần.

do $$
declare
  v_mat_khau text := 'NHAP_MAT_KHAU_TAI_DAY';
  v_so_bac_si_moi_khoa int := 2;

  v_ho    text[] := array['Nguyễn','Trần','Lê','Phạm','Hoàng','Võ','Đặng','Bùi','Đỗ','Hồ','Ngô','Dương','Lý','Huỳnh','Phan','Trương'];
  v_dem   text[] := array['Văn','Thị','Minh','Thanh','Quốc','Ngọc','Hữu','Thu','Gia','Đức','Mỹ','Anh'];
  v_ten   text[] := array['Bảo','Chi','Duy','Giang','Hải','Hằng','Khoa','Linh','Long','Mai','Nga','Nhân',
                          'Oanh','Phong','Quân','Quỳnh','Sơn','Thảo','Trí','Trinh','Tuấn','Uyên','Vy','Yến'];
  v_hoc_vi text[] := array['BS.CKI','ThS.BS','BS.CKII','TS.BS','BS.CKI'];

  v_k     record;
  v_so    int;
  v_uid   uuid;
  v_email text;
  v_ho_ten text;
  v_nam_kn int;
  i       int;
begin
  if v_mat_khau = 'NHAP_MAT_KHAU_TAI_DAY' then
    raise exception 'Hãy thay NHAP_MAT_KHAU_TAI_DAY bằng mật khẩu chung của tài khoản bác sĩ';
  end if;

  -- Số thứ tự email tiếp theo (bacsi13, bacsi14, ...)
  select coalesce(max(substring(email from '^bacsi(\d+)@medibook\.test$')::int), 0)
    into v_so from auth.users where email ~ '^bacsi\d+@medibook\.test$';

  for v_k in
    select k.benh_vien_id, k.chuyen_khoa_id, c.ten_khoa,
           (select count(*) from bac_si b
             where b.benh_vien_id = k.benh_vien_id and b.chuyen_khoa_id = k.chuyen_khoa_id
               and b.trang_thai = 'da_duyet') as hien_co
    from khoa_benh_vien k join chuyen_khoa c on c.id = k.chuyen_khoa_id
    order by k.id
  loop
    for i in 1 .. (v_so_bac_si_moi_khoa - v_k.hien_co) loop
      v_so     := v_so + 1;
      v_uid    := gen_random_uuid();
      v_email  := 'bacsi' || v_so || '@medibook.test';
      v_ho_ten := v_ho[1 + v_so % 16] || ' ' || v_dem[1 + (v_so * 7) % 12] || ' ' || v_ten[1 + (v_so * 5) % 24];
      v_nam_kn := 5 + (v_so * 3) % 20;

      -- Tài khoản đăng nhập (đã xác nhận email)
      insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                              raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                              confirmation_token, email_change, email_change_token_new, recovery_token)
      values ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', v_email,
              extensions.crypt(v_mat_khau, extensions.gen_salt('bf')), now(),
              '{"provider":"email","providers":["email"]}', jsonb_build_object('ho_ten', v_ho_ten),
              now(), now(), '', '', '', '');

      insert into auth.identities (user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (v_uid, v_uid::text,
              jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
              'email', now(), now(), now());

      -- Hồ sơ + bác sĩ
      insert into ho_so (id, ho_ten, vai_tro) values (v_uid, v_ho_ten, 'bac_si')
      on conflict (id) do update set ho_ten = excluded.ho_ten, vai_tro = 'bac_si';

      insert into bac_si (id, chuyen_khoa_id, benh_vien_id, hoc_vi, so_nam_kinh_nghiem, trang_thai, gioi_thieu)
      values (v_uid, v_k.chuyen_khoa_id, v_k.benh_vien_id, v_hoc_vi[1 + v_so % 5], v_nam_kn, 'da_duyet',
              v_nam_kn || ' năm kinh nghiệm khám và điều trị chuyên khoa ' || v_k.ten_khoa || '.');
    end loop;
  end loop;
end $$;

-- Ca khám 14 ngày tới cho bác sĩ chưa có ca (giống 02b, kèm phòng/tầng)
insert into ca_kham (bac_si_id, khoa_benh_vien_id, ngay_kham, gio_bat_dau, gio_ket_thuc, so_luong_toi_da, tang, so_phong)
select b.id, k.id, d::date, ca.bd, ca.kt, ca.sl,
       1 + (b.chuyen_khoa_id % 4),
       ((1 + (b.chuyen_khoa_id % 4)) * 100 + 1 + abs(hashtext(b.id::text)) % 20)::text
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

-- Kiểm tra: mỗi khoa của mỗi bệnh viện có bao nhiêu bác sĩ
select bv.ten_benh_vien, ck.ten_khoa, count(b.id) as so_bac_si
from khoa_benh_vien k
join benh_vien bv   on bv.id = k.benh_vien_id
join chuyen_khoa ck on ck.id = k.chuyen_khoa_id
left join bac_si b  on b.benh_vien_id = k.benh_vien_id and b.chuyen_khoa_id = k.chuyen_khoa_id
group by bv.ten_benh_vien, ck.ten_khoa
order by bv.ten_benh_vien, ck.ten_khoa;
