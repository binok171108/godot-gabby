# Nhà Búp Bê Cầu Vồng — Godot / Xogot iOS

Project Godot native đang phát triển, cùng model, texture, dữ liệu và cảnh bake đầy đủ. `project.godot` nằm ngay ở gốc repository.

## Import trực tiếp trong Xogot

1. Cập nhật Xogot lên **1.7.2+ (Godot 4.7)**.
2. Trong chức năng Git/Clone của Xogot, nhập **https://github.com/binok171108/godot-gabby.git** và chọn nhánh **main**.
3. Mở/import `project.godot` ở gốc repo. Chờ import tài nguyên lần đầu rồi bấm chạy `main.tscn`.
4. Joystick trái để di chuyển, kéo vùng giữa/phải để xoay camera; dùng nút CHẠY/NHẢY/CHƠI để tương tác.

Nếu dùng Download ZIP trên GitHub, giải nén trong Files rồi import thư mục chứa `project.godot`.

## Trạng thái kiểm thử

- Chunking mới: chỉ nạp phần cảnh có bounds nằm trong vùng quan tâm, không nạp trọn tất cả phần của cell 60 m. Index 1.194 phần cảnh giữ nguyên model/mesh; không cắt bỏ nội dung nguồn.
- Một policy chung cho static scene, nền, NPC, cây/cỏ và phương tiện: chi tiết 24 m, hoạt động 48 m, nạp trước 64 m, giữ tối đa 80 m; dự đoán hướng đi 2 giây. Đây là khoảng cách tới bounds, không phải khoảng cách tới tâm mesh.
- Khi đi xa gỡ node/collider/registry thật; cây tải template theo loại cần dùng rồi giải phóng loại hết vùng. Prefetch standby tối đa một cell; instantiate cảnh chia frame trên native nữa, không chỉ Web.
- QA Windows đi qua nhiều vùng → ra ngoài world → quay lại: allocator ~224.2 → ~224.9 MiB, vùng trống ~117.4 MiB; không phải tổng RAM/GPU iPhone. Import thật trên iOS vẫn cần kiểm. Asset thư viện mô phỏng xe/tàu và model người chơi còn dùng chung; không tuyên bố mọi byte RAM được giải phóng khi unload.

- Bản sửa bộ nhớ: không dựng world trước chọn profile; chỉ dựng khi chọn người chơi. Đo allocator Godot headless Windows: màn profile ~390 → ~76.3 MiB sau sửa khởi động/nén texture. QA chủ động vào world đo ~248.9 MiB, sáu hệ thống world vẫn hoạt động. Đây không phải tổng RAM/GPU trên iPhone và chưa chứng minh cảnh báo low memory đã hết.
- 217 texture 3D chuyển từ Lossless sang VRAM Compressed, High Quality; giữ nguyên kích thước ảnh/mipmap, 2 mask giữ lossless để bảo toàn dữ liệu. Mobile renderer có thể import ASTC; desktop có cấu hình S3TC/BPTC để kiểm thử. Pull lần này phải chờ reimport texture hoàn tất.

- Snapshot được kiểm Godot 4.7.2 Windows: cold import không ERROR/SCRIPT ERROR; runtime regression đạt entity load/unload, camera, map/manual cancellation và train.
- **Sửa lỗi parse từ ảnh Xogot:** `background_runner.gd` vẫn gọi `StreamInput` sau khi bỏ Autoload cầu nối stream. Đã tái hiện lỗi `gdscript_resource_format.cpp:46` trên Windows rồi loại toàn bộ script/scene cầu nối stream không dùng khỏi repo này. Chưa kiểm lại trên iPhone/iPad thật.
- Sau khi Pull bản sửa, dừng game và đóng/mở lại project, chờ import tài nguyên hoàn tất. Nếu model Cốm vẫn trả về null, chọn `assets/ai/com-kit.glb` trong FileSystem và Reimport; gửi thêm log import đầu tiên nếu thất bại. Chưa chứng minh model null trên iOS cùng nguyên nhân với lỗi parse; không dùng model thay thế.
- iOS sử dụng Mobile renderer; VSync bật. Không có cầu nối UDP stream, cache Windows `.godot`, save/PIN người chơi hay token.
- Tự tìm đường bản đồ còn phụ thuộc Node.js/Rust WASM trên desktop, chưa hỗ trợ iOS; map và joystick vẫn có. Không thay bằng thuật toán khác.
- Bản port chưa đủ toàn bộ gameplay R3F; streaming/LOD còn cần hoàn thiện. Xem `XOGOT_README.md`.

## Tài nguyên và Git

- Gói runtime gọn: loại GLB nguồn đầy đủ/legacy Babylon và GLB cell dùng để bake; game dùng scene chunk đã chuẩn bị, giữ nguyên toàn bộ geometry/collider/nội dung. Không dùng project này để chạy lại `bake_cells.gd`; nguồn authoring được giữ riêng trên máy phát triển.
- Scene `.scn` nén lossless bằng ResourceSaver chuẩn Godot: tổng 1.897 file ~258.7 → ~113.8 MiB, kiểm hash geometry/collider trước và sau giống hệt. Không giảm tam giác/độ phân giải.
- Dung lượng ổ đĩa trước đây ~641 MiB asset + ~548 MiB cache import = gần 1.2 GiB, không phải RAM. Sau loại source dư và nén scene, asset ~260 MiB; cache trống import Windows đo ~309 MiB (iOS có thể khác). `.godot` không nằm trong repo/ZIP và do editor tạo lại.
- Git giữ lịch sử blob cũ: Pull không làm nhỏ ngay history `.git` hoặc cache import cũ. Để thử gói gọn từ đầu, tải **Code → Download ZIP**, giải nén vào thư mục mới rồi import. Giữ bản cũ/save đến khi xác nhận bản mới chạy.

- Asset được lưu trực tiếp trong Git, **không dùng Git LFS pointer**, để clone/import không cần công cụ LFS riêng trên iOS. Clone đầu tiên có thể nặng và import lần đầu có thể lâu.
- `snapshot-manifest.json` ghi SHA256 của snapshot gốc. README của repo khác README snapshot; file manifest không phải chứng nhận tương thích iOS.
- Chủ project đã cho phép đưa asset của snapshot này lên repo công khai. Việc công khai không tự cấp quyền phân phối lại cho bên thứ ba.
- Nội dung fan-made học tập cá nhân, lấy cảm hứng từ Gabby's Dollhouse; không liên kết hoặc được chứng thực bởi DreamWorks.
