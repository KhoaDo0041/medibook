# Database MediBook (Supabase / PostgreSQL)

Các file SQL được chạy lần lượt trong **Supabase → SQL Editor**. Mỗi file đều chạy lại được
nhiều lần mà không bị trùng dữ liệu. File sau có thể sửa lại hàm của file trước
(ví dụ 07 thay một phần của 06) — đây là lịch sử các bước đã làm.

| Thứ tự | File | Nội dung |
|---|---|---|
| 1 | `01_chinh_bang.sql` | Chỉnh bảng `ca_kham`, `luot_kham` cho luồng đặt lịch: khoá ngoại, ràng buộc, chỉ mục |
| 2 | `04_phong_kham.sql` | Thêm số phòng, tầng cho từng ca khám (chạy trước 02b) |
| 3 | `02a_benh_vien_khoa.sql` | Dữ liệu mẫu: bệnh viện, chuyên khoa, khoa của từng bệnh viện |
| 4 | `02b_bac_si_ca_kham.sql` | Gắn bác sĩ, tạo ca khám 14 ngày |
| 5 | `03_phan_quyen_va_dat_lich.sql` | Bật RLS cho mọi bảng; hàm đặt / huỷ lượt khám an toàn (cấp số thứ tự, chống trùng) |
| 6 | `05_them_bac_si.sql` | Tự tạo tài khoản `bacsiN@medibook.test` (mỗi khoa ≥ 2 bác sĩ). **Mật khẩu chỉ nhập trong SQL Editor, không ghi vào file** |
| 7 | `06_kham_benh.sql` | Bác sĩ gọi số, hoàn tất khám, vắng mặt |
| 8 | `07_tam_hoan.sql` | Tạm hoãn, tự chốt vắng mặt khi hết ca, khoá kết quả sau khi hoàn tất |
| 9 | `08_toa_do_that.sql` | Toạ độ thật của bệnh viện |
| 10 | `09_bac_si_nghi_viec.sql` | Bác sĩ nghỉ việc: chặn đăng nhập, huỷ lịch tương lai (hàm quản trị chỉ chạy được trong SQL Editor) |
| 11 | `10_ca_kham_thang_11.sql` | Thêm ca khám đến hết tháng 11 |
| 12 | `11_hang_cho.sql` | Hàng chờ thời gian thực: cột `so_dang_kham`, trigger, hàm `hang_cho_cua_toi`, bật Realtime cho `ca_kham` |
| 13 | `12_phieu_tien_kham.sql` | Phiếu tiền khám (AI tổng hợp) dạng jsonb trong `luot_kham`, hàm `dat_luot_kham` nhận thêm `p_phieu` |
| 14 | `13_don_thuoc_tai_kham.sql` | Danh mục thuốc mẫu (Thuốc A–E), bảng `don_thuoc_chi_tiet`, cột `ngay_tai_kham`; `hoan_tat_kham` nhận thêm đơn thuốc và ngày tái khám |

## Bảng nghiệp vụ (9 bảng)

`ho_so` · `benh_vien` · `chuyen_khoa` · `khoa_benh_vien` · `bac_si` · `ca_kham` · `luot_kham`
· `danh_muc_thuoc` · `don_thuoc_chi_tiet`
— tài khoản đăng nhập do Supabase Auth quản lý (`auth.users`).

## Trợ lý AI

Trợ lý AI chạy **cục bộ** (Ollama + Qwen3-VL trên máy trong mạng nội bộ), app gọi thẳng tới máy đó,
không dùng Edge Function hay dịch vụ AI trên Internet. Xem mục "Cài đặt máy chủ AI cục bộ" ở README gốc.
