# Texture Thế giới hoạt hình (cartoon world)

`grass.webp`: texture cỏ được tạo mới bằng imagegen trong phiên Codex ngày 2026-10-06, prompt mặt cỏ nhìn từ trên xuống, cỏ/clover màu sage và olive, không chữ/đồ vật/ánh sáng định hướng. Nguồn PNG nằm ngoài repo trong thư mục generated_images của Codex; FFmpeg chuyển xuống WebP 1024×1024, quality82 để tải trên điện thoại. Không lấy từ phim, game hoặc ảnh bản đồ Boss gửi.

Vật liệu asphalt, gạch vỉa hè, mái ngói, tường, vỏ cây và lá được tạo bằng canvas trong `src/worlds/dreamEnvironment.js`; hình học môi trường do code dựng, seed cố định. Texture cỏ chỉ tải khi vào Thế giới hoạt hình.

## Texture CC0 từ Poly Haven (thêm 2026-10-07, Claude Code)

Tải bản Diffuse 1k JPG từ https://polyhaven.com (giấy phép CC0, tác giả Rob Tuytel và cộng sự), thu về 512×512 WebP q80 bằng Pillow, chỉnh độ sáng trung bình để nhân với màu tint trong game (`src/worlds/dreamModels.js` gắn texture theo tên vật liệu, `dreamEnvironment.js` dùng cho đường/vỉa hè/mái/tường):

| File | Nguồn Poly Haven | Xử lý |
| --- | --- | --- |
| `asphalt.webp` | `asphalt_02` | sáng trung bình 0,52 |
| `paving.webp` | `rectangular_paving` | sáng trung bình 0,72 |
| `roof-tiles.webp` | `clay_roof_tiles` | xám hoá (giữ hoa văn, màu lấy từ tint mái), sáng 0,74 |
| `plaster.webp` | `plastered_wall` | sáng 0,86 |
| `bark.webp` | `bark_brown_02` | sáng 0,5 |
| `concrete.webp` | `concrete_floor_02` | xám hoá, sáng 0,72 |

Không dùng normal/roughness map (điện thoại bỏ các map này — `src/textureBudget.js`).

## Mặt đất nhiều lớp (thêm 2026-10-08, Claude Code)

Hai texture CC0 Poly Haven (Diffuse 1k JPG → 512×512 WebP q80 bằng FFmpeg lanczos, giữ màu gốc; tint nhân trong `src/worlds/worldGround.js`), trộn với thảm cỏ theo độ dốc + nhiễu trên `textured-meadow`:

| File | Nguồn Poly Haven | Dùng cho |
| --- | --- | --- |
| `dirt.webp` | `brown_mud_dry` | vệt đất, bờ kênh (bùn) |
| `rock.webp` | `aerial_rocks_02` (đá có rêu; đã thử `rocks_ground_05` nhưng sỏi trắng lặp ô thấy rõ trên sườn dài) | sườn dốc (đồi bắc, mô đất) |
