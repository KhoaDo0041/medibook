# MediBook

**Ứng dụng đặt lịch khám bệnh trực tuyến, hiển thị khoảng cách, tích hợp AI** — đồ án chuyên ngành.

## Chức năng chính

**Bệnh nhân**
- Đăng ký bằng email (mã OTP), đăng nhập, quên / đổi mật khẩu
- Trợ lý AI (Google Gemini): kể triệu chứng hoặc chụp ảnh → gợi ý chuyên khoa, cảnh báo cấp cứu (gọi 115)
- Danh sách bệnh viện sắp xếp theo khoảng cách từ vị trí hiện tại, chỉ đường bằng Google Maps
- Đặt lịch: bệnh viện → khoa → bác sĩ → ca khám, nhận số thứ tự, phòng và tầng
- Lịch hẹn: huỷ lịch, xem kết quả khám, đặt lại bác sĩ đã khám

**Bác sĩ**
- Xem ca khám theo ngày, gọi số tiếp theo, bắt đầu / tạm hoãn / hoàn tất khám, ghi kết quả
- Tự chốt "vắng mặt" khi hết ca; kết quả bị khoá sau khi hoàn tất
- Danh sách và hồ sơ bệnh nhân đã khám

## Công nghệ

| Phần | Công nghệ |
|---|---|
| Ứng dụng | Flutter / Dart (Android) |
| Backend | Supabase: PostgreSQL + RLS, Auth, Edge Functions (Deno/TypeScript) |
| AI | Google Gemini API (gọi qua Edge Function, key không nằm trong app) |
| Vị trí | geolocator, công thức Haversine, Google Maps (mở bằng url_launcher) |

## Cấu trúc thư mục

```
lib/
  core/            theme, định dạng ngày giờ, kết nối Supabase, widget dùng chung
  features/
    auth/          chào mừng, đăng nhập, đăng ký, mật khẩu, hồ sơ
    benh_nhan/     trang chủ bệnh nhân
    dat_lich/      chọn bệnh viện / bác sĩ / ca, phiếu khám, lịch hẹn
    bac_si/        trang chủ bác sĩ, khám bệnh, bệnh nhân của tôi
    tro_ly_ai/     trợ lý AI
supabase/          file SQL theo thứ tự + Edge Function (xem supabase/README.md)
```

## Chạy dự án

```
flutter pub get
flutter run
```

Database được dựng bằng các file trong `supabase/` (xem `supabase/README.md`).
Khoá bí mật (Gemini, mật khẩu bác sĩ) chỉ cấu hình trên Supabase, không có trong repo.
