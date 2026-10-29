# MediBook

**Ứng dụng đặt lịch khám bệnh, gọi số theo thời gian thực, tích hợp AI chạy cục bộ** — đồ án chuyên ngành.

AI hỗ trợ trọn quy trình **trước – trong – sau khám**, chạy hoàn toàn trên máy của bạn (Qwen3-VL qua Ollama),
không gọi dịch vụ AI nào trên Internet.

## Chức năng chính

**Bệnh nhân (app Android)**
- Đăng ký bằng email (mã OTP), đăng nhập, quên / đổi mật khẩu
- **Trước khám – Trợ lý AI:** kể triệu chứng hoặc chụp ảnh vùng da → AI hỏi thêm cho đủ thông tin → gợi ý chuyên khoa
  có trong hệ thống, cảnh báo cấp cứu (gọi 115). AI tổng hợp **phiếu tiền khám** gửi kèm lịch hẹn (bệnh nhân bật/tắt chia sẻ).
  Lịch sử trò chuyện lưu trên điện thoại.
- Danh sách bệnh viện sắp theo khoảng cách, chỉ đường bằng Google Maps
- Đặt lịch: bệnh viện → khoa → bác sĩ → ca khám, nhận số thứ tự, phòng, tầng
- **Hàng chờ trực tiếp:** số đang khám, số người trước bạn; tới lượt thì rung + đọc to "Tới lượt bạn rồi…"
- Lịch hẹn: huỷ lịch, xem kết quả khám, đơn thuốc, ngày tái khám, đặt lại bác sĩ cũ
- **Sau khám – Lịch uống thuốc:** khai giờ sinh hoạt (hoặc nói một câu để AI điền) → AI xếp giờ uống theo đơn,
  code kiểm tra lại theo luật (trước/sau ăn, không rơi vào giờ ngủ…) → xác nhận → **thông báo nhắc uống thuốc**
  và **nhắc tái khám**

**Bác sĩ**
- **Web bác sĩ** (Flutter Web, https://medibook-web.web.app): màn hình gọi số lớn, phiếu tiền khám, lịch sử khám,
  **kê đơn thuốc mẫu** (Thuốc A–E), **đặt ngày tái khám**, thống kê trong ngày, tự cập nhật (Supabase Realtime)
- App bác sĩ: ca khám theo ngày, gọi số / tạm hoãn / hoàn tất, hồ sơ bệnh nhân
- Tự chốt "vắng mặt" khi hết ca; kết quả bị khoá sau khi hoàn tất

## Công nghệ

| Phần | Công nghệ |
|---|---|
| Ứng dụng | Flutter / Dart (Android + Web cho bác sĩ) |
| Backend | Supabase: PostgreSQL + RLS, Auth, Realtime, hàm SQL `security definer` |
| AI | **Qwen3-VL 4B instruct chạy cục bộ bằng Ollama** (chữ + ảnh), ép trả JSON đúng khuôn |
| Thông báo | flutter_local_notifications (nhắc uống thuốc, tái khám), flutter_tts (đọc to khi tới lượt) |
| Vị trí | geolocator, công thức Haversine, Google Maps |
| Web hosting | Firebase Hosting |

## Cấu trúc thư mục

```
lib/
  core/            theme, định dạng, kết nối Supabase, đơn thuốc, widget dùng chung
  features/
    auth/          chào mừng, đăng nhập, đăng ký, mật khẩu, hồ sơ, điều hướng theo vai trò
    benh_nhan/     trang chủ bệnh nhân, thẻ hàng chờ
    dat_lich/      chọn bệnh viện / bác sĩ / ca, xác nhận, lịch hẹn, kết quả khám
    bac_si/        app bác sĩ: lịch khám, khám bệnh, bệnh nhân của tôi
    web_bac_si/    trang web bác sĩ (màn hình gọi số, kê đơn, tái khám)
    tro_ly_ai/     trợ lý AI (gọi Ollama), phiếu tiền khám, lịch sử chat
    thuoc/         giờ sinh hoạt, AI xếp lịch uống thuốc, thông báo nhắc
supabase/          các file SQL chạy theo thứ tự (xem supabase/README.md)
web/               cấu hình Flutter Web
```

## Chạy dự án

### 1. Database (Supabase)

Chạy lần lượt các file trong `supabase/` bằng **Supabase → SQL Editor** (thứ tự ở `supabase/README.md`).
Sửa `lib/core/supabase_config.dart` thành URL và khoá **anon/publishable** của project Supabase của bạn
(khoá này được phép nằm trong app vì quyền truy cập do RLS quyết định).

### 2. Ứng dụng

```bash
flutter pub get
flutter run                 # app Android (bệnh nhân / bác sĩ)
flutter run -d chrome       # web bác sĩ
```

Chưa cài máy chủ AI thì app vẫn chạy bình thường: Trợ lý AI tự dùng **gợi ý theo từ khoá**,
lịch uống thuốc tự xếp **theo luật**.

## Cài đặt máy chủ AI cục bộ (Ollama + Qwen3-VL)

AI chạy trên một máy tính (laptop) trong **cùng mạng wifi / hotspot** với điện thoại. Điện thoại gửi câu hỏi tới máy này
qua cổng `11434`. Không cần khoá API, dữ liệu sức khoẻ không rời khỏi mạng nội bộ.

**Cấu hình khuyến nghị:** GPU NVIDIA ~4 GB VRAM trở lên (đã chạy tốt trên Quadro P1000 4 GB), RAM 16 GB.
Không có GPU vẫn chạy được bằng CPU nhưng chậm hơn (mỗi câu trả lời ~30–60 giây).

### Bước 1 — Cài Ollama và tải model

Tải Ollama tại https://ollama.com/download (Windows: chạy `irm https://ollama.com/install.ps1 | iex` trong PowerShell).
Khi mở lần đầu, chọn **"No thanks, I'll use Ollama locally"** (không dùng bản cloud).

```powershell
ollama pull qwen3-vl:4b-instruct      # ~3,3 GB, đọc được cả chữ và ảnh
ollama run qwen3-vl:4b-instruct       # thử chat, gõ /bye để thoát
```

> Dùng bản **`-instruct`**. Bản `qwen3-vl:4b` mặc định là bản "Thinking", suy luận dài trước khi trả lời nên rất chậm.
> Không dùng các bản có đuôi `-cloud` (chạy trên máy chủ của Ollama, không phải cục bộ).

Tuỳ chọn — lưu model sang ổ khác: `setx OLLAMA_MODELS "D:\ollama_models"` rồi khởi động lại Ollama.

### Bước 2 — Cho phép điện thoại kết nối tới Ollama

Mặc định Ollama chỉ nhận kết nối từ chính máy đó.

**Windows**

```powershell
# PowerShell thường
setx OLLAMA_HOST "0.0.0.0"
```
Thoát Ollama (chuột phải biểu tượng con lạc đà ở khay hệ thống → **Quit Ollama**) rồi mở lại.

```powershell
# PowerShell chạy bằng quyền Administrator: mở cổng 11434 cho mạng riêng
New-NetFirewallRule -DisplayName "Ollama MediBook" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow -Profile Private,Domain
```
Đặt mạng wifi đang dùng là **Private**: Settings → Network & internet → Wi-Fi → (tên mạng) → Network profile type: Private.

**macOS / Linux**

```bash
# macOS
launchctl setenv OLLAMA_HOST "0.0.0.0"     # rồi mở lại app Ollama
# Linux (systemd)
sudo systemctl edit ollama                  # thêm: [Service]  Environment="OLLAMA_HOST=0.0.0.0"
sudo systemctl restart ollama
```

### Bước 3 — Lấy IP của máy và kiểm tra

```powershell
ipconfig        # Windows: lấy "IPv4 Address" của Wi-Fi, VD 192.168.1.5
```
Trên điện thoại (cùng wifi), mở trình duyệt vào `http://<IP>:11434` → thấy **"Ollama is running"** là thông.

### Bước 4 — Nhập địa chỉ trong app

App bệnh nhân → tab **Trợ lý AI** → nút **🕘 Lịch sử** → **Máy chủ AI cục bộ** → nhập IP (VD `192.168.1.5`)
→ **Kiểm tra** → **Lưu**. Đổi mạng (VD dùng hotspot khi demo) thì chỉ cần sửa IP ở đây, không phải build lại app.

Địa chỉ và tên model mặc định nằm ở `lib/features/tro_ly_ai/cau_hinh_ai.dart`.

### Gỡ lỗi nhanh

| Hiện tượng | Cách xử lý |
|---|---|
| App báo "Máy chủ AI đang không kết nối được…" | Kiểm tra Ollama đang chạy, cùng wifi, IP đúng (IP có thể đổi sau khi khởi động lại máy) |
| Điện thoại mở `http://IP:11434` không được | Đã `setx OLLAMA_HOST` và **khởi động lại Ollama** chưa; tường lửa; mạng có để Private không |
| Wifi trường / quán cà phê không kết nối được | Nhiều mạng công cộng chặn các máy nói chuyện với nhau → dùng hotspot của điện thoại |
| `ollama list` trống sau khi đổi `OLLAMA_MODELS` | Model vẫn ở thư mục cũ: chép sang thư mục mới hoặc `ollama pull` lại |
| Câu trả lời đầu tiên rất lâu | Lần đầu phải nạp model vào GPU (~15–30 giây); app tự "khởi động" model khi mở tab Trợ lý AI |

## Web bác sĩ (Firebase Hosting)

```bash
flutter build web --release
firebase deploy --only hosting        # cần Firebase CLI: npm install -g firebase-tools
```

## Bảo mật

- Quyền truy cập dữ liệu do **RLS** trên Supabase quyết định; thao tác quan trọng đi qua hàm SQL có kiểm tra `auth.uid()`.
- Không có khoá bí mật trong repo (mật khẩu bác sĩ chỉ nhập trong SQL Editor).
- Hội thoại với AI, giờ sinh hoạt, lịch uống thuốc **chỉ lưu trên điện thoại**; phiếu tiền khám chỉ gửi khi bệnh nhân đồng ý.
- AI chỉ gợi ý khoa và xếp giờ uống theo đúng đơn bác sĩ — không chẩn đoán, không kê thuốc, không đổi liều.
