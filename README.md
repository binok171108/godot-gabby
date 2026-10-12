# Nhà Búp Bê Cầu Vồng — Godot / Xogot iOS

Project Godot native đang phát triển, cùng model, texture, dữ liệu và cảnh bake đầy đủ. `project.godot` nằm ngay ở gốc repository.

## Import trực tiếp trong Xogot

1. Cập nhật Xogot lên **1.7.2+ (Godot 4.7)**.
2. Trong chức năng Git/Clone của Xogot, nhập **https://github.com/binok171108/godot-gabby.git** và chọn nhánh **main**.
3. Mở/import `project.godot` ở gốc repo. Chờ import tài nguyên lần đầu rồi bấm chạy `main.tscn`.
4. Joystick trái để di chuyển, kéo vùng giữa/phải để xoay camera; dùng nút CHẠY/NHẢY/CHƠI để tương tác.

Nếu dùng Download ZIP trên GitHub, giải nén trong Files rồi import thư mục chứa `project.godot`.

## Trạng thái kiểm thử

- Snapshot được kiểm Godot 4.7.2 Windows: cold import không ERROR/SCRIPT ERROR; runtime regression đạt entity load/unload, camera, map/manual cancellation và train.
- **Chưa kiểm trên iPhone/iPad thật. Lỗi import/crash Xogot được báo nhưng chưa có thông báo cụ thể để chẩn đoán, chưa khẳng định đã sửa.** Đổi cách tải sang Git không tự sửa lỗi engine/import.
- iOS sử dụng Mobile renderer; VSync bật. Không có cầu nối UDP stream, cache Windows `.godot`, save/PIN người chơi hay token.
- Tự tìm đường bản đồ còn phụ thuộc Node.js/Rust WASM trên desktop, chưa hỗ trợ iOS; map và joystick vẫn có. Không thay bằng thuật toán khác.
- Bản port chưa đủ toàn bộ gameplay R3F; streaming/LOD còn cần hoàn thiện. Xem `XOGOT_README.md`.

## Tài nguyên và Git

- Asset được lưu trực tiếp trong Git, **không dùng Git LFS pointer**, để clone/import không cần công cụ LFS riêng trên iOS. Clone đầu tiên có thể nặng và import lần đầu có thể lâu.
- `snapshot-manifest.json` ghi SHA256 của snapshot gốc. README của repo khác README snapshot; file manifest không phải chứng nhận tương thích iOS.
- Chủ project đã cho phép đưa asset của snapshot này lên repo công khai. Việc công khai không tự cấp quyền phân phối lại cho bên thứ ba.
- Nội dung fan-made học tập cá nhân, lấy cảm hứng từ Gabby's Dollhouse; không liên kết hoặc được chứng thực bởi DreamWorks.
