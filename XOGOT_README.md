# Nhà Búp Bê Cầu Vồng — gói thử Xogot iOS

## Cài trên iPhone/iPad

1. Cập nhật Xogot lên 1.7.2 hoặc mới hơn (Godot 4.7).
2. Tải ZIP nhánh main mới nhất từ https://github.com/binok171108/godot-gabby (Code → Download ZIP). Không dùng ZIP Release cũ chứa bridge parse lỗi. Nếu muốn Pull trên iOS, dùng Working Copy và liên kết thư mục với Xogot.
3. Trong ứng dụng Files, chạm ZIP để giải nén. Giữ nguyên toàn bộ thư mục `GabbyHouse-Xogot`.
4. Trong Project Manager của Xogot, import thư mục chứa `project.godot`.
5. Chờ import model/texture lần đầu, sau đó bấm chạy project (`main.tscn`).
6. Chọn profile. Joystick trái để đi; kéo vùng giữa/phải để xoay camera; nút CHẠY/NHẢY/CHƠI để tương tác.

## Nội dung gói

- Snapshot Godot hiện tại cùng toàn bộ model, texture, dữ liệu và cảnh đã bake; không phải bản HTML5 hay video stream.
- Không chứa `.godot` cache Windows, export Web, video cá nhân, save/PIN người chơi hay token stream.
- Giữ `.import` để bảo toàn thiết lập model/animation; Xogot tự tạo cache phù hợp thiết bị.
- Bổ sung bản sao atlas cây đúng tên URI trong GLB, lấy nguyên ảnh hiện có; không tạo texture thay thế.
- Chỉ bản đóng gói được chỉnh renderer iOS sang Mobile (native), bật VSync và bỏ Autoload cầu nối UDP stream. Bản Safari và thư mục Godot nguồn không thay đổi.
- `package-manifest.json` và `SHA256SUMS.txt` ghi danh mục/checksum để kiểm tra tải.

## Giới hạn phải biết

- Chưa chạy thử trên iPhone/iPad thật. Kiểm import/runtime Windows không chứng minh hiệu năng Metal hay tương thích shader iOS.
- Bản repo đã loại script/scene bridge stream gây lỗi parse `background_runner.gd` do không còn `StreamInput` Autoload. Pull rồi mở lại project, chờ import xong trước khi chơi; nếu Cốm chưa import được, Reimport `assets/ai/com-kit.glb` và gửi log đầu tiên. Không coi lỗi model null đã được xác minh hết trên iOS.
- Bản port hiện tại chưa đủ toàn bộ gameplay R3F; các lỗi streaming/LOD hiện có không tự hết khi chuyển native.
- Chức năng tự đi theo mục tiêu bản đồ đang phụ thuộc Node.js + lõi Rust WASM trên desktop. iOS không chạy được Node.js: gói này báo chưa hỗ trợ, không thay bằng thuật toán khác. Bản đồ và điều khiển joystick vẫn được giữ.
- Import tài nguyên lần đầu có thể lâu và cần dung lượng trống; không phải mỗi lần chơi tải lại qua Safari.
- Repo snapshot công khai được chủ project cho phép; không tự coi là quyền phân phối lại asset hoặc ứng dụng đã phát hành App Store.

## Texture mobile ngày 2026-10-13

- 3D giới hạn 512px, gồm ảnh ngoài và ảnh nhúng GLB; map UI tối đa 1024px. Giữ nguyên mesh/UV/animation/reference.
- VRAM Compressed cho 3D, High Quality tắt để tránh ASTC/BPTC encoder nặng; giữ mipmap 3D. UI lossless/no mipmap. Giảm độ phân giải nguồn trước import mới giảm peak decode; WebP chỉ giảm dung lượng file nếu giữ cùng số pixel.
- Cold import Windows không ERROR; profile allocator ~52.6 MiB/world ~169.3 MiB, cold cache ~114 MiB. Chưa đo trên iPhone; cần import ZIP mới và kiểm thực tế low memory.
