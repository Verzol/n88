# Proposal — Web app quản lý đội bóng & quỹ đội

> Phiên bản: v3 · Cập nhật: 2026-10-26
> Trạng thái: Đã chốt phạm vi MVP và các câu hỏi ở mục 10. Đặc tả chi tiết: [SRS.md](SRS.md), thiết kế: [DESIGN.md](DESIGN.md).

## 1. Mục tiêu

Xây dựng web app giúp đội bóng phong trào quản lý thành viên và **thu chi quỹ đội minh bạch**:

- Ban quản lý (Đội trưởng, Đội phó) tạo các đợt thu, xác nhận thanh toán, ghi khoản chi.
- Thành viên biết mình cần đóng bao nhiêu, đóng bằng QR ngân hàng, xem được tình hình quỹ.
- Dữ liệu quỹ được công khai qua trang web chỉ-xem và một Google Sheet chỉ-xem.

## 2. Phạm vi

### Trong MVP

- Quản lý thành viên
- Đợt thu (tạo thủ công)
- Thanh toán qua chuyển khoản ngân hàng + xác nhận
- Khoản chi
- Dashboard Admin và Dashboard Thành viên
- Trang công khai (không cần đăng nhập)
- Đồng bộ một chiều sang Google Sheet

### Tạm hoãn (sau MVP)

- Trận đấu: lịch, điểm danh, vote, tỷ số, ghi bàn
- Chia đội, thống kê cầu thủ, MVP
- Bot thông báo (Telegram/Zalo)
- Tự động đối soát chuyển khoản qua webhook ngân hàng (SePay/Casso)
- Quản lý nhiều đội

## 3. Vai trò & phân quyền

Có ba vai trò: **Đội trưởng**, **Đội phó**, **Thành viên**. Ngoài ra có khách xem trang công khai mà không đăng nhập.

| Quyền                                                        | Đội trưởng | Đội phó | Thành viên | Khách (công khai) |
| ------------------------------------------------------------- | :------------: | :--------: | :----------: | :-----------------: |
| Xem số dư, sao kê thu chi, tiến độ đợt thu            |       ✓       |     ✓     |      ✓      |         ✓         |
| Xem khoản của mình, lấy QR, báo "đã chuyển"           |       ✓       |     ✓     |      ✓      |                    |
| Tạo/đóng đợt thu, ghi khoản chi                         |       ✓       |     ✓     |              |                    |
| Xác nhận / từ chối thanh toán, ghi hộ "đã nhận"      |       ✓       |     ✓     |              |                    |
| Thêm/sửa thành viên, đổi vai trò                       |       ✓       |     ✓     |              |                    |
| Miễn khoản phải đóng                                     |       ✓       |            |              |                    |
| Hủy thanh toán đã xác nhận, sửa số tiền đã chốt   |       ✓       |            |              |                    |
| Cấu hình tài khoản ngân hàng, QR, mức quỹ mặc định |       ✓       |            |              |                    |

## 4. Thành viên

| Trường                 | Kiểu                                    | Ghi chú                                                 |
| ------------------------ | ---------------------------------------- | -------------------------------------------------------- |
| Họ tên                 | text                                     | bắt buộc                                               |
| Email                  | text, có thể trống                    | dùng để liên kết khi thành viên đăng nhập     |
| Số điện thoại        | text                                     |                                                          |
| Số áo                  | số nguyên, có thể trống             | không trùng giữa các thành viên đang Hoạt động |
| Vị trí                 | ENUM `GK` / `DF` / `MF` / `FW`   | Thủ môn / Hậu vệ / Tiền vệ / Tiền đạo           |
| Đối tượng            | ENUM `regular` / `student`           | Thường / Học sinh, dùng để tính mức quỹ         |
| Trạng thái             | ENUM `active` / `inactive`           | Hoạt động / Không hoạt động                       |
| Vai trò                 | ENUM `captain` / `vice` / `member` |                                                          |
| Tài khoản đăng nhập | liên kết, có thể trống              | gắn khi thành viên đăng nhập lần đầu            |

## 5. Đợt thu

Mọi khoản thu (quỹ tháng, tiền áo, liên hoan, khoản lẻ của một vài người…) đều tạo dưới dạng **Đợt thu**. Không có khoản thu nào tự động sinh ra.

Quy trình tạo đợt thu:

1. Nhập tên đợt (ví dụ `Quỹ T11/2026`, `Tiền áo 2026`), mã đợt (tự sinh, sửa được — ví dụ `Q1126`), hạn đóng, ghi chú.
2. Chọn cách tính tiền:
   - **Theo đối tượng**: Thường 200.000đ, Học sinh 100.000đ (mặc định lấy từ cài đặt, sửa được cho từng đợt).
   - **Đồng giá**: một mức cho tất cả.
   - **Nhập tay**: số tiền riêng cho từng người.
3. Chọn người phải đóng: mặc định là toàn bộ thành viên Hoạt động; có thể bỏ chọn hoặc thêm từng người.
4. Xem trước danh sách và số tiền, chỉnh riêng từng dòng nếu cần, rồi xác nhận tạo.
5. Đóng đợt khi đã thu xong.

Số tiền của từng người được lưu cố định vào khoản phải đóng tại thời điểm tạo đợt. Thay đổi mức quỹ mặc định sau này không ảnh hưởng đến các đợt đã tạo.

## 6. Thanh toán

### 6.1. Kênh thanh toán

- Chỉ chuyển khoản vào **một tài khoản ngân hàng của đội**. Không thu tiền mặt qua app.
- Hai kiểu QR, Đội trưởng chọn trong cài đặt:
  - **QR động VietQR** (khuyến nghị): tự điền số tiền và nội dung chuyển khoản.
  - **QR tĩnh**: ảnh QR do Đội trưởng tải lên. App hiển thị sẵn số tiền và nội dung để thành viên copy.

### 6.2. Nội dung chuyển khoản chuẩn

```
N88 <số áo hoặc mã thành viên> <mã đợt>        ví dụ: N88 10 Q1126
N88 <số áo hoặc mã thành viên> G<mã gộp>       khi thanh toán gộp nhiều khoản
```

- Không dấu, dưới 25 ký tự.
- Định dạng cố định để sau này có thể tự động đối soát.

### 6.3. Trạng thái khoản phải đóng

```
Chưa đóng ──(Thành viên bấm "Tôi đã chuyển")──► Chờ xác nhận ──(Admin xác nhận)──► Đã đóng
    ▲                                                │
    └──────────(Admin từ chối, ghi lý do)────────────┘

Chưa đóng ──(Đội trưởng miễn)──► Miễn
```

- **Từ chối** bắt buộc kèm lý do; thành viên thấy lý do trên app.
- **Ghi hộ**: Đội trưởng/Đội phó có thể đánh dấu "Đã nhận" trực tiếp khi thành viên chuyển mà quên báo.
- **Đóng một phần**: khoản hiển thị "Đã đóng X / Y"; đủ tiền thì chuyển sang Đã đóng. Chỉ áp dụng khi thanh toán một khoản.
- **Thanh toán gộp**: nút "Thanh toán tất cả" sinh một QR tổng cho mọi khoản chưa đóng; xác nhận một lần là gạch nợ tất cả. Thanh toán gộp luôn trả đủ từng khoản.

### 6.4. Chứng từ

- Ảnh chụp màn hình chuyển khoản là tùy chọn, được nén trước khi tải lên.
- Chỉ Admin và chính người đóng xem được ảnh.

### 6.5. An toàn dữ liệu tiền

- Thanh toán đã xác nhận chỉ Đội trưởng được hủy, bắt buộc ghi lý do.
- Mọi thao tác xác nhận / từ chối / hủy / sửa số tiền / miễn đều ghi vào nhật ký (ai, lúc nào, giá trị trước và sau).
- Số dư quỹ = tổng thanh toán **đã xác nhận** − tổng khoản chi. Thanh toán đang chờ không được tính.

## 7. Khoản chi

| Trường        | Ghi chú                                                               |
| --------------- | ---------------------------------------------------------------------- |
| Tên khoản chi | bắt buộc                                                             |
| Số tiền       | bắt buộc, VND                                                        |
| Ngày chi       | bắt buộc                                                             |
| Danh mục       | Sân / Nước / Áo / Khác (Đội trưởng chỉnh được danh sách) |
| Người chi     | thành viên đã ứng/chi                                             |
| Ảnh hóa đơn | tùy chọn                                                             |

## 8. Dashboard

### 8.1. Dashboard Admin (Đội trưởng, Đội phó)

- Số dư quỹ; tổng thu, tổng chi trong tháng
- **Chờ xác nhận**: danh sách thanh toán cần duyệt, đặt trên cùng
- Các đợt thu đang mở kèm tiến độ (ví dụ `12/18 người · 2.400.000 / 3.200.000đ`), bấm vào xem chi tiết từng người
- Danh sách thành viên còn nợ (cộng dồn các đợt)
- Khoản chi gần đây
- Thao tác nhanh: Tạo đợt thu, Ghi khoản chi, Copy tin nhắc nợ (đoạn text liệt kê người chưa đóng để dán vào nhóm Zalo)

### 8.2. Dashboard Thành viên

- Số dư quỹ hiện tại
- **Khoản của tôi**: các khoản chưa đóng, nút lấy QR, nút "Tôi đã chuyển"
- Lịch sử đóng tiền của bản thân
- Sao kê thu chi chung của đội
- Tiến độ các đợt thu

### 8.3. Trang công khai

- Là Dashboard Thành viên ở chế độ chỉ xem, không cần đăng nhập, bỏ phần "Khoản của tôi".

## 9. Google Sheet

- **Database của web là nguồn dữ liệu gốc duy nhất.** Google Sheet chỉ là bản sao một chiều để tiện xem.
- Sheet được chia sẻ ở quyền Viewer; chỉ service account của app được ghi.
- App ghi lại toàn bộ dữ liệu sang Sheet mỗi khi có thanh toán được xác nhận/hủy hoặc khoản chi thay đổi. Có thêm nút "Đồng bộ lại" thủ công.
- Chỉ đồng bộ dữ liệu đã xác nhận.
- Các tab dự kiến: `Tổng quan`, `Thu`, `Chi`, và mỗi đợt thu một tab.

## 10. Các câu hỏi đã chốt

| #  | Câu hỏi                                                                 | Quyết định                                                                              |
| -- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Q1 | Có cho phép đóng một phần không?                                   | Có                                                                                        |
| Q2 | Có làm thanh toán gộp nhiều khoản ngay trong MVP không?            | Có                                                                                        |
| Q3 | Thành viên / trang công khai có được xem ai đã đóng, ai chưa? | Thành viên đăng nhập: có. Trang công khai: chỉ hiện tổng số người đã đóng. Google Sheet có tên người nên link Sheet chỉ chia sẻ trong nhóm đội |
| Q4 | Dùng Google Sheet có sẵn hay để app tạo file mới?                  | File mới, trống: Đội trưởng tạo trong Drive của mình và chia sẻ cho app; app tự tạo toàn bộ tab và nội dung (lý do ở DESIGN §7.1) |
| Q5 | Tiền tố nội dung chuyển khoản là `N88`?                           | `N88`, Đội trưởng đổi được trong Cài đặt                                             |

## 11. Công nghệ dự kiến

| Lớp                    | Lựa chọn                                           |
| ----------------------- | ---------------------------------------------------- |
| Frontend + API          | Next.js (App Router) + TypeScript                    |
| UI                      | Tailwind CSS + shadcn/ui, ưu tiên mobile, PWA      |
| Database, Auth, Storage | Supabase (Postgres, Row Level Security)              |
| ORM                     | Drizzle                                              |
| QR                      | VietQR (`img.vietqr.io`)                           |
| Google Sheet            | Google Sheets API (`googleapis`) + service account |
| Deploy                  | Vercel                                               |

## 12. Lộ trình

| Giai đoạn | Nội dung                                                                                                             |
| ----------- | --------------------------------------------------------------------------------------------------------------------- |
| MVP         | Thành viên, Đợt thu, Thanh toán + xác nhận, Khoản chi, 2 Dashboard, Trang công khai, Đồng bộ Google Sheet |
| Phase 2     | Trận đấu + điểm danh, thống kê cầu thủ, bot nhắc nợ / nhắc trận, xuất Excel                             |
| Phase 3     | Tự động đối soát chuyển khoản, nhiều đội                                                                   |
