# API CONTRACT — Chợ Đồ Cũ Sinh Viên (FastAPI)

| **Thuộc tính** | **Giá trị**                                                                                                           |
| -------------- | --------------------------------------------------------------------------------------------------------------------- |
| Phiên bản      | 1.0                                                                                                                   |
| Ngày           | 2026-11-27                                                                                                            |
| Chủ sở hữu     | TV1 (Backend & tích hợp)                                                                                              |
| Nguồn          | `SRS.md` v1.0 — mục 4.x (API Contract từng module), 8, 12.1                                                           |
| Base path      | `/api/v1`                                                                                                             |
| Trạng thái     | Dự thảo để TV2–TV4 rà soát; sau khi duyệt, thay đổi endpoint/schema phải có versioning hoặc thông báo breaking change |

> **Nguyên tắc:** `API.md` là hợp đồng giữa Backend và Flutter. TV2–TV4 không tự giả định cấu trúc JSON khác tài liệu này; thiếu dữ liệu thì yêu cầu TV1 cập nhật hợp đồng. Nếu `API.md` và `SRS.md` mâu thuẫn, kiểm tra lại SRS rồi cập nhật cả hai.

## MỤC LỤC

- [1. Quy ước chung](#1-quy-ước-chung)
- [2. Cấu hình đã chốt](#2-cấu-hình-đã-chốt)
- [3. Danh mục endpoint](#3-danh-mục-endpoint)
- [4. Chi tiết theo module](#4-chi-tiết-theo-module)
- [5. Error catalog](#5-error-catalog)
- [6. Ví dụ bổ sung](#6-ví-dụ-bổ-sung)

## 1. Quy ước chung

### 1.1. Base URL, Header và định dạng

- Base path `/api/v1`; REST dùng HTTPS + JSON UTF-8.
- Auth header Authorization: Bearer \<`access_token`\> cho endpoint protected.
- X-Request-ID do client gửi hoặc Backend sinh và echo trong response – **[Bổ sung hợp lý / Giả định]**.
- JSON dùng application/json; upload dùng multipart/form-data.
- Datetime ISO-8601 UTC, ví dụ 2026-11-27T03:00:00Z.
- Tiền integer VND, không dùng float.
- List dùng page/page_size; chat history có thể dùng cursor.

### 1.2. Response envelope

**Success**

```json
{
  "data": {},
  "meta": {"request_id": "req_01JREQUEST"}
}
```

**Error**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Du lieu gui len khong hop le.",
    "details": [{"field": "price_vnd", "issue": "must be greater than or equal to 0"}]
  },
  "meta": {"request_id": "req_01JREQUEST"}
}
```

### 1.3. HTTP Status Code

| **Status** | **Sử dụng**                                                      |
| ---------- | ---------------------------------------------------------------- |
| `200`      | Đọc/cập nhật/action thành công có response                       |
| `201`      | Tạo resource thành công                                          |
| 202        | Request đã nhận; xử lý async (ví dụ gửi email)                   |
| `204`      | Thành công, không response body                                  |
| `400`      | Request/business format tổng quát không hợp lệ                   |
| `401`      | Thiếu/sai/hết hạn token; refresh không hợp lệ                    |
| `403`      | Đã xác thực nhưng không đủ quyền/tài khoản bị khóa/chưa xác minh |
| `404`      | Không tìm thấy resource hoặc không được phép lộ sự tồn tại       |
| `409`      | Xung đột trạng thái, dữ liệu trùng hoặc resource đã xử lý        |
| `413`      | File vượt dung lượng                                             |
| `422`      | Schema validation error                                          |
| `429`      | Rate limit                                                       |
| `500`      | Lỗi nội bộ                                                       |
| `503`      | Backend/dependency nội bộ tạm thời không sẵn sàng                |

Không trả stack trace hoặc thông tin database trong response public.

### 1.4. Validation và bảo mật API

1. Flutter validate sơ bộ; FastAPI validate độc lập bằng request schema.
2. Backend không tin `user_id`, `seller_id`, role, status, `created_at`, `resolved_at` hoặc field hệ thống từ client.
3. Mọi endpoint thay đổi resource kiểm tra owner/participant/admin ở server.
4. DB có unique constraint email, wishlist (`user_id`, `product_id`), conversation (`product_id`, `buyer_id`), review `confirmation_id` nếu bật confirmation.
5. POST có khả năng retry phải có idempotency key hoặc unique client request ID.
6. API list có `page_size` tối đa; không nhận page size không giới hạn.

## 2. Cấu hình đã chốt

Các giá trị dưới đây lấy từ nhật ký quyết định (`SRS.md` mục 14.5); backend phải cấu hình đúng.

| **Hạng mục**       | **Giá trị**                                                                                                             | **Mã**                          |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| Cơ sở dữ liệu      | PostgreSQL, migration có version                                                                                        | `OQ-03`                         |
| Access token       | JWT, TTL 15 phút                                                                                                        | `OQ-04`                         |
| Refresh token      | Opaque, TTL 30 ngày, lưu hash trong DB, xoay vòng mỗi lần refresh                                                       | `OQ-04`                         |
| Thu hồi token      | Logout: thu hồi session hiện tại; reset mật khẩu: thu hồi toàn bộ session                                               | `OQ-04`                         |
| Email verification | Không bắt buộc; `API-AUTH-08` là tùy chọn, làm sau MVP                                                                  | `OQ-02`                         |
| Lưu ảnh            | Đĩa cục bộ của server qua storage adapter; chỉ truy cập qua FastAPI; backup định kỳ                                     | `OQ-05`                         |
| WebSocket          | JWT ở handshake (query param), ping/pong 30 giây, close code `4401` (chưa xác thực/hết hạn), `4403` (không có quyền)    | `OQ-06`                         |
| Giới hạn dữ liệu   | Giá tối đa 100.000.000 VND; mô tả ≤ 2000 ký tự; 1–5 ảnh/tin; ảnh ≤ 5 MB (jpg/png/webp); avatar ≤ 2 MB, tối đa 1024x1024 | `OQ-12`                         |
| Rate limit         | Login: 5 lần sai/15 phút theo IP+email; report: 10/ngày/user                                                            | `OQ-13`                         |
| Retention          | Soft delete giữ 90 ngày; log giữ 30 ngày                                                                                | `OQ-13`                         |
| Email gửi          | Gmail SMTP + App Password; thông tin lấy từ biến môi trường, không commit                                               | `OQ-14`                         |
| Guest              | Xem read-only nội dung công khai; không ghi dữ liệu                                                                     | `OQ-01` (giả định, chờ TV2–TV4) |
| Xác nhận giao dịch | Buyer request, Seller confirm, rồi Review (`ASM-07`)                                                                    | `OQ-07` (giả định, chờ TV2–TV4) |

## 3. Danh mục endpoint

| **Module**                        | **ID**           | **Method** | **Endpoint**                                           | **Auth**                                               | **Mục đích**                                                      |
| --------------------------------- | ---------------- | ---------- | ------------------------------------------------------ | ------------------------------------------------------ | ----------------------------------------------------------------- |
| Health                            | —                | GET        | `/api/v1/health`                                       | Public                                                 | Kiểm tra dịch vụ                                                  |
| Auth                              | `API-AUTH-01`    | POST       | `/api/v1/auth/register`                                | Public                                                 | Tạo tài khoản                                                     |
| Auth                              | `API-AUTH-02`    | POST       | `/api/v1/auth/login`                                   | Public                                                 | Đăng nhập                                                         |
| Auth                              | `API-AUTH-03`    | POST       | `/api/v1/auth/refresh`                                 | Refresh token                                          | Cấp access token mới                                              |
| Auth                              | `API-AUTH-04`    | POST       | `/api/v1/auth/logout`                                  | Bearer                                                 | Thu hồi refresh session                                           |
| Auth                              | `API-AUTH-05`    | GET        | `/api/v1/auth/me`                                      | Bearer                                                 | User hiện tại                                                     |
| Auth                              | `API-AUTH-06`    | POST       | `/api/v1/auth/password/forgot`                         | Public                                                 | Gửi email reset                                                   |
| Auth                              | `API-AUTH-07`    | POST       | `/api/v1/auth/password/reset`                          | Reset token                                            | Đặt lại mật khẩu                                                  |
| Auth                              | `API-AUTH-08`    | POST       | `/api/v1/auth/email/verify`                            | Verification token                                     | Xác minh email (tùy chọn, làm sau MVP)                            |
| Profile                           | `API-PROFILE-01` | GET        | `/api/v1/users/me`                                     | Bearer                                                 | Hồ sơ của mình                                                    |
| Profile                           | `API-PROFILE-02` | PATCH      | `/api/v1/users/me`                                     | Bearer                                                 | Cập nhật hồ sơ                                                    |
| Profile                           | `API-PROFILE-03` | GET        | `/api/v1/users/{user_id}`                              | Public hoặc Bearer                                     | Hồ sơ công khai                                                   |
| Browse / Product Read             | `API-BROWSE-01`  | GET        | `/api/v1/categories`                                   | Public                                                 | Danh mục active                                                   |
| Browse / Product Read             | `API-BROWSE-02`  | GET        | `/api/v1/products`                                     | Public                                                 | List/search/filter/pagination                                     |
| Browse / Product Read             | `API-BROWSE-03`  | GET        | `/api/v1/products/{product_id}`                        | Public                                                 | Product detail                                                    |
| Browse / Product Read             | `API-BROWSE-04`  | GET        | `/api/v1/users/{user_id}/products`                     | Public                                                 | Product public của seller                                         |
| Product Write / File              | `API-FILE-01`    | POST       | `/api/v1/files/images`                                 | Bearer                                                 | Upload ảnh                                                        |
| Product Write / File              | `API-FILE-02`    | DELETE     | `/api/v1/files/{file_id}`                              | Bearer + owner                                         | Xóa file tạm chưa gắn Product – **[Bổ sung hợp lý / Giả định]**   |
| Product Write / File              | `API-FILE-03`    | GET        | `/api/v1/files/{file_id}/content`                      | Public nếu file public; nếu private thì Bearer + quyền | Stream file qua FastAPI; Flutter không truy cập Storage trực tiếp |
| Product Write / File              | `API-PRODUCT-01` | POST       | `/api/v1/products`                                     | Bearer                                                 | Tạo tin                                                           |
| Product Write / File              | `API-PRODUCT-02` | PATCH      | `/api/v1/products/{product_id}`                        | Bearer + Owner                                         | Sửa tin                                                           |
| Product Write / File              | `API-PRODUCT-03` | POST       | `/api/v1/products/{product_id}/hide`                   | Bearer + Owner                                         | Ẩn                                                                |
| Product Write / File              | `API-PRODUCT-04` | POST       | `/api/v1/products/{product_id}/publish`                | Bearer + Owner                                         | Hiện lại                                                          |
| Product Write / File              | `API-PRODUCT-05` | POST       | `/api/v1/products/{product_id}/mark-sold`              | Bearer + Owner                                         | Đánh dấu `SOLD`                                                   |
| Product Write / File              | `API-PRODUCT-06` | DELETE     | `/api/v1/products/{product_id}`                        | Bearer + Owner                                         | Soft delete                                                       |
| Product Write / File              | `API-PRODUCT-07` | GET        | `/api/v1/users/me/products`                            | Bearer                                                 | Tin của tôi                                                       |
| Wishlist                          | `API-WISH-01`    | GET        | `/api/v1/me/wishlist`                                  | Bearer                                                 | Wishlist phân trang                                               |
| Wishlist                          | `API-WISH-02`    | PUT        | `/api/v1/me/wishlist/{product_id}`                     | Bearer                                                 | Thêm yêu thích (idempotent)                                       |
| Wishlist                          | `API-WISH-03`    | DELETE     | `/api/v1/me/wishlist/{product_id}`                     | Bearer                                                 | Bỏ yêu thích                                                      |
| Chat                              | `API-CHAT-01`    | GET        | `/api/v1/conversations`                                | Bearer                                                 | Danh sách hội thoại                                               |
| Chat                              | `API-CHAT-02`    | POST       | `/api/v1/conversations`                                | Bearer                                                 | Tìm/tạo hội thoại                                                 |
| Chat                              | `API-CHAT-03`    | GET        | `/api/v1/conversations/{id}/messages`                  | Bearer + Participant                                   | Lịch sử                                                           |
| Chat                              | `API-CHAT-04`    | POST       | `/api/v1/conversations/{id}/read`                      | Bearer + Participant                                   | Đánh dấu đã đọc                                                   |
| Chat                              | `API-CHAT-05`    | WS         | `/api/v1/ws/chat`                                      | Bearer handshake                                       | Real-time events                                                  |
| Transaction Confirmation / Review | `API-TXN-01`     | POST       | `/api/v1/products/{product_id}/purchase-confirmations` | Bearer + Buyer                                         | Buyer yêu cầu xác nhận                                            |
| Transaction Confirmation / Review | `API-TXN-02`     | POST       | `/api/v1/purchase-confirmations/{id}/decision`         | Bearer + Seller                                        | Seller confirm/reject                                             |
| Transaction Confirmation / Review | `API-TXN-03`     | GET        | `/api/v1/me/pending-reviews`                           | Bearer                                                 | Danh sách chờ review                                              |
| Transaction Confirmation / Review | `API-REVIEW-01`  | POST       | `/api/v1/purchase-confirmations/{id}/review`           | Bearer + Buyer                                         | Tạo review                                                        |
| Transaction Confirmation / Review | `API-REVIEW-02`  | GET        | `/api/v1/users/{user_id}/reviews`                      | Public                                                 | Review của seller                                                 |
| Share                             | `API-SHARE-01`   | GET        | `/api/v1/products/{product_id}/share-metadata`         | Public                                                 | Metadata chia sẻ                                                  |
| Report                            | `API-REPORT-01`  | POST       | `/api/v1/reports/products`                             | Bearer                                                 | Tạo report Product                                                |
| Report                            | `API-REPORT-02`  | GET        | `/api/v1/me/reports`                                   | Bearer                                                 | Report của tôi                                                    |
| Report                            | `API-REPORT-03`  | GET        | `/api/v1/me/reports/{report_id}`                       | Bearer + Reporter                                      | Chi tiết report                                                   |
| Admin                             | `API-ADMIN-01`   | GET        | `/api/v1/admin/reports`                                | Bearer + `ADMIN`                                       | Report list                                                       |
| Admin                             | `API-ADMIN-02`   | GET        | `/api/v1/admin/reports/{report_id}`                    | Bearer + `ADMIN`                                       | Report detail                                                     |
| Admin                             | `API-ADMIN-03`   | POST       | `/api/v1/admin/reports/{report_id}/resolve`            | Bearer + `ADMIN`                                       | Resolve report                                                    |
| Admin                             | `API-ADMIN-04`   | POST       | `/api/v1/admin/users/{user_id}/ban`                    | Bearer + `ADMIN`                                       | Ban user                                                          |
| Admin                             | `API-ADMIN-05`   | POST       | `/api/v1/admin/products/{product_id}/restore`          | Bearer + `ADMIN`                                       | Restore tin gỡ nhầm – **[Bổ sung hợp lý / Giả định; Should]**     |

### Health check

`GET /api/v1/health` public.

```json
{
  "data": {"status": "ok", "service": "marketplace-api", "api_version": "v1"},
  "meta": {}
}
```

Không đưa credential/connection string vào health response.

## 4. Chi tiết theo module

### 4.1. Auth — Xác thực, phiên đăng nhập

> **Phụ trách chính:** TV1 · **Phối hợp:** TV2 · Nguồn SRS mục 4.1

| **ID**        | **Method + Endpoint**               | **Auth**           | **Mục đích**                           |
| ------------- | ----------------------------------- | ------------------ | -------------------------------------- |
| `API-AUTH-01` | `POST /api/v1/auth/register`        | Public             | Tạo tài khoản                          |
| `API-AUTH-02` | `POST /api/v1/auth/login`           | Public             | Đăng nhập                              |
| `API-AUTH-03` | `POST /api/v1/auth/refresh`         | Refresh token      | Cấp access token mới                   |
| `API-AUTH-04` | `POST /api/v1/auth/logout`          | Bearer             | Thu hồi refresh session                |
| `API-AUTH-05` | `GET /api/v1/auth/me`               | Bearer             | User hiện tại                          |
| `API-AUTH-06` | `POST /api/v1/auth/password/forgot` | Public             | Gửi email reset                        |
| `API-AUTH-07` | `POST /api/v1/auth/password/reset`  | Reset token        | Đặt lại mật khẩu                       |
| `API-AUTH-08` | `POST /api/v1/auth/email/verify`    | Verification token | Xác minh email (tùy chọn, làm sau MVP) |

**Request – Register**

```json
{
  "display_name": "Nguyen Van A",
  "email": "a@example.com",
  "password": "Example123",
  "password_confirmation": "Example123"
}
```

**Response `201` – Register**

```json
{
  "data": {
    "user": {
      "id": "usr_01JABC123",
      "display_name": "Nguyen Van A",
      "email": "a@example.com",
      "status": "ACTIVE",
      "role": "USER",
      "email_verified": false,
      "created_at": "2026-11-27T03:00:00Z"
    },
    "verification_required": false
  },
  "meta": {}
}
```

**Request – Login**

```json
{
  "email": "a@example.com",
  "password": "Example123"
}
```

**Response `200` – Login**

```json
{
  "data": {
    "access_token": "<jwt-access-token>",
    "token_type": "Bearer",
    "expires_in": 900,
    "refresh_token": "<opaque-refresh-token>",
    "refresh_expires_at": "2026-12-27T03:00:00Z",
    "user": {
      "id": "usr_01JABC123",
      "display_name": "Nguyen Van A",
      "role": "USER",
      "status": "ACTIVE",
      "email_verified": true
    }
  },
  "meta": {}
}
```

**Request – Refresh**

```json
{
  "refresh_token": "<opaque-refresh-token>"
}
```

**Response `200` – Refresh**

```json
{
  "data": {
    "access_token": "<new-jwt-access-token>",
    "token_type": "Bearer",
    "expires_in": 900,
    "refresh_token": "<rotated-refresh-token>"
  },
  "meta": {}
}
```

**Request – Logout**

```json
{
  "refresh_token": "<opaque-refresh-token>"
}
```

Response: `204`, không body.

**Request – Forgot password**

```json
{
  "email": "a@example.com"
}
```

**Response 202 – Forgot password**

```json
{
  "data": {
    "message": "Nếu email hợp lệ, hướng dẫn đặt lại mật khẩu sẽ được gửi."
  },
  "meta": {}
}
```

**Request – Reset password**

```json
{
  "reset_token": "<single-use-reset-token>",
  "new_password": "NewExample456",
  "password_confirmation": "NewExample456"
}
```

**Response `200` – Reset password**

```json
{
  "data": {
    "password_reset": true
  },
  "meta": {}
}
```

**Request – Verify email**

```json
{
  "verification_token": "<single-use-verification-token>"
}
```

**Response `200` – Verify email**

```json
{
  "data": {
    "email_verified": true,
    "status": "ACTIVE"
  },
  "meta": {}
}
```

**Lỗi:** `401` `AUTH_INVALID_CREDENTIALS` khi sai credentials hoặc token không hợp lệ; `403` `ACCOUNT_BANNED` / `EMAIL_NOT_VERIFIED`; `404` `AUTH_USER_NOT_FOUND` khi có target user; `409` `AUTH_EMAIL_EXISTS` khi email đăng ký đã tồn tại; `422` `VALIDATION_ERROR`. `404` `AUTH_USER_NOT_FOUND` khi có target user; `422` `VALIDATION_ERROR`; email trùng register trả `409` `AUTH_EMAIL_EXISTS` – **[Bổ sung hợp lý / Giả định]**. Response Error Envelope xem mục 8.2.

| **Trường**              | **Kiểu**          | **Bắt buộc** | **Quy tắc**                                                         |
| ----------------------- | ----------------- | ------------ | ------------------------------------------------------------------- |
| `display_name`          | string            | Required     | 2–50 ký tự sau trim – **[Giữ từ SRS 0.1]**                          |
| email                   | string            | Required     | Email hợp lệ; normalize lowercase – **[Bổ sung hợp lý / Giả định]** |
| password                | string            | Required     | Tối thiểu 8 ký tự, chữ và số – **[Giữ từ SRS 0.1; cần duyệt]**      |
| `password_confirmation` | string            | Required     | Phải trùng password; không lưu                                      |
| `expires_in`            | int               | Response     | Thời hạn access token (giây)                                        |
| `email_verified`        | boolean           | Response     | Trạng thái xác minh                                                 |
| `created_at`            | datetime ISO-8601 | Response     | UTC, hậu tố Z                                                       |

**Token policy (đã chốt `OQ-04`):** access token 15 phút; refresh token opaque, lưu hash trong DB, xoay vòng mỗi lần refresh; logout thu hồi session hiện tại. Refresh token 30 ngày; reset mật khẩu thu hồi toàn bộ refresh session. Không lưu password/refresh token dạng plaintext trong Flutter; dùng secure storage thay vì SharedPreferences thuần.

### 4.2. Profile — Hồ sơ người dùng và quyền riêng tư

> **Phụ trách chính:** TV1 · **Phối hợp:** TV3 · Nguồn SRS mục 4.2

| **ID**           | **Method + Endpoint**         | **Auth**           | **Mục đích**    |
| ---------------- | ----------------------------- | ------------------ | --------------- |
| `API-PROFILE-01` | `GET /api/v1/users/me`        | Bearer             | Hồ sơ của mình  |
| `API-PROFILE-02` | `PATCH /api/v1/users/me`      | Bearer             | Cập nhật hồ sơ  |
| `API-PROFILE-03` | `GET /api/v1/users/{user_id}` | Public hoặc Bearer | Hồ sơ công khai |

**Request – `API-PROFILE-02`**

```json
{
  "display_name": "Nguyen Van A",
  "school": "Truong Dai hoc A",
  "bio": "Sinh vien, co mot so mon do can thanh ly.",
  "default_area": "Khu vuc Thu Duc",
  "avatar_file_id": "fil_01JAVATAR"
}
```

**Response `200` – `API-PROFILE-02`**

```json
{
  "data": {
    "id": "usr_01JABC123",
    "display_name": "Nguyen Van A",
    "school": "Truong Dai hoc A",
    "school_disclaimer": "Thong tin do nguoi dung tu khai bao",
    "bio": "Sinh vien, co mot so mon do can thanh ly.",
    "default_area": "Khu vuc Thu Duc",
    "avatar_url": "https://api.example.invalid/api/v1/files/fil_01JAVATAR/content",
    "created_at": "2026-11-20T10:00:00Z"
  },
  "meta": {}
}
```

**Response `200` – `API-PROFILE-03` (Public DTO)**

```json
{
  "data": {
    "id": "usr_01JABC123",
    "display_name": "Nguyen Van A",
    "avatar_url": "https://api.example.invalid/api/v1/files/fil_01JAVATAR/content",
    "school": "Truong Dai hoc A",
    "school_disclaimer": "Tu khai bao",
    "bio": "Sinh vien",
    "created_at": "2026-11-20T10:00:00Z",
    "review_average": 4.7,
    "review_count": 12,
    "completed_confirmations_count": 9,
    "products": []
  },
  "meta": {}
}
```

GET không có request body. Lỗi: `400` `PROFILE_INVALID_DATA`; `401` `AUTH_REQUIRED`; `404` `USER_NOT_FOUND`; `422` `VALIDATION_ERROR`. Public endpoint tuyệt đối không trả email, password hash, refresh token, private address hoặc nội dung chat.

| **Trường**       | **Kiểu**          | **Bắt buộc**     | **Validate**                      |
| ---------------- | ----------------- | ---------------- | --------------------------------- |
| `display_name`   | string            | Optional ở PATCH | 2–50 ký tự sau trim               |
| school           | string            | Optional         | Tối đa 80 ký tự                   |
| bio              | string            | Optional         | Tối đa 200 ký tự                  |
| `default_area`   | string            | Optional         | 2–60 ký tự; chỉ khu vực tổng quát |
| `avatar_file_id` | string            | Optional         | File ID hợp lệ do API upload cấp  |
| `review_average` | float             | Response         | 0.0–5.0; làm tròn 1 chữ số        |
| `review_count`   | int               | Response         | \>= 0                             |
| `created_at`     | datetime ISO-8601 | Response         | UTC                               |

### 4.3. Browse / Product Read — Danh mục, danh sách, tìm kiếm, chi tiết sản phẩm

> **Phụ trách chính:** TV1 · **Phối hợp:** TV2 · Nguồn SRS mục 4.3

| **ID**          | **Method + Endpoint**                  | **Auth** | **Mục đích**                  |
| --------------- | -------------------------------------- | -------- | ----------------------------- |
| `API-BROWSE-01` | `GET /api/v1/categories`               | Public   | Danh mục active               |
| `API-BROWSE-02` | `GET /api/v1/products`                 | Public   | List/search/filter/pagination |
| `API-BROWSE-03` | `GET /api/v1/products/{product_id}`    | Public   | Product detail                |
| `API-BROWSE-04` | `GET /api/v1/users/{user_id}/products` | Public   | Product public của seller     |

**Request – `API-BROWSE-02` (query, không body)**

```http
GET /api/v1/products?q=giao%20trinh&category_id=cat_books&page=1&page_size=20&sort=created_desc
Authorization: Bearer <access-token-if-signed-in>
```

**Response `200` – `API-BROWSE-02`**

```json
{
  "data": [
    {
      "id": "prd_01JPRODUCT1",
      "title": "Giao trinh Giai tich 1",
      "price_vnd": 45000,
      "condition": "GOOD",
      "category": {"id": "cat_books", "name": "Sach & giao trinh"},
      "cover_image_url": "https://api.example.invalid/api/v1/files/fil_01JIMAGE123/content",
      "area": "Thu Duc",
      "seller": {"id": "usr_01JABC123", "display_name": "Nguyen Van A", "avatar_url": null},
      "status": "AVAILABLE",
      "created_at": "2026-11-27T02:30:00Z"
    }
  ],
  "meta": {"page": 1, "page_size": 20, "total_items": 1, "total_pages": 1}
}
```

**Request – `API-BROWSE-03`:** Không body; path `product_id` kiểu string.

**Response `200` – `API-BROWSE-03`**

```json
{
  "data": {
    "id": "prd_01JPRODUCT1",
    "seller_id": "usr_01JABC123",
    "title": "Giao trinh Giai tich 1",
    "description": "Sach con tot, co ghi chu mot so trang.",
    "price_vnd": 45000,
    "negotiable": true,
    "condition": "GOOD",
    "category": {"id": "cat_books", "name": "Sach & giao trinh"},
    "area": "Thu Duc",
    "images": [{"id": "img_01", "url": "https://api.example.invalid/api/v1/files/fil_01JIMAGE123/content", "position": 0}],
    "status": "AVAILABLE",
    "seller": {"id": "usr_01JABC123", "display_name": "Nguyen Van A", "avatar_url": null, "school": "Truong Dai hoc A", "review_average": 4.7, "review_count": 12},
    "created_at": "2026-11-27T02:30:00Z",
    "updated_at": "2026-11-27T02:30:00Z"
  },
  "meta": {}
}
```

Lỗi: `400` `PRODUCT_QUERY_INVALID`; `401` chỉ khi endpoint yêu cầu auth theo cấu hình; `404` `PRODUCT_NOT_FOUND`/`PRODUCT_UNAVAILABLE`; `422` `VALIDATION_ERROR`.

| **Query/field**          | **Kiểu**          | **Required** | **Quy tắc**                                                  |
| ------------------------ | ----------------- | ------------ | ------------------------------------------------------------ |
| q                        | string            | Optional     | Trim, 1–100 ký tự; tìm trong title                           |
| `category_id`            | string            | Optional     | Category tồn tại và active                                   |
| page                     | int               | Optional     | Mặc định 1, min 1                                            |
| `page_size`              | int               | Optional     | Mặc định 20, min 1, max 50 – **[Bổ sung hợp lý / Giả định]** |
| sort                     | enum string       | Optional     | `created_desc`, `price_asc`, `price_desc`                    |
| `min_price`, `max_price` | int               | Optional     | 0–100.000.000 VND (`OQ-12`)                                  |
| condition                | enum string       | Optional     | NEW, `LIKE_NEW`, GOOD, FAIR, POOR                            |
| `created_at`             | datetime ISO-8601 | Response     | UTC                                                          |

### 4.4. Product Write / File — Tạo, sửa, ẩn, xóa tin và upload ảnh

> **Phụ trách chính:** TV3 · **Phối hợp:** TV1 · Nguồn SRS mục 4.4

| **ID**           | **Method + Endpoint**                          | **Auth**                                               | **Mục đích**                                                      |
| ---------------- | ---------------------------------------------- | ------------------------------------------------------ | ----------------------------------------------------------------- |
| `API-FILE-01`    | `POST /api/v1/files/images`                    | Bearer                                                 | Upload ảnh                                                        |
| `API-FILE-02`    | `DELETE /api/v1/files/{file_id}`               | Bearer + owner                                         | Xóa file tạm chưa gắn Product – **[Bổ sung hợp lý / Giả định]**   |
| `API-FILE-03`    | `GET /api/v1/files/{file_id}/content`          | Public nếu file public; nếu private thì Bearer + quyền | Stream file qua FastAPI; Flutter không truy cập Storage trực tiếp |
| `API-PRODUCT-01` | `POST /api/v1/products`                        | Bearer                                                 | Tạo tin                                                           |
| `API-PRODUCT-02` | `PATCH /api/v1/products/{product_id}`          | Bearer + Owner                                         | Sửa tin                                                           |
| `API-PRODUCT-03` | `POST /api/v1/products/{product_id}/hide`      | Bearer + Owner                                         | Ẩn                                                                |
| `API-PRODUCT-04` | `POST /api/v1/products/{product_id}/publish`   | Bearer + Owner                                         | Hiện lại                                                          |
| `API-PRODUCT-05` | `POST /api/v1/products/{product_id}/mark-sold` | Bearer + Owner                                         | Đánh dấu `SOLD`                                                   |
| `API-PRODUCT-06` | `DELETE /api/v1/products/{product_id}`         | Bearer + Owner                                         | Soft delete                                                       |
| `API-PRODUCT-07` | `GET /api/v1/users/me/products`                | Bearer                                                 | Tin của tôi                                                       |

**Request – `API-FILE-01`:** multipart/form-data, field file kiểu binary, Header Bearer; không gửi JSON. FastAPI kiểm tra file và ghi vào storage server-side.

**`API-FILE-03`:** GET không có body; thành công trả bytes của ảnh với Content-Type: image/jpeg\|image/png\|image/webp, Cache-Control phù hợp và ETag nếu được hỗ trợ. Flutter chỉ tải ảnh từ URL FastAPI dạng `/api/v1/files/{file_id}/content`; tuyệt đối không nhận storage key hoặc URL nội bộ để gọi trực tiếp.

**Response `201` – `API-FILE-01`**

```json
{
  "data": {
    "id": "fil_01JIMAGE123",
    "file_name": "product_01.webp",
    "mime_type": "image/webp",
    "size_bytes": 420000,
    "width": 1280,
    "height": 960,
    "status": "TEMPORARY",
    "created_at": "2026-11-27T03:15:00Z"
  },
  "meta": {}
}
```

**Request – `API-PRODUCT-01`**

```json
{
  "title": "Giao trinh Giai tich 1",
  "description": "Sach con tot, co ghi chu mot so trang.",
  "price_vnd": 45000,
  "category_id": "cat_books",
  "condition": "GOOD",
  "area": "Thu Duc",
  "negotiable": true,
  "image_ids": ["fil_01JIMAGE123", "fil_01JIMAGE124"]
}
```

**Response `201` – `API-PRODUCT-01`**

```json
{
  "data": {
    "id": "prd_01JPRODUCT1",
    "seller_id": "usr_01JABC123",
    "title": "Giao trinh Giai tich 1",
    "price_vnd": 45000,
    "category_id": "cat_books",
    "condition": "GOOD",
    "area": "Thu Duc",
    "negotiable": true,
    "status": "AVAILABLE",
    "images": [
      {"id": "img_01", "url": "https://api.example.invalid/api/v1/files/fil_01JIMAGE123/content", "position": 0},
      {"id": "img_02", "url": "https://api.example.invalid/api/v1/files/fil_01JIMAGE124/content", "position": 1}
    ],
    "created_at": "2026-11-27T03:20:00Z"
  },
  "meta": {}
}
```

**Request – `API-PRODUCT-02` (PATCH)**

```json
{
  "title": "Giao trinh Giai tich 1 - ban moi",
  "description": "Mo ta da cap nhat.",
  "price_vnd": 40000,
  "image_ids": ["fil_01JIMAGE123", "fil_01JIMAGE125"]
}
```

**Response `200` – `API-PRODUCT-02`**

```json
{
  "data": {
    "id": "prd_01JPRODUCT1",
    "title": "Giao trinh Giai tich 1 - ban moi",
    "price_vnd": 40000,
    "status": "AVAILABLE",
    "updated_at": "2026-11-27T03:30:00Z"
  },
  "meta": {}
}
```

**Request – `API-PRODUCT-03`/04/05:**

```json
{
  "reason": "Seller action from My Products screen"
}
```

optional. Server không tin `seller_id`, status, `created_at` do client gửi.

**Response `200` – status action**

```json
{
  "data": {
    "id": "prd_01JPRODUCT1",
    "status": "SOLD",
    "updated_at": "2026-11-27T03:35:00Z"
  },
  "meta": {}
}
```

**Response `200` – `API-PRODUCT-06`:**

```json
{
  "data": {
    "id": "prd_01JPRODUCT1",
    "status": "DELETED"
  },
  "meta": {}
}
```

khi triển khai phải chốt response `200` hoặc `204`, không dùng lẫn.

**Lỗi:** `400` `PRODUCT_STATE_CONFLICT`; `401` `AUTH_REQUIRED`; `404` `PRODUCT_NOT_FOUND`; `422` `VALIDATION_ERROR`; owner khác nhận `403` `PRODUCT_FORBIDDEN`; file sai trả `422` `FILE_INVALID`; file quá dung lượng trả `413` `FILE_TOO_LARGE`.

| **Field**     | **Kiểu**      | **Required**                     | **Quy tắc**                                                   |
| ------------- | ------------- | -------------------------------- | ------------------------------------------------------------- |
| title         | string        | Required create / Optional patch | 5–100 ký tự – **[Giữ từ SRS 0.1]**                            |
| description   | string        | Required create / Optional patch | 10–2000 ký tự (`OQ-12`)                                       |
| `price_vnd`   | int           | Required create / Optional patch | 0–100.000.000; số nguyên; 0 = Cho tặng – **[Giữ từ SRS 0.1]** |
| `category_id` | string        | Required create                  | Category tồn tại và active                                    |
| condition     | enum string   | Required create                  | NEW, `LIKE_NEW`, GOOD, FAIR, POOR                             |
| area          | string        | Required create                  | 2–60 ký tự; khu vực chung, không phải địa chỉ nhà             |
| negotiable    | boolean       | Required create                  | true/false                                                    |
| `image_ids`   | array[string] | Required create                  | 1–5 ảnh (`OQ-12`); mọi file thuộc user                        |
| file          | binary        | Required upload                  | JPG/PNG/WebP; tối đa 5 MB (`OQ-12`)                           |
| status        | enum string   | Server only                      | `AVAILABLE`, `HIDDEN`, `SOLD`, `BLOCKED`, `DELETED`           |

### 4.5. Wishlist — Tin yêu thích

> **Phụ trách chính:** TV1 · **Phối hợp:** TV2 · Nguồn SRS mục 4.5

| **ID**        | **Method + Endpoint**                     | **Auth** | **Mục đích**                |
| ------------- | ----------------------------------------- | -------- | --------------------------- |
| `API-WISH-01` | `GET /api/v1/me/wishlist`                 | Bearer   | Wishlist phân trang         |
| `API-WISH-02` | `PUT /api/v1/me/wishlist/{product_id}`    | Bearer   | Thêm yêu thích (idempotent) |
| `API-WISH-03` | `DELETE /api/v1/me/wishlist/{product_id}` | Bearer   | Bỏ yêu thích                |

`API-WISH-02`/03 không có request body.

**Response `200` – `API-WISH-02`**

```json
{
  "data": {
    "product_id": "prd_01JPRODUCT1",
    "is_favorite": true,
    "created_at": "2026-11-27T03:40:00Z"
  },
  "meta": {}
}
```

**Response `200` – `API-WISH-01`**

```json
{
  "data": [
    {
      "product_id": "prd_01JPRODUCT1",
      "title": "Giao trinh Giai tich 1",
      "price_vnd": 45000,
      "product_status": "SOLD",
      "cover_image_url": "https://api.example.invalid/api/v1/files/fil_01JIMAGE123/content",
      "saved_at": "2026-11-27T03:40:00Z"
    }
  ],
  "meta": {"page": 1, "page_size": 20, "total_items": 1}
}
```

Lỗi: `400` `WISHLIST_INVALID`; `401` `AUTH_REQUIRED`; `404` `PRODUCT_NOT_FOUND`; `422` `VALIDATION_ERROR`; `409` `WISHLIST_SELF_PRODUCT` nếu lưu tin của chính mình.

| **Trường**    | **Kiểu**          | **Required**  | **Validate**        |
| ------------- | ----------------- | ------------- | ------------------- |
| `product_id`  | string            | Path required | Product ID hợp lệ   |
| `is_favorite` | boolean           | Response      | Trạng thái hiện tại |
| `saved_at`    | datetime ISO-8601 | Response      | UTC                 |

### 4.6. Chat — Hội thoại, tin nhắn, WebSocket

> **Phụ trách chính:** TV4 · **Phối hợp:** TV1 · Nguồn SRS mục 4.6

| **ID**        | **Method + Endpoint**                     | **Auth**             | **Mục đích**        |
| ------------- | ----------------------------------------- | -------------------- | ------------------- |
| `API-CHAT-01` | `GET /api/v1/conversations`               | Bearer               | Danh sách hội thoại |
| `API-CHAT-02` | `POST /api/v1/conversations`              | Bearer               | Tìm/tạo hội thoại   |
| `API-CHAT-03` | `GET /api/v1/conversations/{id}/messages` | Bearer + Participant | Lịch sử             |
| `API-CHAT-04` | `POST /api/v1/conversations/{id}/read`    | Bearer + Participant | Đánh dấu đã đọc     |
| `API-CHAT-05` | WS `/api/v1/ws/chat`                      | Bearer handshake     | Real-time events    |

**Request – `API-CHAT-02`**

```json
{
  "product_id": "prd_01JPRODUCT1"
}
```

**Response `201` – `API-CHAT-02`**

```json
{
  "data": {
    "id": "cnv_01JCONV1",
    "product_id": "prd_01JPRODUCT1",
    "buyer_id": "usr_01JBUYER1",
    "seller_id": "usr_01JABC123",
    "created_at": "2026-11-27T04:00:00Z",
    "is_new": true
  },
  "meta": {}
}
```

**Request – `API-CHAT-03`:** query limit=30&before=\<`message_id`\>; không body.

**Response `200` – `API-CHAT-03`**

```json
{
  "data": [
    {
      "id": "msg_01JMESSAGE1",
      "conversation_id": "cnv_01JCONV1",
      "sender_id": "usr_01JBUYER1",
      "type": "TEXT",
      "text": "Mon nay con khong ban?",
      "client_message_id": "local-uuid-123",
      "created_at": "2026-11-27T04:01:00Z",
      "read_at": null
    }
  ],
  "meta": {"next_cursor": null, "has_more": false}
}
```

WebSocket handshake: wss://\<api-host\>`/api/v1/ws/chat`; Authorization qua secure WebSocket subprotocol hoặc cơ chế handshake TV1 quy định; không đặt token trong URL query – **[Bổ sung hợp lý / Giả định]**.

**Client event**

```json
{
  "event": "message.send",
  "data": {
    "conversation_id": "cnv_01JCONV1",
    "client_message_id": "local-uuid-123",
    "text": "Mon nay con khong ban?"
  }
}
```

**Server event – ack**

```json
{
  "event": "message.ack",
  "data": {
    "client_message_id": "local-uuid-123",
    "message_id": "msg_01JMESSAGE1",
    "status": "SENT",
    "created_at": "2026-11-27T04:01:00Z"
  }
}
```

**Server event – new message**

```json
{
  "event": "message.new",
  "data": {
    "conversation_id": "cnv_01JCONV1",
    "message": {
      "id": "msg_01JMESSAGE1",
      "sender_id": "usr_01JBUYER1",
      "type": "TEXT",
      "text": "Mon nay con khong ban?",
      "created_at": "2026-11-27T04:01:00Z"
    }
  }
}
```

REST errors: `400` `CHAT_INVALID_REQUEST`; `401` `AUTH_REQUIRED`; `404` `CONVERSATION_NOT_FOUND`/`PRODUCT_NOT_FOUND`; `422` `VALIDATION_ERROR`. WebSocket lỗi dùng event error có code, message, retryable; close code `4401` (chưa xác thực/hết hạn), `4403` (không có quyền) – `OQ-06`.

| **Field**           | **Kiểu**          | **Required**      | **Validate**                                            |
| ------------------- | ----------------- | ----------------- | ------------------------------------------------------- |
| `product_id`        | string            | Required          | Product tồn tại, `AVAILABLE`, buyer khác seller         |
| text                | string            | Required với TEXT | 1–1000 ký tự sau trim – **[Giữ từ SRS 0.1; cần duyệt]** |
| `client_message_id` | string            | Required          | UUID do Flutter sinh; unique theo sender                |
| type                | enum string       | Server/response   | TEXT, SYSTEM; client không gửi SYSTEM                   |
| `created_at`        | datetime ISO-8601 | Response          | Server timestamp UTC                                    |
| limit               | int               | Optional          | Default 30, max 100 – **[Bổ sung hợp lý / Giả định]**   |

### 4.7. Transaction Confirmation / Review — Xác nhận giao dịch và đánh giá người bán

> **Phụ trách chính:** TV3 · **Phối hợp:** TV1 · Nguồn SRS mục 4.7

| **ID**          | **Method + Endpoint**                                       | **Auth**        | **Mục đích**           |
| --------------- | ----------------------------------------------------------- | --------------- | ---------------------- |
| `API-TXN-01`    | `POST /api/v1/products/{product_id}/purchase-confirmations` | Bearer + Buyer  | Buyer yêu cầu xác nhận |
| `API-TXN-02`    | `POST /api/v1/purchase-confirmations/{id}/decision`         | Bearer + Seller | Seller confirm/reject  |
| `API-TXN-03`    | `GET /api/v1/me/pending-reviews`                            | Bearer          | Danh sách chờ review   |
| `API-REVIEW-01` | `POST /api/v1/purchase-confirmations/{id}/review`           | Bearer + Buyer  | Tạo review             |
| `API-REVIEW-02` | `GET /api/v1/users/{user_id}/reviews`                       | Public          | Review của seller      |

**Request – `API-TXN-01`**

```json
{
  "conversation_id": "cnv_01JCONV1",
  "buyer_note": "Hai ben da gap va nhan hang truc tiep."
}
```

**Response `201` – `API-TXN-01`**

```json
{
  "data": {
    "id": "txn_01JCONFIRM1",
    "product_id": "prd_01JPRODUCT1",
    "conversation_id": "cnv_01JCONV1",
    "buyer_id": "usr_01JBUYER1",
    "seller_id": "usr_01JABC123",
    "status": "PENDING",
    "created_at": "2026-11-27T05:00:00Z"
  },
  "meta": {}
}
```

**Request – `API-TXN-02`**

```json
{
  "decision": "CONFIRM",
  "note": null
}
```

**Response `200` – `API-TXN-02`**

```json
{
  "data": {
    "id": "txn_01JCONFIRM1",
    "status": "COMPLETED",
    "product_id": "prd_01JPRODUCT1",
    "product_status": "SOLD",
    "decided_at": "2026-11-27T05:10:00Z"
  },
  "meta": {}
}
```

**Request – `API-REVIEW-01`**

```json
{
  "rating": 5,
  "comment": "Nguoi ban giao dich dung hen, thong tin san pham ro rang."
}
```

**Response `201` – `API-REVIEW-01`**

```json
{
  "data": {
    "id": "rev_01JREVIEW1",
    "confirmation_id": "txn_01JCONFIRM1",
    "seller_id": "usr_01JABC123",
    "buyer_id": "usr_01JBUYER1",
    "rating": 5,
    "comment": "Nguoi ban giao dich dung hen, thong tin san pham ro rang.",
    "created_at": "2026-11-27T05:15:00Z"
  },
  "meta": {}
}
```

**Response `200` – `API-REVIEW-02`**

```json
{
  "data": {
    "average_rating": 4.7,
    "review_count": 12,
    "items": [
      {
        "id": "rev_01JREVIEW1",
        "buyer_display_name": "Nguyen B",
        "rating": 5,
        "comment": "Giao dich dung hen.",
        "product_title": "Giao trinh Giai tich 1",
        "created_at": "2026-11-27T05:15:00Z"
      }
    ]
  },
  "meta": {"page": 1, "page_size": 20}
}
```

**Lỗi:** `400` `TRANSACTION_STATE_INVALID`; `401` `AUTH_REQUIRED`; `404` `CONFIRMATION_NOT_FOUND`; `422` `VALIDATION_ERROR`; `403` nếu không đúng buyer/seller; `409` `REVIEW_ALREADY_EXISTS` hoặc `PRODUCT_ALREADY_COMPLETED`.

| **Field**                  | **Kiểu**          | **Required** | **Validate**                                                      |
| -------------------------- | ----------------- | ------------ | ----------------------------------------------------------------- |
| `conversation_id`          | string            | Required     | Conversation có buyer hiện tại, seller khớp owner Product         |
| `buyer_note`               | string            | Optional     | 0–500 ký tự – **[Bổ sung hợp lý / Giả định]**                     |
| decision                   | enum string       | Required     | CONFIRM hoặc REJECT                                               |
| note                       | string/null       | Optional     | 0–500 ký tự; chủ yếu cho REJECT – **[Bổ sung hợp lý / Giả định]** |
| rating                     | int               | Required     | 1–5                                                               |
| comment                    | string            | Optional     | 0–500 ký tự                                                       |
| `created_at`, `decided_at` | datetime ISO-8601 | Response     | UTC                                                               |

### 4.8. Share — Metadata chia sẻ sản phẩm

> **Phụ trách chính:** TV3 · **Phối hợp:** TV1 · Nguồn SRS mục 4.8

| **ID**         | **Method + Endpoint**                              | **Auth** | **Mục đích**     |
| -------------- | -------------------------------------------------- | -------- | ---------------- |
| `API-SHARE-01` | `GET /api/v1/products/{product_id}/share-metadata` | Public   | Metadata chia sẻ |

Request: không body.

**Response `200` – `API-SHARE-01`**

```json
{
  "data": {
    "title": "Giao trinh Giai tich 1",
    "price_text": "45.000 d",
    "canonical_url": "https://app.example.invalid/p/prd_01JPRODUCT1",
    "availability": "AVAILABLE"
  },
  "meta": {}
}
```

Lỗi: `400` `SHARE_INVALID_PRODUCT_ID`; `401` không bắt buộc cho public metadata; `404` `PRODUCT_UNAVAILABLE`; `422` `VALIDATION_ERROR`.

| **Field**       | **Kiểu** | **Required**  | **Validate**                   |
| --------------- | -------- | ------------- | ------------------------------ |
| `product_id`    | string   | Path required | ID public hợp lệ               |
| `canonical_url` | string   | Response      | HTTPS, chỉ ID/slug, không PII  |
| availability    | enum     | Response      | `AVAILABLE`/`SOLD`/UNAVAILABLE |

### 4.9. Report — Báo cáo tin vi phạm

> **Phụ trách chính:** TV4 · **Phối hợp:** TV1 · Nguồn SRS mục 4.9

| **ID**          | **Method + Endpoint**                | **Auth**          | **Mục đích**       |
| --------------- | ------------------------------------ | ----------------- | ------------------ |
| `API-REPORT-01` | `POST /api/v1/reports/products`      | Bearer            | Tạo report Product |
| `API-REPORT-02` | `GET /api/v1/me/reports`             | Bearer            | Report của tôi     |
| `API-REPORT-03` | `GET /api/v1/me/reports/{report_id}` | Bearer + Reporter | Chi tiết report    |

**Request – `API-REPORT-01`**

```json
{
  "product_id": "prd_01JPRODUCT1",
  "reason": "MISLEADING",
  "description": "Anh va mo ta khong trung khop voi san pham nhan duoc trong thong tin dang ban."
}
```

**Response `201` – `API-REPORT-01`**

```json
{
  "data": {
    "id": "rpt_01JREPORT1",
    "product_id": "prd_01JPRODUCT1",
    "reason": "MISLEADING",
    "status": "PENDING",
    "created_at": "2026-11-27T06:00:00Z"
  },
  "meta": {}
}
```

**Response `200` – `API-REPORT-02`**

```json
{
  "data": [
    {
      "id": "rpt_01JREPORT1",
      "product_id": "prd_01JPRODUCT1",
      "product_title_snapshot": "Giao trinh Giai tich 1",
      "reason": "MISLEADING",
      "status": "PENDING",
      "created_at": "2026-11-27T06:00:00Z",
      "resolved_at": null
    }
  ],
  "meta": {"page": 1, "page_size": 20, "total_items": 1}
}
```

Lỗi: `400` `REPORT_INVALID_TARGET`; `401` `AUTH_REQUIRED`; `404` `PRODUCT_NOT_FOUND`; `422` `VALIDATION_ERROR`; `409` `REPORT_ALREADY_PENDING`; `429` `REPORT_RATE_LIMITED` (giới hạn 10 report/24 giờ, `OQ-13`).

| **Field**    | **Kiểu**          | **Required** | **Validate**                               |
| ------------ | ----------------- | ------------ | ------------------------------------------ |
| `product_id` | string            | Required     | Product tồn tại; reporter không phải owner |
| reason       | enum string       | Required     | Mã Appendix C dành cho PRODUCT             |
| description  | string            | Optional     | 0–500 ký tự; OTHER tối thiểu 10            |
| status       | enum              | Response     | `PENDING`/RESOLVED/`REJECTED`              |
| `created_at` | datetime ISO-8601 | Response     | UTC                                        |

### 4.10. Admin — Kiểm duyệt và quản trị

> **Phụ trách chính:** TV4 · **Phối hợp:** TV1 · Nguồn SRS mục 4.10

| **ID**         | **Method + Endpoint**                              | **Auth**         | **Mục đích**                                                  |
| -------------- | -------------------------------------------------- | ---------------- | ------------------------------------------------------------- |
| `API-ADMIN-01` | `GET /api/v1/admin/reports`                        | Bearer + `ADMIN` | Report list                                                   |
| `API-ADMIN-02` | `GET /api/v1/admin/reports/{report_id}`            | Bearer + `ADMIN` | Report detail                                                 |
| `API-ADMIN-03` | `POST /api/v1/admin/reports/{report_id}/resolve`   | Bearer + `ADMIN` | Resolve report                                                |
| `API-ADMIN-04` | `POST /api/v1/admin/users/{user_id}/ban`           | Bearer + `ADMIN` | Ban user                                                      |
| `API-ADMIN-05` | `POST /api/v1/admin/products/{product_id}/restore` | Bearer + `ADMIN` | Restore tin gỡ nhầm – **[Bổ sung hợp lý / Giả định; Should]** |

**Request – `API-ADMIN-03`**

```json
{
  "action": "REMOVE_PRODUCT_AND_BAN_OWNER",
  "note": "Product co dau hieu lua dao; da kiem tra snapshot va thong tin hien tai."
}
```

Enum action: `REJECT_REPORT`, `REMOVE_PRODUCT`, `REMOVE_PRODUCT_AND_BAN_OWNER`.

**Response `200` – `API-ADMIN-03`**

```json
{
  "data": {
    "report_id": "rpt_01JREPORT1",
    "report_status": "RESOLVED",
    "action": "REMOVE_PRODUCT_AND_BAN_OWNER",
    "product_status": "BLOCKED",
    "owner_status": "BANNED",
    "resolved_at": "2026-11-27T07:00:00Z"
  },
  "meta": {}
}
```

**Request – `API-ADMIN-04`**

```json
{
  "reason": "Tai khoan co hanh vi vi pham lap lai."
}
```

**Response `200` – `API-ADMIN-04`**

```json
{
  "data": {
    "user_id": "usr_01JABC123",
    "status": "BANNED",
    "ban_reason": "Tai khoan co hanh vi vi pham lap lai.",
    "banned_at": "2026-11-27T07:05:00Z"
  },
  "meta": {}
}
```

Lỗi: `400` `ADMIN_ACTION_INVALID`; `401` `AUTH_REQUIRED`; `404` `REPORT_NOT_FOUND`/`USER_NOT_FOUND`; `422` `VALIDATION_ERROR`; `403` `ADMIN_REQUIRED`; `409` `REPORT_ALREADY_RESOLVED` hoặc `ADMIN_SELF_BAN_FORBIDDEN`.

| **Field**                  | **Kiểu**          | **Required**     | **Validate**                                        |
| -------------------------- | ----------------- | ---------------- | --------------------------------------------------- |
| action                     | enum string       | Required         | Một trong enum action                               |
| note                       | string            | Required         | Tối thiểu 5 ký tự – **[Giữ từ SRS 0.1; cần duyệt]** |
| reason                     | string            | Required khi ban | Tối thiểu 5 ký tự – **[Giữ từ SRS 0.1]**            |
| `resolved_at`, `banned_at` | datetime ISO-8601 | Response         | UTC                                                 |

## 5. Error catalog

| **ID** | **Tình huống**                                 | **Hành vi Flutter**                                                     | **Backend/HTTP**                                                                                               |
| ------ | ---------------------------------------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `E-01` | Mất mạng tải danh sách                         | Hiển thị cache nếu có, banner offline, nút retry                        | Không nhận được response; Flutter phân biệt network timeout với HTTP error.                                    |
| `E-02` | Mất mạng gửi chat                              | Tin ở trạng thái pending; gửi lại khi kết nối                           | WebSocket reconnect; gửi lại với `client_message_id` duy nhất.                                                 |
| `E-03` | Mất mạng/upload ảnh                            | Giữ form và tiến độ; thử upload lại; không tạo Product khi thiếu ảnh    | Chỉ tạo Product sau khi file hợp lệ và upload hoàn tất.                                                        |
| `E-04` | Access token hết hạn                           | Thử refresh một lần; nếu thất bại về Login                              | `401` `TOKEN_EXPIRED`; refresh endpoint xác thực refresh token.                                                |
| `E-05` | Không đủ quyền                                 | Thông báo thân thiện, không lặp request                                 | `403` FORBIDDEN; không tiết lộ dữ liệu nhạy cảm.                                                               |
| `E-06` | Product không còn tồn tại/không public         | Màn “Tin không còn tồn tại”                                             | `404` `PRODUCT_NOT_FOUND` hoặc `404` chung để tránh dò tài nguyên riêng tư.                                    |
| `E-07` | Product vừa chuyển `SOLD` khi nhắn tin         | Thông báo “Tin đã bán”; không tạo chat mới                              | `409` `PRODUCT_NOT_AVAILABLE`.                                                                                 |
| `E-08` | Gửi request trùng sau timeout                  | Không tạo hai message/record                                            | Idempotency key/client_message_id; trả kết quả bản ghi đã tạo.                                                 |
| `E-09` | Hai người cùng thao tác mark sold/confirmation | Hiển thị trạng thái mới nhất; yêu cầu reload                            | DB transaction + conditional update; một request thắng, request còn lại `409`.                                 |
| `E-10` | Report trùng                                   | Hiển thị đang chờ xử lý                                                 | `409` `DUPLICATE_PENDING_REPORT`.                                                                              |
| `E-11` | Rate limit                                     | Hiển thị thời điểm có thể thử lại nếu server cung cấp                   | `429` `RATE_LIMITED` + Retry-After. Ngưỡng: login 5 lần sai/15 phút (IP+email), report 10/ngày/user (`OQ-13`). |
| `E-12` | User bị ban khi đang dùng app                  | Chuyển về ban screen; hủy request ghi đang chờ                          | `403` `ACCOUNT_BANNED`; invalidate/deny further write.                                                         |
| `E-13` | Participant bị ban                             | Chat read-only theo policy; banner                                      | Backend từ chối gửi message nếu một participant bị ban.                                                        |
| `E-14` | Ảnh sai định dạng/quá lớn                      | Giữ ảnh hợp lệ; báo lỗi ảnh không hợp lệ                                | `413`/415 hoặc `422` theo lỗi cụ thể.                                                                          |
| `E-15` | Admin mở report đã xử lý                       | Hiển thị trạng thái đã giải quyết                                       | `409` `REPORT_ALREADY_RESOLVED`.                                                                               |
| `E-16` | Hai Admin cùng xử lý report                    | Người thứ hai nhận thông báo report đã xử lý                            | Optimistic concurrency/version check + transaction.                                                            |
| `E-17` | Quyền camera/thư viện bị từ chối               | Giải thích và mở cài đặt hệ thống                                       | Không gọi API.                                                                                                 |
| `E-18` | Màn nhỏ/chữ hệ thống lớn                       | Nội dung cuộn; không overflow                                           | QA kiểm thử ít nhất 2 thiết bị thật theo TASKS.                                                                |
| `E-19` | WebSocket disconnect                           | Hiển thị reconnecting; retry exponential backoff có giới hạn            | Server cấp lại kết nối; client sync message sau last acknowledged id.                                          |
| `E-20` | Logout có outbox chưa gửi                      | Cảnh báo và không gửi bằng tài khoản kế tiếp; xóa/giữ local theo policy | Không chấp nhận message mang token account khác; xử lý outbox riêng theo user.                                 |

## 6. Ví dụ bổ sung

Các endpoint ở bảng tổng hợp mục 8.5 vẫn phải tuân thủ Response Envelope ở mục 8.2. Với GET, HEAD, DELETE không cần Request Body trừ khi ghi rõ. Ví dụ dưới đây hoàn thiện payload thành công cho endpoint đã được liệt kê trong từng module.

### 6.1. Auth – current user

`GET /api/v1/auth/me` – Header Authorization: Bearer \<`access_token`\>; không request body.

```json
{
  "data": {
    "id": "usr_01JABC123",
    "display_name": "Nguyen Van A",
    "email": "a@example.com",
    "role": "USER",
    "status": "ACTIVE",
    "email_verified": true
  },
  "meta": {}
}
```

email chỉ trả trong endpoint self; public user DTO tuyệt đối không có field này. Các field ID/role/status/email_verified là string/string/enum/boolean tương ứng.

### 6.2. Categories

`GET /api/v1/categories` – Public; query active=true mặc định; không body.

```json
{
  "data": [
    {"id": "cat_books", "name": "Sach & giao trinh", "icon_key": "books", "sort_order": 1},
    {"id": "cat_electronics", "name": "Do dien tu & phu kien", "icon_key": "devices", "sort_order": 2}
  ],
  "meta": {}
}
```

id/name/icon_key là string; `sort_order` là int. Chỉ trả category đang active. Danh mục seed theo Phụ lục A.

### 6.3. Seller products và My Products

`GET /api/v1/users/{user_id}/products?page=1&page_size=20` – Public; chỉ trả Product public (`AVAILABLE`/`SOLD` theo chính sách public).

```json
{
  "data": [
    {"id": "prd_01JPRODUCT1", "title": "Giao trinh Giai tich 1", "price_vnd": 45000, "status": "AVAILABLE", "cover_image_url": null}
  ],
  "meta": {"page": 1, "page_size": 20, "total_items": 1}
}
```

`GET /api/v1/users/me/products?status=AVAILABLE&page=1&page_size=20` – Bearer; owner-only.

```json
{
  "data": [
    {"id": "prd_01JPRODUCT1", "title": "Giao trinh Giai tich 1", "price_vnd": 45000, "status": "AVAILABLE", "updated_at": "2026-11-27T03:30:00Z"}
  ],
  "meta": {"page": 1, "page_size": 20, "total_items": 1}
}
```

status là optional enum, page/page_size là optional int, `price_vnd` là int, `updated_at` là datetime ISO-8601. page \>= 1; `page_size` 1–50 – **[Bổ sung hợp lý / Giả định]**.

### 6.4. File delete

`DELETE /api/v1/files/{file_id}` – Bearer + owner; không body; chỉ xóa file chưa gắn Product hoặc file mà nghiệp vụ cho phép thay thế.

Response `200`:

```json
{"data": {"file_id": "fil_01JAVATAR", "deleted": true}, "meta": {}}
```

`404` `FILE_NOT_FOUND`; `401` `AUTH_REQUIRED`; `403` `FILE_FORBIDDEN`; `409` `FILE_ALREADY_ATTACHED`; `422` `VALIDATION_ERROR`.

### 6.5. Wishlist delete

`DELETE /api/v1/me/wishlist/{product_id}` – Bearer; no body.

Response `200`:

```json
{"data": {"product_id": "prd_01JPRODUCT1", "is_favorite": false}, "meta": {}}
```

Nếu đã bỏ lưu trước đó, API vẫn trả trạng thái `is_favorite`=false – **[Bổ sung hợp lý / Giả định]** nhằm giữ thao tác idempotent.

### 6.6. Conversation list và read receipt

`GET /api/v1/conversations?page=1&page_size=20` – Bearer.

```json
{
  "data": [
    {
      "id": "cnv_01JCONV1",
      "product_id": "prd_01JPRODUCT1",
      "product_title": "Giao trinh Giai tich 1",
      "other_participant": {"id": "usr_01JABC123", "display_name": "Nguyen Van A"},
      "last_message": {"text": "Minh hen 5h nhe", "created_at": "2026-11-27T04:30:00Z"},
      "unread_count": 2
    }
  ],
  "meta": {"page": 1, "page_size": 20, "total_items": 1}
}
```

`POST /api/v1/conversations/{id}/read` – Bearer + participant; no body.

```json
{"data": {"conversation_id": "cnv_01JCONV1", "unread_count": 0, "last_read_at": "2026-11-27T04:31:00Z"}, "meta": {}}
```

Field `unread_count` là int \>= 0; `last_read_at` là datetime ISO-8601. Message list dùng cursor để không tải toàn bộ lịch sử.

### 6.7. Pending reviews

`GET /api/v1/me/pending-reviews` – Bearer; no body.

```json
{
  "data": [
    {
      "confirmation_id": "txn_01JCONFIRM1",
      "product_id": "prd_01JPRODUCT1",
      "product_title": "Giao trinh Giai tich 1",
      "seller": {"id": "usr_01JABC123", "display_name": "Nguyen Van A"},
      "completed_at": "2026-11-27T05:10:00Z",
      "can_review": true
    }
  ],
  "meta": {"page": 1, "page_size": 20, "total_items": 1}
}
```

`can_review` là boolean; `completed_at` datetime ISO-8601. 

### 6.8. Report detail

`GET /api/v1/me/reports/{report_id}` – Bearer + reporter; không body.

```json
{
  "data": {
    "id": "rpt_01JREPORT1",
    "product_id": "prd_01JPRODUCT1",
    "reason": "MISLEADING",
    "description": "Anh va mo ta khong trung khop.",
    "status": "PENDING",
    "created_at": "2026-11-27T06:00:00Z",
    "resolution_note": null
  },
  "meta": {}
}
```

Không trả `reporter_id` cho target owner; endpoint người báo cáo chỉ trả thông tin thuộc report của chính họ.

### 6.9. Admin report list và detail

`GET /api/v1/admin/reports?status=PENDING&page=1&page_size=20` – Bearer + `ADMIN`; no body.

```json
{
  "data": [
    {"id": "rpt_01JREPORT1", "target_type": "PRODUCT", "target_id": "prd_01JPRODUCT1", "reason": "MISLEADING", "status": "PENDING", "created_at": "2026-11-27T06:00:00Z"}
  ],
  "meta": {"page": 1, "page_size": 20, "total_items": 1}
}
```

`GET /api/v1/admin/reports/{report_id}` – Bearer + `ADMIN`; no body.

```json
{
  "data": {
    "id": "rpt_01JREPORT1",
    "reporter": {"display_name": "Nguyen B", "joined_at": "2026-10-01T00:00:00Z"},
    "target": {"type": "PRODUCT", "id": "prd_01JPRODUCT1", "status": "AVAILABLE"},
    "snapshot": {"title": "Giao trinh Giai tich 1", "price_vnd": 45000, "cover_image_url": null},
    "reason": "MISLEADING",
    "description": "Thong tin khong trung khop.",
    "status": "PENDING"
  },
  "meta": {}
}
```

Snapshot chỉ có dữ liệu cần thiết cho moderation; không bao gồm email, địa chỉ, số điện thoại hoặc nội dung conversation.

### 6.10. Error examples

Các module tham chiếu mã lỗi trong từng bảng. Ví dụ response chuẩn:

**`400` – Business/request invalid**

```json
{
  "error": {"code": "PRODUCT_STATE_CONFLICT", "message": "Trang thai san pham khong cho phep thao tac nay.", "details": []},
  "meta": {"request_id": "req_01JREQUEST"}
}
```

**`401` – Unauthorized**

```json
{
  "error": {"code": "AUTH_REQUIRED", "message": "Vui long dang nhap lai.", "details": []},
  "meta": {"request_id": "req_01JREQUEST"}
}
```

**`404` – Not found**

```json
{
  "error": {"code": "PRODUCT_NOT_FOUND", "message": "Tin khong ton tai hoac khong kha dung.", "details": []},
  "meta": {"request_id": "req_01JREQUEST"}
}
```

**`422` – Validation error**

```json
{
  "error": {"code": "VALIDATION_ERROR", "message": "Du lieu gui len khong hop le.", "details": [{"field": "price_vnd", "issue": "must be greater than or equal to 0"}]},
  "meta": {"request_id": "req_01JREQUEST"}
}
```

details là array of object; field/issue là string. Các ví dụ error là payload chuẩn dùng xuyên module; mã cụ thể thay theo bảng lỗi ở mỗi module.
