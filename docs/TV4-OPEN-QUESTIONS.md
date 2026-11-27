# TV4 – Các điểm cần nhóm xác nhận (đang làm theo giả định)

> TV4 đã làm tiếp theo các giả định dưới đây để không bị chặn. Nếu nhóm quyết định khác, TV4 sẽ sửa lại. Mỗi dòng ghi rõ phần nào của TV4 bị ảnh hưởng.

## 1. Cần TV1 trả lời (ảnh hưởng tích hợp)

| # | Câu hỏi | Giả định TV4 đang dùng | Phần bị ảnh hưởng nếu đổi |
|---|---|---|---|
| 1 | **Xác thực WebSocket:** `OQ-06` (SRS 14.5) ghi token ở query param, nhưng SRS 4.6 và `API.md` 4.6 ghi *không* đặt token trong URL. Chọn cách nào? | Dùng header `Authorization: Bearer …` ở bước handshake (Dart `IOWebSocketChannel` hỗ trợ). Token trong URL dễ lọt vào log. | `ChatSocketService` (lớp kết nối) |
| 2 | **Mã lỗi report trùng / rate limit:** SRS 4.9 ghi `REPORT_ALREADY_PENDING` và `REPORT_RATE_LIMITED`, còn mục error catalog ghi `DUPLICATE_PENDING_REPORT` và `RATE_LIMITED`. | Đã thống nhất theo mã riêng của module: `REPORT_ALREADY_PENDING`, `REPORT_RATE_LIMITED` (đã sửa trong `SRS.md` và `API.md`). | Bảng ánh xạ mã lỗi → thông báo |
| 3 | Mã lỗi gửi chat khi Product không còn `AVAILABLE` hoặc hội thoại read-only: `API.md` chưa có mã riêng cho chat (chỉ `CHAT_INVALID_REQUEST`). | Dùng `PRODUCT_NOT_AVAILABLE` (409) cho SOLD, và coi hội thoại read-only là lỗi `403`/`409` chung. | Xử lý lỗi gửi tin |
| 4 | DTO danh sách hội thoại chưa có trường trạng thái (`OPEN`/`READ_ONLY`). | Thêm trường `status` (`OPEN`/`READ_ONLY`) vào DTO conversation; nếu thiếu thì mặc định `OPEN`. | Model `Conversation`, màn phòng chat |
| 5 | Message `SYSTEM` (sự kiện xác nhận giao dịch) cần thêm payload gì? | Chỉ hiển thị `text`, không có payload riêng. | Hiển thị tin hệ thống |

## 2. Cần cả nhóm xác nhận (TV1 đã giả định hộ TV2–TV4)

| ID | Nội dung | Giả định TV4 đang dùng |
|---|---|---|
| `OQ-01` | Khách xem read-only | Đồng ý. Chat, report, admin đều yêu cầu đăng nhập. |
| `OQ-07` | `ASM-07`: Buyer yêu cầu + Seller xác nhận + Review | Đồng ý. TV4 chỉ lo điểm chạm trong chat (nút/tin hệ thống), phần logic do TV3. |
| `OQ-08` | Không có trạng thái `RESERVED` | Đồng ý. |
| `OQ-09` | Chỉ native share + App Link, không có web fallback | Không ảnh hưởng TV4. |
| `OQ-10` | Không có report user/message, không có block user | Đồng ý. Menu chat chỉ có "Xem hồ sơ". |
| `OQ-11` | Danh mục seed cố định | Không ảnh hưởng TV4. |
| `OQ-15` | Tên app / scheme `chodocusv://` | Không ảnh hưởng TV4. |

## 3. Giả định riêng của TV4 (cần TV2/TV3 biết)

- Nút "Báo cáo" nằm ở màn chi tiết sản phẩm (TV2 gắn vào), mở form báo cáo của TV4 với `product_id`.
- Tab Admin hiển thị khi `role == ADMIN` trong hồ sơ người dùng hiện tại (`GET /auth/me`). Nếu API chưa trả `role` thì cần TV1 bổ sung.
- Banner "Mẹo giao dịch an toàn" trong chat là nội dung tĩnh lấy từ Phụ lục F (`FR-CHAT-14`, mức *Should*).
- Quick reply chỉ điền vào ô nhập, không tự gửi (`FR-CHAT-10`).
- Thư mục code của TV4 theo cấu trúc `features/chat`, `features/report`, `features/admin`, sẽ chỉnh khi TV2 chốt cấu trúc project.
