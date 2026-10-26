# SRS — Đặc tả yêu cầu phần mềm

> Hệ thống: Web app quản lý đội bóng & quỹ đội (N88)
> Phiên bản: 1.0 · Cập nhật: 2026-10-26
> Tài liệu liên quan: [PROPOSAL.md](PROPOSAL.md) (định hướng sản phẩm), [DESIGN.md](DESIGN.md) (thiết kế hệ thống)

---

## 1. Giới thiệu

### 1.1. Mục đích
Tài liệu này mô tả đầy đủ những gì hệ thống phải làm trong giai đoạn MVP. Đây là căn cứ để duyệt phạm vi, thiết kế, viết test và nghiệm thu. Tài liệu không mô tả cách hiện thực; phần đó nằm ở [DESIGN.md](DESIGN.md).

### 1.2. Phạm vi
Hệ thống phục vụ **một đội bóng phong trào**, gồm:
- Quản lý danh sách thành viên.
- Tạo các đợt thu tiền (quỹ, tiền áo, khoản lẻ…), theo dõi ai đã đóng, ai còn nợ.
- Thành viên thanh toán bằng chuyển khoản ngân hàng qua QR, ban quản lý xác nhận.
- Ghi nhận khoản chi.
- Công khai tình hình quỹ qua trang web chỉ-xem và Google Sheet chỉ-xem.

Ngoài phạm vi MVP: trận đấu, điểm danh, thống kê cầu thủ, bot thông báo, tự động đối soát ngân hàng, nhiều đội.

### 1.3. Thuật ngữ

| Thuật ngữ | Định nghĩa |
|---|---|
| Admin | Gọi chung cho Đội trưởng và Đội phó |
| Thành viên | Một người trong danh sách đội, có thể có hoặc chưa có tài khoản đăng nhập |
| Đợt thu | Một lần thu tiền do Admin tạo, ví dụ "Quỹ T11/2026", có mã đợt riêng |
| Khoản phải đóng | Số tiền một thành viên phải đóng trong một đợt thu (mỗi thành viên tối đa một khoản trong một đợt) |
| Thanh toán | Một lần chuyển khoản của thành viên, trả cho một hoặc nhiều khoản phải đóng |
| Thanh toán gộp | Thanh toán trả cho từ hai khoản phải đóng trở lên |
| Đóng một phần | Thanh toán nhỏ hơn số tiền còn thiếu của một khoản |
| Nội dung CK | Nội dung chuyển khoản ngân hàng theo định dạng chuẩn của hệ thống |
| Số dư quỹ | Tổng thanh toán đã xác nhận trừ tổng khoản chi chưa bị xóa |
| Nhật ký | Bản ghi các thao tác thay đổi dữ liệu tiền và phân quyền |

### 1.4. Quy ước trong tài liệu
- `FR-<MODULE>-<NN>`: yêu cầu chức năng. `BR-<NN>`: quy tắc nghiệp vụ. `NFR-<NN>`: yêu cầu phi chức năng.
- Mức ưu tiên: **M** (Must — bắt buộc cho MVP), **S** (Should — nên có trong MVP), **C** (Could — làm nếu kịp).
- Tiêu chí chấp nhận viết dạng **Given / When / Then**; mỗi tiêu chí sẽ tương ứng ít nhất một test case.
- Tiền tệ là VND, hiển thị dạng `1.200.000đ`.

---

## 2. Mô tả tổng quan

### 2.1. Tác nhân

| Tác nhân | Mô tả |
|---|---|
| Đội trưởng | Quyền cao nhất. Cấu hình hệ thống, quyết định cuối cùng với dữ liệu tiền đã chốt |
| Đội phó | Vận hành hằng ngày: tạo đợt thu, xác nhận thanh toán, ghi chi, quản lý thành viên |
| Thành viên | Xem và thanh toán khoản của mình, xem tình hình quỹ |
| Khách | Người không đăng nhập, xem trang công khai |
| Hệ thống | Tác vụ tự động: đồng bộ Google Sheet, ghi nhật ký |

### 2.2. Giả định
- A-01: Chỉ có một đội và một tài khoản ngân hàng nhận tiền.
- A-02: Thành viên chủ yếu dùng điện thoại, mở app từ link gửi trong nhóm chat.
- A-03: Thành viên đăng nhập bằng email (Google hoặc link đăng nhập gửi qua email). Thành viên không có email vẫn được quản lý trong danh sách; Admin ghi hộ thanh toán cho họ.
- A-04: Admin tự kiểm tra tiền về trên app ngân hàng; hệ thống không kết nối ngân hàng trong MVP.

### 2.3. Ràng buộc
- C-01: Chỉ hỗ trợ VND, số tiền là số nguyên.
- C-02: Giao diện tiếng Việt.
- C-03: Chi phí vận hành ở mức gói miễn phí của các dịch vụ hosting/database.
- C-04: Múi giờ hiển thị là `Asia/Ho_Chi_Minh`.

---

## 3. Yêu cầu chức năng

Các yêu cầu đơn giản được mô tả ngắn kèm tiêu chí chấp nhận. Các yêu cầu có nhiều bước (đánh dấu ★) có thêm luồng chính và luồng phụ.

### 3.1. AUTH — Xác thực

**FR-AUTH-01 — Đăng nhập** · M
Người dùng đăng nhập bằng tài khoản Google hoặc bằng link đăng nhập gửi tới email.
- Given người dùng chưa đăng nhập, When mở một trang cần đăng nhập, Then được chuyển tới trang đăng nhập và sau khi đăng nhập quay lại đúng trang ban đầu.

**FR-AUTH-02 — Liên kết tài khoản với thành viên** · M
Khi đăng nhập, hệ thống tìm thành viên có email trùng (không phân biệt hoa thường) với email đăng nhập và liên kết tài khoản với thành viên đó.
- Given thành viên có email `a@x.com` chưa liên kết, When người dùng đăng nhập bằng `A@x.com`, Then tài khoản được liên kết và người dùng vào được Dashboard Thành viên.
- Given không có thành viên nào trùng email, When đăng nhập, Then hiển thị trang "Bạn chưa có trong danh sách đội, hãy liên hệ Đội trưởng/Đội phó" và không truy cập được dữ liệu cá nhân nào.

**FR-AUTH-03 — Điều hướng theo vai trò** · M
- Given người dùng là Admin, When đăng nhập, Then mặc định vào Dashboard Admin và có thể chuyển sang Dashboard Thành viên.
- Given người dùng là Thành viên, When truy cập bất kỳ trang Admin nào, Then nhận thông báo không có quyền.

**FR-AUTH-04 — Đăng xuất** · M
- When người dùng bấm Đăng xuất, Then phiên đăng nhập kết thúc và quay về trang công khai.

### 3.2. MEM — Thành viên

**FR-MEM-01 — Danh sách thành viên** · M · Admin
Hiển thị danh sách với cột: số áo, họ tên, vị trí, đối tượng, trạng thái, vai trò, tổng nợ. Lọc theo trạng thái, đối tượng, vị trí; tìm theo tên.
- Given có thành viên Hoạt động và Không hoạt động, When mở danh sách, Then mặc định chỉ hiện thành viên Hoạt động, có bộ lọc để xem tất cả.

**FR-MEM-02 — Thêm thành viên** · M · Admin
Các trường: họ tên (bắt buộc), email, số điện thoại, số áo, vị trí, đối tượng (bắt buộc, mặc định Thường), vai trò (mặc định Thành viên). Trạng thái mặc định Hoạt động.
- Given số áo 10 đang thuộc một thành viên Hoạt động, When thêm thành viên mới cũng số áo 10, Then báo lỗi "Số áo đã được dùng" (BR-05).
- Given email đã thuộc thành viên khác, When lưu, Then báo lỗi "Email đã được dùng".

**FR-MEM-03 — Sửa thông tin thành viên** · M · Admin
Sửa mọi trường ở FR-MEM-02. Thay đổi đối tượng **không** làm thay đổi số tiền của các khoản phải đóng đã tạo (BR-02).

**FR-MEM-04 — Đổi trạng thái** · M · Admin
Chuyển giữa Hoạt động và Không hoạt động.
- Given thành viên chuyển sang Không hoạt động, Then các khoản còn nợ vẫn giữ nguyên và vẫn hiện trong danh sách nợ.
- Given thành viên Không hoạt động, When tạo đợt thu mới, Then thành viên này không được chọn mặc định.

**FR-MEM-05 — Đổi vai trò** · M · Admin
- Given người thao tác là Đội phó, When cố gán hoặc gỡ vai trò Đội trưởng, Then bị từ chối (BR-07).
- Given đội chỉ còn một Đội trưởng Hoạt động, When gỡ vai trò hoặc chuyển người đó sang Không hoạt động, Then bị từ chối (BR-08).

**FR-MEM-06 — Chi tiết thành viên** · M · Admin
Hiển thị thông tin, các khoản phải đóng (theo đợt, kèm trạng thái), lịch sử thanh toán.

**FR-MEM-07 — Xóa thành viên** · S · Đội trưởng
- Given thành viên đã có dữ liệu liên quan (khoản phải đóng, thanh toán, khoản chi, hoặc đợt thu do người đó tạo), When xóa, Then bị từ chối và gợi ý chuyển sang Không hoạt động.
- Given thành viên chưa có dữ liệu liên quan nào, When xóa, Then thành viên bị xóa.

### 3.3. COL — Đợt thu

**FR-COL-01 — Danh sách đợt thu** · M · Admin
Hiển thị tên, mã đợt, hạn đóng, trạng thái (Đang mở / Đã đóng), tiến độ (số người đã đóng đủ / tổng, số tiền đã thu / phải thu).

**FR-COL-02 ★ — Tạo đợt thu** · M · Admin

*Luồng chính:*
1. Admin nhập tên đợt, mã đợt, hạn đóng (tùy chọn), ghi chú (tùy chọn). Hệ thống gợi ý mã đợt dạng `Q<MM><YY>` theo tháng hiện tại.
2. Admin chọn cách tính tiền:
   - **Theo đối tượng**: nhập mức cho Thường và Học sinh (mặc định lấy từ cài đặt, 200.000đ và 100.000đ).
   - **Đồng giá**: nhập một mức.
   - **Nhập tay**: số tiền để trống, nhập ở bước 4.
3. Hệ thống hiển thị danh sách thành viên, đã chọn sẵn toàn bộ thành viên Hoạt động. Admin bỏ chọn hoặc chọn thêm.
4. Hệ thống hiển thị bảng xem trước: mỗi người một dòng với số tiền tính theo bước 2. Admin sửa được số tiền từng dòng.
5. Admin bấm Tạo. Hệ thống tạo đợt thu và các khoản phải đóng trong cùng một giao dịch, ghi nhật ký.

*Luồng phụ:*
- 1a. Mã đợt trùng với đợt đã có, hoặc sai định dạng (BR-10): báo lỗi, không cho sang bước sau.
- 3a. Không chọn người nào: không cho tạo.
- 4a. Có dòng số tiền trống hoặc ≤ 0: báo lỗi tại dòng đó.

*Tiêu chí chấp nhận:*
- Given A là Thường, B là Học sinh, cách tính Theo đối tượng 200.000/100.000, When tạo đợt, Then A có khoản 200.000đ, B có khoản 100.000đ.
- Given Admin sửa dòng của A thành 150.000đ ở bước 4, When tạo, Then khoản của A là 150.000đ.
- Given đợt đã tạo, When Đội trưởng đổi mức quỹ mặc định trong cài đặt, Then số tiền các khoản của đợt đó không đổi (BR-02).

**FR-COL-03 — Chi tiết đợt thu** · M · Admin
Bảng từng người: số áo, họ tên, số phải đóng, đã đóng (đã xác nhận), còn thiếu, trạng thái khoản (BR-03). Lọc theo trạng thái.

**FR-COL-04 — Thêm người vào đợt** · M · Admin
Chỉ khi đợt Đang mở. Nhập số tiền cho người được thêm (gợi ý theo cách tính của đợt).
- Given thành viên đã có khoản trong đợt, When thêm lại, Then bị từ chối (BR-04).

**FR-COL-05 — Bỏ người khỏi đợt** · M · Admin
- Given khoản đã có bất kỳ thanh toán nào (ở mọi trạng thái, kể cả bị từ chối), When bỏ người đó khỏi đợt, Then bị từ chối và gợi ý dùng Miễn hoặc Điều chỉnh số tiền.

**FR-COL-06 — Điều chỉnh số tiền khoản phải đóng** · M · Đội trưởng
Bắt buộc ghi lý do.
- Given khoản 200.000đ đã xác nhận đóng 50.000đ, When điều chỉnh xuống 40.000đ, Then bị từ chối (số tiền mới không được nhỏ hơn số đã đóng — BR-11).

**FR-COL-07 — Miễn khoản phải đóng** · M · Đội trưởng
Bắt buộc ghi lý do.
- Given khoản chưa có thanh toán nào, When miễn, Then khoản chuyển sang trạng thái Miễn và không còn tính vào nợ.
- Given khoản đã có thanh toán (đang chờ hoặc đã xác nhận), When miễn, Then bị từ chối và gợi ý Điều chỉnh số tiền bằng số đã đóng.
- Đội trưởng có thể bỏ miễn; khoản quay về Chưa đóng.

**FR-COL-08 — Đóng / mở lại đợt thu** · M · Admin
- Given đợt Đã đóng, Then không thêm/bỏ người được, nhưng thành viên vẫn thanh toán được phần còn nợ.
- Admin có thể mở lại đợt đã đóng.

**FR-COL-09 — Xóa đợt thu** · S · Đội trưởng
- Given đợt chưa có thanh toán nào, When xóa, Then đợt và các khoản phải đóng bị xóa, ghi nhật ký.
- Given đợt đã có thanh toán (ở mọi trạng thái, kể cả bị từ chối), When xóa, Then bị từ chối.

**FR-COL-10 — Copy tin nhắc nợ** · S · Admin
Từ chi tiết đợt hoặc Dashboard Admin, tạo đoạn văn bản:

```
[N88] Nhắc đóng Quỹ T11/2026 (hạn 05/11)
Còn 6 bạn chưa đóng đủ:
- #10 Minh: 200.000đ
- #7 Hùng: 100.000đ (còn thiếu)
...
Đóng tại: <link app>
```

- When bấm nút, Then đoạn văn bản được copy vào clipboard và hiện thông báo "Đã copy".

### 3.4. PAY — Thanh toán

**FR-PAY-01 — Khoản của tôi** · M · Thành viên
Danh sách khoản chưa đóng đủ của bản thân (mọi đợt, cả đợt đã đóng), hiển thị số còn thiếu và trạng thái. Có nút "Thanh toán" cho từng khoản và nút "Thanh toán tất cả" khi có từ 2 khoản trở lên.

**FR-PAY-02 ★ — Thanh toán một khoản** · M · Thành viên

*Luồng chính:*
1. Thành viên bấm "Thanh toán" ở một khoản.
2. Hệ thống hiển thị: số tiền (mặc định bằng số còn thiếu), thông tin tài khoản nhận, nội dung CK chuẩn (BR-12), QR.
3. Thành viên chuyển khoản bằng app ngân hàng.
4. Thành viên (tùy chọn) đính ảnh chụp màn hình, bấm "Tôi đã chuyển".
5. Hệ thống tạo thanh toán trạng thái **Chờ xác nhận**.

*Luồng phụ:*
- 2a. Thành viên sửa số tiền nhỏ hơn số còn thiếu (đóng một phần). QR và số tiền hiển thị cập nhật theo.
- 2b. Số tiền nhập > số còn thiếu hoặc ≤ 0: báo lỗi.
- 2c. Khoản đang có một thanh toán Chờ xác nhận: không cho tạo thêm, hiển thị "Đang chờ xác nhận" (BR-13).

*Tiêu chí chấp nhận:*
- Given khoản 100.000đ chưa đóng, When thành viên báo đã chuyển 50.000đ, Then có một thanh toán 50.000đ Chờ xác nhận và khoản ở trạng thái Chờ xác nhận.
- Given chế độ QR động, Then QR chứa đúng số tiền và nội dung CK; Given chế độ QR tĩnh, Then hiển thị ảnh QR của đội kèm số tiền và nội dung CK có nút copy.

**FR-PAY-03 ★ — Thanh toán gộp** · M · Thành viên

*Luồng chính:*
1. Thành viên bấm "Thanh toán tất cả", hoặc tick chọn nhiều khoản rồi bấm "Thanh toán các khoản đã chọn".
2. Hệ thống hiển thị danh sách khoản đã chọn, tổng tiền, nội dung CK dạng gộp (BR-12), QR.
3. Thành viên chuyển khoản, (tùy chọn) đính ảnh, bấm "Tôi đã chuyển".
4. Hệ thống tạo **một** thanh toán Chờ xác nhận gồm các khoản đã chọn.

*Quy tắc:*
- Thanh toán gộp luôn trả **đủ số còn thiếu** của từng khoản; không đóng một phần trong thanh toán gộp (BR-14).
- Khoản đang có thanh toán Chờ xác nhận không được chọn (BR-13).

*Tiêu chí chấp nhận:*
- Given thành viên còn thiếu 200.000đ quỹ T10 và 200.000đ quỹ T11, When thanh toán tất cả, Then tổng là 400.000đ, nội dung CK dạng gộp, và cả hai khoản chuyển sang Chờ xác nhận.

**FR-PAY-04 — Rút lại yêu cầu đang chờ** · S · Thành viên
- Given thanh toán của mình đang Chờ xác nhận, When thành viên bấm "Rút lại", Then thanh toán bị xóa và các khoản liên quan quay về trạng thái trước đó.

**FR-PAY-05 — Hàng chờ xác nhận** · M · Admin
Danh sách thanh toán Chờ xác nhận, cũ nhất lên trên: thành viên, số tiền, nội dung CK, thời điểm báo, ảnh chứng từ (nếu có), các khoản đi kèm.

**FR-PAY-06 — Xác nhận thanh toán** · M · Admin
- Given thanh toán Chờ xác nhận, When Admin bấm Xác nhận, Then thanh toán chuyển sang Đã xác nhận, các khoản cập nhật trạng thái theo BR-03, số dư quỹ tăng tương ứng, ghi nhật ký, đánh dấu cần đồng bộ Sheet.
- Given hai Admin cùng xác nhận một thanh toán gần như đồng thời, Then chỉ một lần xác nhận có hiệu lực, người còn lại nhận thông báo "Thanh toán đã được xử lý".

**FR-PAY-07 — Từ chối thanh toán** · M · Admin
Bắt buộc nhập lý do.
- When Admin từ chối, Then thanh toán chuyển sang Bị từ chối, các khoản quay về trạng thái trước đó, thành viên thấy lý do ở lịch sử thanh toán của mình.

**FR-PAY-08 ★ — Ghi hộ thanh toán** · M · Admin
Dùng khi thành viên đã chuyển nhưng không báo trên app.

*Luồng chính:*
1. Admin chọn thành viên, chọn một hoặc nhiều khoản chưa đóng đủ của người đó.
2. Với mỗi khoản, nhập số tiền (mặc định bằng số còn thiếu, được nhỏ hơn).
3. (Tùy chọn) đính ảnh, ghi chú, bấm Lưu.
4. Hệ thống tạo thanh toán ở trạng thái **Đã xác nhận** ngay.

- Given số tiền một dòng lớn hơn số còn thiếu của khoản đó, When lưu, Then báo lỗi (BR-11).

**FR-PAY-09 — Hủy thanh toán đã xác nhận** · M · Đội trưởng
Bắt buộc nhập lý do.
- When Đội trưởng hủy, Then thanh toán chuyển sang Đã hủy, không còn tính vào số dư và vào số đã đóng của các khoản, ghi nhật ký, đánh dấu cần đồng bộ Sheet.
- Thanh toán đã hủy không thể khôi phục; nếu hủy nhầm thì ghi hộ một thanh toán mới.

**FR-PAY-10 — Lịch sử thanh toán của tôi** · M · Thành viên
Mọi thanh toán của bản thân với trạng thái, số tiền, ngày, các khoản; hiển thị lý do nếu bị từ chối hoặc bị hủy.

**FR-PAY-11 — Xem ảnh chứng từ** · M
- Given người xem là Admin hoặc chính người tạo thanh toán, Then xem được ảnh.
- Given người xem khác, Then không truy cập được ảnh, kể cả khi có đường dẫn (NFR-05).

### 3.5. EXP — Khoản chi

**FR-EXP-01 — Danh sách khoản chi** · M · Admin
Lọc theo tháng và danh mục; hiển thị tổng chi theo bộ lọc.

**FR-EXP-02 — Ghi khoản chi** · M · Admin
Các trường: tên (bắt buộc), số tiền (bắt buộc, > 0), ngày chi (bắt buộc, mặc định hôm nay), danh mục (bắt buộc), người chi (tùy chọn, chọn từ thành viên), ảnh hóa đơn (tùy chọn), ghi chú.
- When lưu, Then số dư quỹ giảm tương ứng, ghi nhật ký, đánh dấu cần đồng bộ Sheet.

**FR-EXP-03 — Sửa khoản chi** · M · Đội trưởng
Bắt buộc nhập lý do khi sửa số tiền.

**FR-EXP-04 — Xóa khoản chi** · M · Đội trưởng
Xóa mềm, bắt buộc nhập lý do. Khoản chi đã xóa không tính vào số dư và không hiển thị ở danh sách, nhưng vẫn còn trong nhật ký.

**FR-EXP-05 — Quản lý danh mục chi** · S · Đội trưởng
Thêm, đổi tên, ẩn danh mục. Không xóa được danh mục đã có khoản chi. Danh mục mặc định: Sân, Nước, Áo, Khác.

### 3.6. DASH — Dashboard

**FR-DASH-01 — Dashboard Admin** · M · Admin
Gồm các khối, theo thứ tự:
1. Số thanh toán Chờ xác nhận (nổi bật, bấm vào mở hàng chờ — FR-PAY-05).
2. Số dư quỹ; tổng thu, tổng chi trong tháng hiện tại.
3. Các đợt thu Đang mở kèm tiến độ.
4. Top thành viên còn nợ nhiều nhất (tổng các đợt), bấm vào xem chi tiết.
5. 5 khoản chi gần nhất.
6. Thao tác nhanh: Tạo đợt thu, Ghi khoản chi, Ghi hộ thanh toán.

**FR-DASH-02 — Dashboard Thành viên** · M · Thành viên
Gồm:
1. Khoản của tôi (FR-PAY-01).
2. Số dư quỹ.
3. Tiến độ các đợt thu đang mở, **có** danh sách tên người đã/chưa đóng (BR-15).
4. Sao kê thu chi chung (FR-PUB-02, bản đầy đủ).
5. Lối vào Lịch sử thanh toán của tôi (FR-PAY-10).

### 3.7. PUB — Trang công khai

**FR-PUB-01 — Tổng quan công khai** · M · Khách
Số dư quỹ, tổng thu và tổng chi theo từng tháng (6 tháng gần nhất), tiến độ các đợt thu đang mở.

**FR-PUB-02 — Sao kê** · M
- Bản công khai (Khách): phần Thu tổng hợp **theo đợt thu** (tên đợt, số tiền đã thu, số người đã đóng đủ / tổng), không có tên người; phần Chi đầy đủ từng khoản (tên, số tiền, ngày, danh mục), không có ảnh hóa đơn.
- Bản thành viên (đã đăng nhập): phần Thu chi tiết từng thanh toán đã xác nhận, có tên người.

**FR-PUB-03 — Tiến độ đợt thu công khai** · M · Khách
- Given Khách mở chi tiết một đợt thu, Then chỉ thấy số người đã đóng đủ / tổng và số tiền, không thấy tên (BR-15).

### 3.8. SHEET — Đồng bộ Google Sheet

**FR-SHEET-01 — Tự động đồng bộ** · M · Hệ thống
Sau mỗi thao tác làm thay đổi dữ liệu đã xác nhận (xác nhận / hủy / ghi hộ thanh toán, tạo / sửa / xóa khoản chi, tạo / sửa / xóa đợt thu, điều chỉnh hoặc miễn khoản, sửa tên hoặc số áo thành viên), hệ thống ghi lại toàn bộ dữ liệu sang Google Sheet.
- Given Admin vừa xác nhận một thanh toán, Then trong vòng 1 phút Sheet phản ánh thanh toán đó.
- Thao tác của người dùng không bị chậm hay thất bại vì lỗi đồng bộ (BR-17).

**FR-SHEET-02 — Đồng bộ lại thủ công** · M · Admin
Nút "Đồng bộ lại" trong Cài đặt.

**FR-SHEET-03 — Đồng bộ định kỳ** · M · Hệ thống
- Given lần đồng bộ trước thất bại, Then hệ thống tự thử lại theo chu kỳ cho đến khi thành công.

**FR-SHEET-04 — Trạng thái đồng bộ** · S · Admin
Hiển thị thời điểm đồng bộ thành công gần nhất và lỗi gần nhất (nếu có).

**FR-SHEET-05 — Nội dung Sheet** · M
Các tab:
- `Tổng quan`: số dư, tổng thu, tổng chi, thời điểm cập nhật.
- `Thu`: mọi thanh toán đã xác nhận — ngày, thành viên, số tiền, các đợt, nội dung CK.
- `Chi`: mọi khoản chi chưa xóa — ngày, tên, danh mục, số tiền, người chi.
- Mỗi đợt thu một tab: thành viên, phải đóng, đã đóng, còn thiếu, trạng thái.

### 3.9. AUD — Nhật ký

**FR-AUD-01 — Ghi nhật ký** · M · Hệ thống
Ghi lại: người thực hiện, thời điểm, hành động, đối tượng, giá trị trước và sau, lý do (nếu có), cho các thao tác:
- Tạo / sửa / xóa đợt thu; thêm / bỏ người khỏi đợt; điều chỉnh / miễn / bỏ miễn khoản.
- Tạo / xác nhận / từ chối / hủy / ghi hộ / rút lại thanh toán.
- Tạo / sửa / xóa khoản chi.
- Thêm / sửa / xóa thành viên, đổi vai trò, đổi trạng thái.
- Sửa cài đặt.

**FR-AUD-02 — Xem nhật ký** · M · Admin
Lọc theo loại đối tượng, người thực hiện, khoảng thời gian. Không ai sửa hay xóa được nhật ký (BR-16).

### 3.10. SET — Cài đặt

**FR-SET-01 — Thông tin đội và ngân hàng** · M · Đội trưởng
Tên đội, ngân hàng, số tài khoản, tên chủ tài khoản, chế độ QR (động / tĩnh), ảnh QR tĩnh.

**FR-SET-02 — Mức quỹ mặc định** · M · Đội trưởng
Mức cho Thường và Học sinh, dùng làm giá trị gợi ý khi tạo đợt thu.

**FR-SET-03 — Tiền tố nội dung CK** · S · Đội trưởng
Mặc định `N88`, 2–6 ký tự A–Z, 0–9.

---

## 4. Quy tắc nghiệp vụ

| Mã | Quy tắc |
|---|---|
| BR-01 | **Số dư quỹ** = tổng `số tiền` các thanh toán ở trạng thái Đã xác nhận − tổng `số tiền` các khoản chi chưa bị xóa. Thanh toán Chờ xác nhận, Bị từ chối, Đã hủy không được tính. |
| BR-02 | Số tiền của khoản phải đóng được **chốt tại thời điểm tạo**. Thay đổi mức quỹ mặc định hoặc đối tượng của thành viên không ảnh hưởng tới các khoản đã tạo. Chỉ thay đổi được qua FR-COL-06. |
| BR-03 | **Trạng thái khoản phải đóng** được suy ra, xét theo thứ tự ưu tiên: (1) **Miễn** nếu đã được miễn; (2) **Đã đóng** nếu tổng đã xác nhận ≥ số phải đóng; (3) **Chờ xác nhận** nếu có thanh toán đang chờ chứa khoản này; (4) **Đóng một phần** nếu tổng đã xác nhận > 0; (5) **Chưa đóng**. |
| BR-04 | Mỗi thành viên có tối đa một khoản phải đóng trong một đợt thu. |
| BR-05 | Số áo không trùng nhau giữa các thành viên đang Hoạt động. Số áo của thành viên Không hoạt động có thể được người khác dùng; khi kích hoạt lại một thành viên mà số áo đã có người dùng, phải đổi số áo trước. |
| BR-06 | Quyền Admin chỉ có hiệu lực khi thành viên đang Hoạt động. Thành viên Không hoạt động vẫn đăng nhập được, xem và thanh toán khoản của mình. |
| BR-07 | Chỉ Đội trưởng được gán hoặc gỡ vai trò Đội trưởng. |
| BR-08 | Luôn có ít nhất một Đội trưởng đang Hoạt động. |
| BR-09 | Số tiền là số nguyên VND, > 0, tối đa 100.000.000đ cho một khoản phải đóng, một thanh toán hoặc một khoản chi. |
| BR-10 | Mã đợt: 3–8 ký tự A–Z, 0–9, không trùng giữa các đợt. |
| BR-11 | Tại mọi thời điểm, với mỗi khoản: tổng đã xác nhận ≤ số phải đóng. Mọi thao tác vi phạm (xác nhận, ghi hộ, điều chỉnh giảm) đều bị từ chối. |
| BR-12 | **Nội dung CK**: `<tiền tố> <mã TV> <mã đợt>` cho thanh toán một khoản, `<tiền tố> <mã TV> G<DDMM>` cho thanh toán gộp (DDMM là ngày tạo). `<mã TV>` là số áo nếu có, nếu không là mã thành viên do hệ thống cấp. Không dấu, tối đa 25 ký tự. Nội dung CK được lưu cố định vào thanh toán lúc tạo. |
| BR-13 | Một khoản chỉ có tối đa một thanh toán Chờ xác nhận tại một thời điểm. |
| BR-14 | Thanh toán gộp trả đủ số còn thiếu của từng khoản. Đóng một phần chỉ áp dụng khi thanh toán một khoản (FR-PAY-02) hoặc khi Admin ghi hộ (FR-PAY-08). |
| BR-15 | Danh sách tên người đã/chưa đóng chỉ hiển thị cho người đã đăng nhập và là thành viên. Khách chỉ thấy số liệu tổng hợp. Google Sheet có tên người, nên link Sheet chỉ được chia sẻ trong nhóm của đội. |
| BR-16 | Nhật ký chỉ được thêm mới, không được sửa hay xóa. |
| BR-17 | Lỗi đồng bộ Google Sheet không làm thất bại thao tác của người dùng; dữ liệu trong database là nguồn gốc duy nhất. |
| BR-18 | Thanh toán chỉ đi qua các bước chuyển hợp lệ: Chờ xác nhận → Đã xác nhận / Bị từ chối / (bị rút lại); Đã xác nhận → Đã hủy. Ghi hộ tạo thẳng Đã xác nhận. Bị từ chối và Đã hủy là trạng thái cuối. |

---

## 5. Yêu cầu phi chức năng

| Mã | Nhóm | Yêu cầu |
|---|---|---|
| NFR-01 | Hiệu năng | Dashboard và trang công khai hiển thị nội dung chính trong ≤ 2 giây trên mạng 4G với dữ liệu 1 năm (~50 thành viên, ~30 đợt thu, ~1.500 thanh toán). |
| NFR-02 | Hiệu năng | Thao tác ghi (xác nhận, tạo đợt thu…) phản hồi trong ≤ 1 giây, không tính thời gian tải ảnh. |
| NFR-03 | Giao diện | Dùng tốt trên màn hình rộng từ 360px; không cuộn ngang. Vùng bấm tối thiểu 44×44px. |
| NFR-04 | Bảo mật | Chỉ dùng HTTPS. Mọi kiểm tra quyền thực hiện phía server; giao diện ẩn nút chỉ là phụ. |
| NFR-05 | Bảo mật | Ảnh chứng từ và hóa đơn lưu ở kho riêng tư, chỉ truy cập qua link có thời hạn do server cấp sau khi kiểm tra quyền. |
| NFR-06 | Bảo mật | Khóa bí mật (database, Google service account) chỉ nằm ở server, không bao giờ gửi xuống trình duyệt. |
| NFR-07 | Toàn vẹn | Mọi thao tác thay đổi tiền thực hiện trong một giao dịch database; không bao giờ có trạng thái dở dang. |
| NFR-08 | Toàn vẹn | Thao tác đồng thời trên cùng thanh toán hoặc khoản không làm sai số liệu (FR-PAY-06). |
| NFR-09 | Sao lưu | Database được sao lưu tự động ít nhất mỗi tuần, lưu tối thiểu 4 bản gần nhất. |
| NFR-10 | Ngôn ngữ | Toàn bộ giao diện tiếng Việt; tiền hiển thị dạng `1.200.000đ`; ngày dạng `dd/mm/yyyy`. |
| NFR-11 | Vận hành | Chạy được trong giới hạn gói miễn phí của dịch vụ hosting và database đã chọn. |
| NFR-12 | Khả dụng | Có thể cài lên màn hình chính điện thoại (PWA). Không yêu cầu chạy offline. |

---

## 6. Ma trận phân quyền

Ký hiệu: ✓ được phép · — không được phép · *own* chỉ với dữ liệu của chính mình.

| Yêu cầu | Đội trưởng | Đội phó | Thành viên | Khách |
|---|:-:|:-:|:-:|:-:|
| FR-AUTH-01..04 | ✓ | ✓ | ✓ | (đăng nhập) |
| FR-MEM-01..04, 06 | ✓ | ✓ | — | — |
| FR-MEM-05 | ✓ | ✓ (trừ vai trò Đội trưởng) | — | — |
| FR-MEM-07 | ✓ | — | — | — |
| FR-COL-01..05, 08, 10 | ✓ | ✓ | — | — |
| FR-COL-06, 07, 09 | ✓ | — | — | — |
| FR-PAY-01..04, 10 | ✓ *own* | ✓ *own* | ✓ *own* | — |
| FR-PAY-05..08 | ✓ | ✓ | — | — |
| FR-PAY-09 | ✓ | — | — | — |
| FR-PAY-11 | ✓ | ✓ | ✓ *own* | — |
| FR-EXP-01, 02 | ✓ | ✓ | — | — |
| FR-EXP-03..05 | ✓ | — | — | — |
| FR-DASH-01 | ✓ | ✓ | — | — |
| FR-DASH-02 | ✓ | ✓ | ✓ | — |
| FR-PUB-01..03 | ✓ | ✓ | ✓ | ✓ |
| FR-SHEET-02, 04 | ✓ | ✓ | — | — |
| FR-AUD-02 | ✓ | ✓ | — | — |
| FR-SET-01..03 | ✓ | — | — | — |

Áp dụng thêm BR-06: Admin Không hoạt động chỉ có quyền như Thành viên.

---

## 7. Truy vết

Bảng này được điền dần khi thiết kế màn hình và viết test. Cột Màn hình tham chiếu sơ đồ route ở [DESIGN.md §6](DESIGN.md#6-màn-hình--route).

| Yêu cầu | Màn hình | Test | Trạng thái |
|---|---|---|---|
| FR-AUTH-01 | `/login` | | Chưa làm |
| FR-AUTH-02 | `/auth/callback`, `/not-member` | | Chưa làm |
| FR-MEM-01..07 | `/admin/members/*` | | Chưa làm |
| FR-COL-01..10 | `/admin/collections/*` | | Chưa làm |
| FR-PAY-01..04, 10, 11 | `/me`, `/me/pay`, `/me/payments` | | Chưa làm |
| FR-PAY-05..09 | `/admin/payments/*` | | Chưa làm |
| FR-EXP-01..05 | `/admin/expenses/*`, `/admin/settings` | | Chưa làm |
| FR-DASH-01 | `/admin` | | Chưa làm |
| FR-DASH-02 | `/me` | | Chưa làm |
| FR-PUB-01..03 | `/`, `/ledger`, `/collections/[code]` | | Chưa làm |
| FR-SHEET-01..05 | (nền), `/admin/settings` | | Chưa làm |
| FR-AUD-01..02 | (nền), `/admin/audit` | | Chưa làm |
| FR-SET-01..03 | `/admin/settings` | | Chưa làm |
