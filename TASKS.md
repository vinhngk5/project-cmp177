# 📋 Danh Sách Công Việc Dự Án: App Chợ Đồ Cũ Sinh Viên (C2C - Flutter)

> **Cách chia nhóm:** Dùng TV1–TV4 làm mã thành viên tạm thời. Thay bằng `@username` GitHub của từng người trước khi bắt đầu. Mỗi task có **một người chịu trách nhiệm chính**; người hỗ trợ phối hợp nhưng không tạo hai phiên bản code độc lập.
>
> **Nguyên tắc:** Chia theo mảng nghiệp vụ để giảm xung đột: TV1 phụ trách backend/nền tảng; TV2 phụ trách trải nghiệm người mua; TV3 phụ trách người bán/đăng tin; TV4 phụ trách tương tác/an toàn. Cả nhóm cùng thống nhất hợp đồng API và cùng kiểm thử.

## 1. Vai trò 4 thành viên

| Thành viên | Vai trò chính | Phạm vi sở hữu |
|---|---|---|
| **TV1** | Backend & tích hợp | Backend setup, ERD, API đăng nhập, phân quyền, API dùng chung, tích hợp và phát hành bản build |
| **TV2** | Buyer experience | Flutter foundation/UI kit, đăng nhập, trang chủ, tìm kiếm/lọc, chi tiết sản phẩm, wishlist |
| **TV3** | Seller experience | Đăng/sửa/xóa tin, upload ảnh, hồ sơ người bán, quản lý tin, đánh giá sau giao dịch, chia sẻ tin |
| **TV4** | Communication & Safety | Chat, báo cáo vi phạm, quy trình kiểm duyệt và giao diện Admin |

> **Phân chia backend theo miền:** TV1 dựng nền tảng, xác thực và quy tắc phân quyền. TV2 phối hợp TV1 cho API đọc/tìm kiếm sản phẩm và wishlist; TV3 phụ trách luồng ghi sản phẩm/upload ảnh; TV4 phụ trách chat và giao diện báo cáo. Với API quản trị, TV1 chịu trách nhiệm kiểm tra quyền ở server, TV4 làm giao diện và luồng xử lý.

## 2. Quy trình làm việc chung

1. Mọi người hoàn thành phần cài đặt môi trường ở Giai đoạn 0.
2. Trước khi code một tính năng, người phụ trách ghi rõ màn hình, API, request/response, trạng thái loading/error/empty và tiêu chí hoàn thành.
3. Tạo branch theo mẫu `feat/<ten-task>` hoặc `fix/<ten-loi>`. Không commit trực tiếp lên `main`.
4. Mỗi Pull Request phải có ảnh/video chạy thử, mô tả cách kiểm thử và người review. TV1 review thay đổi backend/API; TV2/TV3/TV4 review chéo phần Flutter theo mảng liên quan.
5. Chỉ đánh dấu `[x]` sau khi PR được merge và kiểm thử tích hợp thành công.

---

## 🎓 Giai đoạn 0: Làm quen Dart/Flutter & Dựng khung dự án
*Mục tiêu: Cài đặt môi trường đồng bộ, nắm cú pháp cơ bản và có bộ khung thống nhất.*

- [ ] **[All Members]** Cài đặt môi trường & học nhanh Dart/Flutter cơ bản — *(Assignee: Cả nhóm)*
  - `➔ Output:` Mỗi thành viên cài Flutter SDK, Android Studio/VS Code, chạy được app mẫu trên Emulator và nắm các Widget cơ bản (`Container`, `Row`, `Column`, `ListView`, `TextField`).
- [ ] **[Setup - Flutter]** Khởi tạo project Flutter & cấu trúc thư mục — *(Assignee: TV2; TV3 review)*
  - `➔ Output:` Repo có cấu trúc thống nhất (ưu tiên feature-based), quy ước đặt tên, routing và quản lý state; cài các package đã thống nhất như `dio`/`http`, `provider` và `image_picker`.
- [ ] **[Setup - UI Kit]** Tạo thành phần giao diện dùng chung — *(Assignee: TV2; TV3 review)*
  - `➔ Output:` `app_colors.dart`, `app_styles.dart`, `custom_button.dart`, các ô nhập liệu/loading/error dùng chung. Các màn hình không tự tạo màu và nút riêng nếu đã có component chung.
- [ ] **[Setup - Backend]** Dựng khung Backend API & Database hoặc Firebase — *(Assignee: TV1)*
  - `➔ Output:` Backend chạy được trên môi trường phát triển; có cấu hình môi trường mẫu, kết nối database/Firebase và tài liệu API ban đầu. Không commit secret/API key thật lên Git.

**Mốc hoàn thành Giai đoạn 0:** Cả bốn thành viên pull được project, chạy cùng một phiên bản và tạo được branch/PR mẫu.

---

## 🚀 Giai đoạn 1: Thiết kế & Luồng hoạt động (Planning & Design)
*Mục tiêu: Chốt phạm vi MVP, luồng nghiệp vụ, giao diện và cấu trúc dữ liệu trước khi triển khai.*

- [ ] **[Docs]** Viết SRS rút gọn cho MVP — *(Assignee: TV4; cả nhóm duyệt)*
  - `➔ Output:` `SRS.md` ghi rõ vai trò Sinh viên/Người bán/Người mua/Admin, chức năng, luồng chính, trường hợp lỗi và những gì nằm ngoài phạm vi MVP.
- [ ] **[Design]** Thiết kế giao diện trên Figma — *(Assignee: TV2: đăng nhập/trang chủ/chi tiết; TV3: đăng bán/hồ sơ; TV4: chat/báo cáo/Admin; TV1: góp ý tính khả thi)*
  - `➔ Output:` Link Figma có đầy đủ màn hình đã phân công, dùng chung màu sắc, typography, component và trạng thái loading/empty/error.
- [ ] **[DB]** Thiết kế cơ sở dữ liệu (ERD) — *(Assignee: TV1; TV2–TV4 review theo chức năng)*
  - `➔ Output:` ERD tối thiểu gồm `Users`, `Products`, `Categories`, `ProductImages`, `Conversations`, `Messages`, `Wishlists`, `Reviews`, `Reports`. Chỉ thêm `Orders`, `OrderItems`, `OrderAddresses` nếu nhóm quyết định có luồng đặt hàng trong app.
- [ ] **[API Contract]** Thống nhất endpoint và JSON — *(Assignee: TV1; TV2–TV4 cung cấp nhu cầu dữ liệu)*
  - `➔ Output:` Tài liệu `API.md` mô tả endpoint, quyền truy cập, request/response, mã lỗi và quy ước phân trang. TV2–TV4 không tự giả định cấu trúc JSON khác tài liệu.

**Mốc hoàn thành Giai đoạn 1:** Chốt SRS, Figma, ERD và API contract. Thay đổi schema/API sau mốc này phải được trao đổi trong nhóm trước khi code.

---

## 🛠️ Giai đoạn 2: Xây dựng tính năng cốt lõi (MVP)
*Mục tiêu: Hoàn tất đăng nhập, khám phá sản phẩm và đăng bán. Mỗi tính năng phải chạy được từ giao diện đến dữ liệu.*

- [ ] **[Backend - Auth]** API đăng ký/đăng nhập — *(Assignee: TV1; TV2 tích hợp Flutter)*
  - `➔ Output:` Endpoint đăng ký/đăng nhập hoạt động, validate dữ liệu, trả token/thông tin người dùng; có xử lý token hết hạn và endpoint lấy hồ sơ hiện tại.
- [ ] **[Backend - Product Read]** API danh sách/chi tiết/tìm kiếm/lọc sản phẩm — *(Assignee: TV1; TV2 tích hợp và phản hồi thiếu dữ liệu)*
  - `➔ Output:` API trả danh sách và chi tiết sản phẩm, hỗ trợ từ khóa/danh mục/phân trang; chỉ trả trường công khai, không trả địa chỉ riêng hoặc dữ liệu nhạy cảm của người bán.
- [ ] **[Backend - Product Write]** API tạo/sửa/xóa tin và upload ảnh — *(Assignee: TV3; TV1 hỗ trợ cấu hình storage và review quyền truy cập)*
  - `➔ Output:` Chỉ chủ sở hữu mới được sửa/xóa tin của mình; ảnh được lưu trên Cloudinary/Firebase Storage; kiểm tra loại và dung lượng file.
- [ ] **[Flutter - Screen 1]** Màn hình đăng nhập/đăng ký — *(Assignee: TV2; TV1 hỗ trợ tích hợp API)*
  - `➔ Output:` Có validate email/mật khẩu, trạng thái loading/error, gọi API và lưu phiên đăng nhập an toàn theo phương án nhóm thống nhất.
- [ ] **[Flutter - Screen 2]** BottomNavigationBar & trang chủ — *(Assignee: TV2)*
  - `➔ Output:` Bốn tab (Trang chủ, Đăng tin, Tin nhắn, Cá nhân); trang chủ hiển thị dữ liệu API, tìm kiếm và lọc danh mục.
- [ ] **[Flutter - Screen 3]** Chi tiết sản phẩm — *(Assignee: TV2; TV3 cung cấp quy tắc hiển thị dữ liệu tin đăng)*
  - `➔ Output:` Hiển thị ảnh, giá, mô tả, tình trạng, khu vực công khai và thông tin người bán; có nút nhắn tin, yêu thích và chia sẻ. Không hiển thị địa chỉ nhà/số điện thoại riêng nếu người bán chưa chủ động công khai.
- [ ] **[Flutter - Screen 4]** Đăng tin thanh lý đồ cũ — *(Assignee: TV3)*
  - `➔ Output:` Chọn/chụp ảnh bằng `image_picker`, nhập tên/giá/mô tả/danh mục/tình trạng/khu vực hiển thị; validate và đăng thành công lên server.
- [ ] **[Flutter - Screen 5]** Hồ sơ cá nhân & quản lý tin đã đăng — *(Assignee: TV3; TV2 review UI consistency)*
  - `➔ Output:` Hiển thị hồ sơ, danh sách tin của chính người dùng, sửa/xóa/ẩn hoặc đánh dấu đã bán; có đăng xuất.

---

## 💬 Giai đoạn 3: Tương tác & Giao dịch C2C
*Mục tiêu: Hoàn thiện trao đổi, lưu tin và đánh giá. Mọi dữ liệu phải gắn đúng người dùng và sản phẩm.*

- [ ] **[Fullstack - Chat]** Chat giữa người mua và người bán — *(Assignee: TV4; TV1 hỗ trợ xác thực/quy tắc truy cập)*
  - `➔ Output:` Danh sách hội thoại và nhắn tin real-time; mỗi hội thoại gắn với `buyer_id`, `seller_id`, `product_id`; chỉ thành viên hội thoại được đọc/gửi tin. Có gợi ý tin nhắn nhanh.
- [ ] **[Fullstack - Wishlist]** Lưu tin yêu thích — *(Assignee: TV2; TV1 hỗ trợ schema/API nếu cần)*
  - `➔ Output:` Bấm biểu tượng trái tim để thêm/bỏ yêu thích; danh sách yêu thích theo tài khoản; không lưu trùng một sản phẩm cho cùng người dùng.
- [ ] **[Fullstack - Review]** Đánh giá uy tín người bán — *(Assignee: TV3; TV1 review quy tắc dữ liệu)*
  - `➔ Output:` Chấm 1–5 sao và nhận xét; mỗi người dùng không thể gửi nhiều đánh giá trùng cho cùng một giao dịch. Nếu MVP chưa có đơn hàng trong app, phải ghi rõ đánh giá dựa trên xác nhận nào; không gọi đó là “giao dịch đã xác minh” chỉ dựa vào việc người bán tự chuyển tin sang `SOLD`.
- [ ] **[Share]** Chia sẻ liên kết sản phẩm — *(Assignee: TV3; TV2 tích hợp tại màn chi tiết)*
  - `➔ Output:` Chia sẻ link sản phẩm qua bảng chia sẻ của hệ điều hành; link mở được trang sản phẩm trên web/app nếu nhóm triển khai; xử lý tin đã ẩn/đã bán. Không nhúng địa chỉ riêng vào URL hoặc metadata chia sẻ.

---

## 🛡️ Giai đoạn 4: An toàn & Hoàn thiện (Admin & Testing)
*Mục tiêu: Có quy trình báo cáo/kiểm duyệt, kiểm thử chéo và đóng gói bản cài đặt.*

- [ ] **[Fullstack - Report]** Báo cáo tin đăng vi phạm — *(Assignee: TV4; TV1 hỗ trợ API và kiểm soát quyền)*
  - `➔ Output:` Người dùng gửi báo cáo kèm lý do; backend lưu người báo cáo, tin bị báo cáo, thời điểm và trạng thái xử lý; tránh cho người dùng xem báo cáo của người khác.
- [ ] **[Admin]** Màn hình quản lý dành cho Admin — *(Assignee: TV4 phần giao diện; TV1 phần API/role authorization)*
  - `➔ Output:` Admin xem danh sách báo cáo, xem ngữ cảnh cần thiết, ẩn/xóa tin hoặc khóa tài khoản theo quyền. Backend phải kiểm tra role Admin; không chỉ ẩn nút trên giao diện.
- [ ] **[Privacy]** Kiểm tra quyền riêng tư dữ liệu người bán — *(Assignee: TV1; TV3 kiểm tra luồng đăng tin)*
  - `➔ Output:` API công khai chỉ trả khu vực tổng quát; địa chỉ chính xác (nếu có thu thập) lưu tách biệt và chỉ cấp cho người/đơn vị thực sự cần theo luồng nghiệp vụ. Không đưa địa chỉ chính xác vào log, URL hoặc dữ liệu chia sẻ. Nếu MVP không hỗ trợ giao hàng thì không cần thu thập địa chỉ nhà.
- [ ] **[QA & Fix]** Kiểm thử chéo — *(Assignee: Cả nhóm; mỗi người chịu trách nhiệm sửa lỗi thuộc module mình)*
  - `➔ Output:` TV1 kiểm thử API, quyền truy cập và database; TV2 kiểm thử đăng nhập/trang chủ/chi tiết/wishlist; TV3 kiểm thử đăng bán/upload/hồ sơ/chia sẻ/đánh giá; TV4 kiểm thử chat/report/Admin. Cả nhóm chạy trên thiết bị thật và sửa lỗi giao diện, đặc biệt `RenderFlex overflow`.
- [ ] **[Build]** Đóng gói APK Android — *(Assignee: TV1; TV2 hỗ trợ kiểm tra giao diện trên bản release)*
  - `➔ Output:` Build `flutter build apk --release`, kiểm tra cài đặt và các luồng chính trên APK; đưa file phát hành lên GitHub Releases.

---

## 3. Các điểm nhóm cần chốt trước khi triển khai

1. **Mô hình giao dịch MVP:** Tasks hiện tại thiên về mô hình rao vặt C2C: người mua xem tin, chat/thương lượng, người bán tự đánh dấu `SOLD`. Chưa có checkout, đơn hàng, thanh toán hoặc vận chuyển tích hợp. Nếu muốn người mua đặt hàng trong app, cần bổ sung module `Orders/OrderItems`, địa chỉ giao nhận, trạng thái đơn, hủy đơn và phương thức thanh toán; không nên xem nút `SOLD` là bằng chứng giao dịch hoàn tất.
2. **Địa chỉ:** Nếu chỉ hiển thị khu vực và hai bên tự liên hệ, không cần thu thập địa chỉ nhà chính xác. Nếu có giao hàng, phải tách địa chỉ công khai khỏi địa chỉ giao nhận, kiểm soát quyền ở backend và chỉ chia sẻ dữ liệu cần thiết.
3. **Đánh giá:** Chỉ nên gắn nhãn “đánh giá giao dịch đã xác minh” khi hệ thống có bằng chứng giao dịch đủ tin cậy. Với MVP hiện tại, có thể dùng đánh giá sau khi hai bên xác nhận, nhưng phải mô tả đúng mức độ xác minh.
4. **Công nghệ chat:** Nếu dùng Firestore, TV1 và TV4 phải thống nhất Firebase Authentication/UID và Firestore Security Rules trước khi làm UI chat. Không dựa vào việc ẩn màn hình để bảo vệ dữ liệu.

## 4. Quy tắc phối hợp để tránh xung đột Git

- Mỗi task chỉ có một **Assignee chính**; người hỗ trợ được ghi ở phần review/support.
- TV1 công bố API contract và dữ liệu mẫu trước khi TV2–TV4 tích hợp.
- TV2 sở hữu component dùng chung và điều hướng; các thành viên khác tái sử dụng, không tự tạo bản sao.
- Không sửa trực tiếp file của module khác nếu chưa trao đổi. Tạo issue/PR hoặc yêu cầu người phụ trách hỗ trợ.
- Mỗi PR nên nhỏ, chỉ giải quyết một task; merge thường xuyên để tránh dồn xung đột cuối kỳ.
