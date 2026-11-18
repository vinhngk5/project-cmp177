# 📋 Danh Sách Công Việc Dự Án: App Chợ Đồ Cũ Sinh Viên (C2C - Flutter)

> 💡 **Lưu ý cho cả nhóm:** Vì chúng ta đều mới bắt đầu với Dart & Flutter, hãy hoàn thành **Giai đoạn 0** trước để thống nhất cách viết code, tránh lỗi xung đột khi ghép bài.

## 📌 Quy trình tự nhận việc dành cho thành viên
1. Xem danh sách các task bên dưới và chọn task phù hợp (mục *Assignee: Trống*).
2. Vào tab **Issues** trên GitHub (hoặc sửa trực tiếp file này) điền `@username` của bạn vào task để đánh dấu đã nhận.
3. Tạo branch mới theo cú pháp: `feat/ten-task` hoặc `fix/ten-loi` để bắt đầu làm.
4. Hoàn thành đầy đủ phần **Output** yêu cầu, tạo Pull Request và đánh dấu `[x]` vào ô trống sau khi được duyệt.

---

## 🎓 Giai đoạn 0: Làm quen Dart/Flutter & Dựng khung dự án
*Mục tiêu: Cài đặt môi trường đồng bộ, nắm vững cú pháp cơ bản và tạo bộ khung dễ hiểu nhất cho người mới.*

- [ ] **[All Members]** Cài đặt môi trường & Học nhanh Dart/Flutter cơ bản - *(Assignee: Cả nhóm)*
  - `➔ Output:` Mỗi thành viên cài xong Flutter SDK, Android Studio/VS Code, chạy thành công app đếm số mặc định trên máy ảo (Emulator) và nắm được các Widget cơ bản (`Container`, `Row`, `Column`, `ListView`, `TextField`).
- [ ] **[Setup - Flutter]** Khởi tạo project Flutter & Chia cấu trúc thư mục đơn giản (Feature-based hoặc MVC) - *(Assignee: Trống)*
  - `➔ Output:` Repo GitHub có sẵn các thư mục dễ hiểu: `models/`, `screens/`, `widgets/`, `services/` (gọi API), cài sẵn thư viện cơ bản (`http` hoặc `dio`, `provider`, `image_picker`).
- [ ] **[Setup - UI Kit]** Tạo file dùng chung cho toàn App (Màu sắc, Font chữ, Nút bấm chuẩn) - *(Assignee: Trống)*
  - `➔ Output:` File `app_colors.dart`, `app_styles.dart` và widget `custom_button.dart` để cả nhóm dùng chung, giúp giao diện đồng bộ và không phải code lại nhiều lần.
- [ ] **[Setup - Backend]** Dựng khung Backend API & Database (Hoặc thiết lập Firebase nếu muốn làm nhanh) - *(Assignee: Trống)*
  - `➔ Output:` Link API chạy được trên local/cloud và file tài liệu hướng dẫn cách gọi API (Endpoint, dữ liệu gửi lên, dữ liệu trả về) cho team Flutter.

---

## 🚀 Giai đoạn 1: Thiết kế & Luồng hoạt động (Planning & Design)
*Mục tiêu: Vẽ ra hình hài ứng dụng trước khi bắt tay vào code giao diện.*

- [ ] **[Docs]** Viết tài liệu đặc tả tính năng (SRS) bản rút gọn cho MVP - *(Assignee: Trống)*
  - `➔ Output:` File `SRS.md` liệt kê rõ app có những màn hình nào, sinh viên được làm gì, Admin được làm gì.
- [ ] **[Design]** Thiết kế giao diện các màn hình chính trên Figma - *(Assignee: Trống)*
  - `➔ Output:` Link Figma đầy đủ các màn: Đăng nhập, Trang chủ, Chi tiết đồ, Đăng bán, Chat, Cá nhân (thiết kế đơn giản, dùng các thành phần chuẩn của Material Design để dễ code bằng Flutter).
- [ ] **[DB]** Thiết kế cơ sở dữ liệu (ERD) - *(Assignee: Trống)*
  - `➔ Output:` Sơ đồ các bảng dữ liệu: `Users`, `Products`, `Categories`, `Messages`, `Reviews`, `Reports`.

---

## 🛠️ Giai đoạn 2: Xây dựng tính năng cốt lõi (MVP)
*Mục tiêu: Chia nhỏ từng màn hình để mỗi thành viên tự code trọn vẹn giao diện và gắn API cho màn hình đó.*

- [ ] **[Backend]** API Đăng ký / Đăng nhập (Email/Password hoặc Google) - *(Assignee: Trống)*
  - `➔ Output:` Endpoint `/login`, `/register` hoạt động ổn định, trả về Token và thông tin sinh viên.
- [ ] **[Backend]** API Đăng bài, Sửa, Xóa & Lấy danh sách đồ cũ (Hỗ trợ upload ảnh) - *(Assignee: Trống)*
  - `➔ Output:` Các endpoint CRUD sản phẩm trả về JSON chuẩn, ảnh được lưu lên Cloudinary hoặc Firebase Storage.
- [ ] **[Flutter - Screen 1]** Màn hình Đăng nhập & Đăng ký - *(Assignee: Trống)*
  - `➔ Output:` Màn hình nhập liệu có kiểm tra lỗi (validate email/mật khẩu), gọi API đăng nhập thành công và lưu trạng thái đăng nhập bằng `shared_preferences`.
- [ ] **[Flutter - Screen 2]** Thanh điều hướng (BottomNavigationBar) & Màn hình Trang chủ - *(Assignee: Trống)*
  - `➔ Output:` Thanh menu dưới đáy chuyển qua lại 4 tab (Trang chủ, Đăng tin, Tin nhắn, Cá nhân); Trang chủ hiển thị danh sách món đồ từ API kèm thanh tìm kiếm, lọc danh mục.
- [ ] **[Flutter - Screen 3]** Màn hình Chi tiết sản phẩm - *(Assignee: Trống)*
  - `➔ Output:` Hiển thị hình ảnh món đồ (lướt ngang được), giá tiền, mô tả, tình trạng mới/cũ, thông tin người bán và nút **"Nhắn tin trả giá"**.
- [ ] **[Flutter - Screen 4]** Màn hình Đăng tin thanh lý đồ cũ - *(Assignee: Trống)*
  - `➔ Output:` Dùng package `image_picker` cho phép chọn ảnh từ thư viện/chụp ảnh, nhập tên đồ, giá, chọn danh mục và bấm đăng lên server thành công.
- [ ] **[Flutter - Screen 5]** Màn hình Hồ sơ cá nhân & Quản lý tin đã đăng - *(Assignee: Trống)*
  - `➔ Output:` Hiển thị thông tin sinh viên, danh sách đồ mình đang đăng bán (có nút Xóa hoặc đổi trạng thái thành **"Đã bán"**) và nút Đăng xuất.

---

## 💬 Giai đoạn 3: Tương tác & Giao dịch C2C
*Mục tiêu: Hoàn thiện tính năng nhắn tin trao đổi và đánh giá uy tín.*

- [ ] **[Fullstack]** Tính năng Chat giữa người mua và người bán (Khuyên dùng Firebase Firestore cho người mới vì rất dễ tích hợp với Flutter) - *(Assignee: Trống)*
  - `➔ Output:` Màn hình danh sách cuộc trò chuyện và màn hình nhắn tin real-time, kèm các nút bấm gợi ý nhanh (*"Đồ này còn không bạn?"*, *"Bớt chút được không?"*).
- [ ] **[Fullstack]** Tính năng Lưu tin yêu thích (Wishlist) - *(Assignee: Trống)*
  - `➔ Output:` Bấm icon trái tim trên món đồ để lưu lại và xem được danh sách đồ đã lưu trong trang Cá nhân.
- [ ] **[Fullstack]** Tính năng Đánh giá uy tín (Rating 1-5 sao) sau khi mua - *(Assignee: Trống)*
  - `➔ Output:` Hộp thoại (Dialog) cho phép chấm sao + viết nhận xét người bán sau khi món đồ chuyển trạng thái đã bán.

---

## 🛡️ Giai đoạn 4: An toàn & Hoàn thiện (Admin & Testing)
*Mục tiêu: Xử lý báo cáo vi phạm, sửa lỗi giao diện và đóng gói file cài đặt.*

- [ ] **[Fullstack]** Tính năng Báo cáo (Report) bài đăng lừa đảo/vi phạm - *(Assignee: Trống)*
  - `➔ Output:` Nút "Báo cáo" trong màn hình chi tiết món đồ, gửi lý do vi phạm về hệ thống.
- [ ] **[Admin]** Trang/Màn hình quản lý dành cho Admin - *(Assignee: Trống)*
  - `➔ Output:` Giao diện (Web hoặc màn hình ẩn trên App) giúp Admin xem danh sách bài bị báo cáo và bấm nút Xóa bài/Khóa tài khoản vi phạm.
- [ ] **[QA & Fix]** Chạy thử chéo (Cross-testing) & Sửa lỗi tràn màn hình - *(Assignee: Cả nhóm)*
  - `➔ Output:` Các thành viên cài app của nhau lên điện thoại thật, kiểm tra và sửa hết các lỗi vạch vàng/đen tràn màn hình (`RenderFlex overflow`) của Flutter.
- [ ] **[Build]** Đóng gói file cài đặt `.apk` cho Android - *(Assignee: Trống)*
  - `➔ Output:` Chạy lệnh `flutter build apk --release` thành công và tải file `app-release.apk` lên mục **Releases** của GitHub để nộp bài/demo.
