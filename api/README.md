# MediBook Web API (ASP.NET Core)

Web API trung gian giữa ứng dụng Flutter (bệnh nhân, bác sĩ, web bác sĩ) và cơ sở dữ liệu PostgreSQL trên Supabase.

```
Flutter app ──HTTPS + Bearer token──▶ MediBook.Api (Render) ──SQL──▶ PostgreSQL (Supabase)
     │                                                                   ▲
     └── đăng nhập / đăng ký / OTP: Supabase Auth ───────────────────────┘
```

- **Xác thực:** app đăng nhập bằng Supabase Auth như cũ, rồi gửi `access_token` trong header
  `Authorization: Bearer ...`. API kiểm tra chữ ký token bằng khoá công khai (JWKS, ES256) của Supabase.
- **Phân quyền:** mỗi yêu cầu chạy SQL trong một giao dịch với vai trò `authenticated` và id người dùng
  lấy từ token, nên mọi hàm SQL (`auth.uid()`) và chính sách Row Level Security vẫn giữ nguyên.
- **Swagger:** mở `<link-api>/swagger` để xem và thử từng API (bấm **Authorize**, dán access token).

## Danh sách API

| Nhóm | Phương thức & đường dẫn | Mô tả |
|---|---|---|
| Hệ thống | `GET /api/health` | Kiểm tra API còn sống (không cần token) |
| Tài khoản | `GET /api/tai-khoan/ho-so` | Hồ sơ người đang đăng nhập |
| | `GET /api/tai-khoan/con-hoat-dong` | Bác sĩ còn làm việc không |
| Danh mục | `GET /api/benh-vien` | Danh sách bệnh viện |
| | `GET /api/benh-vien/{id}/khoa` | Các khoa của bệnh viện |
| | `GET /api/benh-vien/{id}/bac-si` | Bác sĩ của bệnh viện |
| | `GET /api/chuyen-khoa` | Danh sách chuyên khoa |
| | `GET /api/chuyen-khoa/{id}/benh-vien` | Bệnh viện có chuyên khoa |
| | `GET /api/ca-kham?bacSiIds=&tuNgay=&denNgay=` | Ca khám của bác sĩ |
| | `GET /api/danh-muc-thuoc` | Thuốc mẫu (Thuốc A – E) |
| Bệnh nhân | `POST /api/luot-kham` | Đặt lượt khám (kèm phiếu tiền khám) |
| | `POST /api/luot-kham/{id}/huy` | Huỷ lượt khám |
| | `GET /api/luot-kham/cua-toi` | Lịch hẹn của tôi |
| | `GET /api/luot-kham/{id}/hang-cho` | Hàng chờ: số đang khám, số người phía trước |
| | `GET /api/luot-kham/{id}/don-thuoc` | Đơn thuốc của lượt khám |
| Bác sĩ | `GET /api/bac-si/noi-cong-tac` | Khoa, bệnh viện công tác |
| | `GET /api/bac-si/ca?ngay=` | Ca trong ngày kèm danh sách bệnh nhân |
| | `GET /api/bac-si/benh-nhan` | Bệnh nhân đã khám |
| | `GET /api/bac-si/benh-nhan/{id}/lich-su` | Lịch sử khám của một bệnh nhân |
| | `POST /api/bac-si/ca/{id}/goi-so-tiep-theo` | Gọi số tiếp theo |
| | `POST /api/bac-si/luot-kham/{id}/bat-dau` | Mời bệnh nhân vào khám |
| | `POST /api/bac-si/luot-kham/{id}/tam-hoan` | Tạm hoãn (chưa có mặt) |
| | `POST /api/bac-si/luot-kham/{id}/hoan-tat` | Hoàn tất khám: chẩn đoán, lời dặn, đơn thuốc, ngày tái khám |

Lỗi nghiệp vụ trả về HTTP 400 dạng `{ "message": "Bạn đã đặt ca này rồi" }`.

## Biến môi trường (không ghi vào mã nguồn)

| Biến | Giá trị |
|---|---|
| `DB_CONNECTION` | Chuỗi kết nối **Session pooler** của Supabase (Supabase → Connect → Session pooler), dạng: `Host=aws-0-<vùng>.pooler.supabase.com;Port=5432;Database=postgres;Username=postgres.<project-ref>;Password=<mật khẩu database>;SSL Mode=Require;Trust Server Certificate=true` |
| `SUPABASE_URL` | `https://ckiddvvryeduwnmopgik.supabase.co` |

## Chạy trên máy

```bash
cd api/MediBook.Api
dotnet user-secrets init
dotnet user-secrets set DB_CONNECTION "<chuỗi kết nối>"
dotnet run
# mở http://localhost:5260/swagger
```

## Deploy lên Render (Docker)

1. Render → service web (tạo mới, hoặc mở service cũ muốn dùng lại link) → **Settings**.
2. **Repository:** `KhoaDo0041/medibook`, **Branch:** nhánh chứa thư mục `api/`.
3. **Root Directory:** `api/MediBook.Api` · **Runtime:** Docker (Render tự dùng `Dockerfile`).
4. **Environment:** thêm `DB_CONNECTION`, `SUPABASE_URL`.
5. **Health Check Path:** `/api/health` → **Manual Deploy → Deploy latest commit**.
6. Mở `https://<tên-service>.onrender.com/swagger` để kiểm tra, rồi dán link vào `lib/core/api_config.dart`.

Bản Render miễn phí sẽ "ngủ" sau 15 phút không có ai gọi; lần gọi đầu tiên có thể mất khoảng 50 giây.
