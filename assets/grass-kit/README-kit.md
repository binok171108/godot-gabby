# Grass & Flower Kit – cỏ, hoa thấp, cây phủ đất cho web game (React Three Fiber / three.js)

Bộ asset **stylized painterly** tối ưu cho thời gian thực / mobile, tạo hoàn toàn bằng script Blender Python (Blender 5.2, `bpy`).
Chỉ có cỏ, hoa thấp, cây phủ đất và texture nền – không có nhà, cây lớn, hàng rào hay môi trường.

> **Lưu ý về ảnh tham chiếu:** yêu cầu có nhắc “các ảnh đính kèm”, nhưng phiên làm việc này **không nhận được ảnh nào**.
> Hình dáng và màu được dựng theo mô tả bằng chữ (xanh non / xanh vàng / xanh trung tính, lá vàng nhạt chọn lọc, hoa nhỏ hồng – tím nhạt – trắng).
> Khi có ảnh, chỉ cần chỉnh bảng màu trong `scripts/atlas.py` (`BLADE_COLORS`, `PINK/LILAC/WHITE`) và tham số trong `scripts/grasskit_lib.py` rồi chạy lại `run_all.py`.

## 1. Có gì trong thư mục

| Thư mục / file | Nội dung |
|---|---|
| `grass_flower_kit.blend` | File chính. Collection: **Grass, Flowers, GroundCover, Lawn, LODs (LOD1, LOD2), PreviewPatches**. Mọi asset được đánh dấu trong **Asset Browser** (tag theo họ + LOD; các patch là asset dạng collection). Ảnh atlas / texture nền đã pack sẵn trong file. |
| `glb/GrassFlowerKit_All.glb` | **File dùng cho app**: 28 cụm × 3 LOD, 1 material, 1 atlas. Node `Tên_LOD0/1/2`. Translation node chỉ là bố cục trưng bày (LOD cạnh nhau). |
| `glb/clumps/<Asset>.glb` | Mỗi cụm một file, 3 LOD cùng đặt tại gốc toạ độ (cùng origin, kích thước, vị trí chân). |
| `glb/LawnGroundTiles.glb` | 4 tile nền (1,5 m) có texture. |
| `textures/GrassFlower_Atlas.png` | Atlas RGBA 1024² dùng chung. `atlas_layout.json` = toạ độ từng ô. |
| `textures/Ground_*.jpg` | 4 texture nền seamless nhìn từ trên xuống (cắt ngắn / tự nhiên / thưa + đất / đất dưới hoa). |
| `patches/PreviewPatches.json` | Dữ liệu vị trí 7 patch mẫu để dựng lại bằng instancing (toạ độ three.js). |
| `r3f/` | `grassKit.js` (lõi three.js), `GrassField.jsx` (R3F), xem `docs/R3F_GUIDE.md`. |
| `renders/` | Ảnh render (xem mục 6). |
| `docs/` | `STATS.md` (triangle / vertex / material slot / texture), `asset_metadata.json`, `lawn_systems.json`, `R3F_GUIDE.md`, `ALPHA_CUTOFF_REPORT.md`, `THREEJS_CHECK.md`. |
| `scripts/` | Toàn bộ script Python (code + comment tiếng Anh). `run_all.py` dựng lại mọi thứ. |

## 2. Danh sách asset (28 cụm × LOD0/1/2)

| Nhóm | Tên | Số biến thể | Cao (LOD0) |
|---|---|---:|---|
| Cỏ thấp | `GrassLow_A–D` | 4 | 9 – 16 cm |
| Cỏ cao | `GrassTall_A–D` | 4 | 40 – 60 cm |
| Cỏ thưa | `GrassSparse_A–C` | 3 | 10 – 24 cm |
| Cỏ xanh vàng | `GrassYellow_A–C` | 3 | 20 – 27 cm |
| Cỏ ven đường (nghiêng, không đều) | `GrassRoadside_A–C` | 3 | 22 – 27 cm |
| Hoa hồng | `FlowerPink_A–C` | 3 | 34 – 42 cm |
| Hoa tím nhạt | `FlowerLilac_A–C` | 3 | 43 – 65 cm |
| Hoa trắng | `FlowerWhite_A–B` | 2 | 33 – 38 cm |
| Cây phủ đất | `GroundCover_A–C` | 3 | 10 – 11 cm |

Các biến thể khác nhau về **hình dáng, độ cong, hướng lá và phân bố trong cụm** (số lá, bán kính, nhóm con, độ nghiêng, hướng nghiêng của cỏ ven đường…), không chỉ khác màu.
Số liệu chính xác từng asset nằm ở `docs/STATS.md` và `docs/asset_metadata.json`.

### Cấu tạo mesh
* **Lá cỏ & cuống hoa**: dải tam giác thon nhọn (2–4 đoạn) → silhouette rõ, rất ít polygon; **không** dùng hair / curve / particle.
* **Đầu hoa & lá cây phủ đất**: card alpha-cutout cắt sát hình (đầu hoa bát giác 8 tam giác ở LOD0, 2 tam giác ở LOD1), nghiêng và xoay quanh cuống để nhìn được từ nhiều góc kể cả camera hơi cao.
* **LOD2**: 3 card chéo nhau (6 tam giác; cây phủ đất 5 card nằm nghiêng, 10 tam giác) dùng ô “tuft” trong atlas, khớp màu / hình khối với LOD0.
* Mỗi cụm là **một mesh, một material slot**.

| | Ngân sách | Thực tế |
|---|---|---|
| Cỏ thấp LOD0 | 40–120 | 63–85 |
| Cỏ cao LOD0 | 80–220 | 91–133 |
| Hoa LOD0 | 100–300 | 96–134 |
| LOD1 | 30–50 % LOD0 | 29–50 % (cây phủ đất ~50 %) |
| LOD2 | 4–16 | 6 (cây phủ đất 10) |

(Cỏ thưa cố ý nhẹ hơn: 45–55 tam giác.)

## 3. Chuẩn xuất

* Đơn vị **mét**, Blender **Z-up**, glTF **Y-up** (`three = (bx, bz, −by)`), origin = **tâm chân cụm**, rotation/scale đã apply, không armature.
* Một material `GrassAtlas`: glTF `alphaMode = MASK`, `alphaCutoff = 0.5` (đã kiểm: `docs/ALPHA_CUTOFF_REPORT.md`), `doubleSided = true`, roughness 0,92, metallic 0, sampler clamp-to-edge + mipmap.
* Atlas có gutter 4 px + RGB được kéo ra ngoài mép alpha (chống viền khi mipmap); `textures/../renders/atlas_views.png` có ảnh kiểm tra.
* Không bake bóng, nền trời hay ánh sáng studio. Gốc lá chỉ tối nhẹ theo kiểu vẽ tay; vùng xanh đậm trong bóng râm phải đến từ ánh sáng cảnh.
* Normal map **không dùng** (không cải thiện rõ so với normal tuỳ chỉnh hướng lên). Vertex color **không dùng**.
* UV nằm trong atlas với padding 5 px; normal tuỳ chỉnh “hướng lên + phồng nhẹ ra ngoài” để cỏ sáng đều kiểu vẽ tay.

### LOD
GLB **không tự chuyển LOD**. App chọn LOD theo khoảng cách (gợi ý khởi đầu, chưa đo): LOD0 < 3,2 m, LOD1 < 6,5 m, LOD2 < 24 m, xa hơn chỉ dùng texture nền.
Cùng origin / chiều cao / chân cho 3 LOD (đã kiểm tự động: không LOD nào cao hơn LOD0, chân luôn ở y = 0).

### Gió
Mỗi đỉnh có thuộc tính float **`_WIND`** (three.js: attribute `_wind`): 0 ở gốc, 1 ở ngọn phần cao nhất của cụm, `(z/H)^1.5`; cây phủ đất tối đa 0,45.
Cách đọc và shader mẫu: `r3f/grassKit.js` (`createGrassMaterial`) và `docs/R3F_GUIDE.md`. Quy ước dự phòng nếu không đọc được attribute: trọng số = (độ cao cục bộ / chiều cao cụm)^1,5.

## 4. Bốn hệ cỏ sân

Mỗi hệ có texture nền + cụm 3D khác nhau về hình dáng và mật độ (`docs/lawn_systems.json`, và empty `LawnX_*` trong collection **Lawn** của .blend):

| Hệ | Texture nền | Cụm 3D | Ý đồ |
|---|---|---|---|
| A. Cắt ngắn | `Ground_LawnShort.jpg` | `GrassLow_A/B/C` | texture lo độ phủ; cụm thấp chỉ thêm chiều sâu ở gần camera / mép |
| B. Tự nhiên | `Ground_LawnNatural.jpg` | `GrassLow_C/D`, `GrassYellow_*`, vài `GrassTall_*` | mảng xanh đậm / non / xanh vàng, vài cụm dài |
| C. Thưa | `Ground_LawnSparseSoil.jpg` | `GrassSparse_A–C`, `GrassRoadside_A` | đất lộ ra, chuyển tiếp mềm, không viền chữ nhật |
| D. Có hoa | `Ground_LawnShort.jpg` + `Ground_SoilUnderFlowers.jpg` | cỏ thấp + `Flower*` + `GroundCover_*` | hoa theo nhóm có khoảng trống; biến thể ít / nhiều hoa |

Texture nền lặp mỗi **1,5 m**.

## 5. Patch mẫu (linked instances)

Trong .blend: collection `PreviewPatches` (7 patch, mỗi patch là một collection asset, instance dùng chung mesh). Dữ liệu dựng lại bằng instancing: `patches/PreviewPatches.json`.

1. `Patch_1_LawnShortCut` – cỏ cắt ngắn  2. `Patch_2_LawnNatural` – cỏ tự nhiên  3. `Patch_3_LawnSparseSoil` – cỏ thưa phối đất
4. `Patch_4_RoadsideFlowers` – cỏ ven đường + hoa hồng / tím  5–6. `Patch_5_LawnFlowersFew` / `Patch_6_LawnFlowersMany` – cỏ sân có hoa nhỏ (ít / nhiều)
7. `Patch_7_GrassToSoilEdge` – mép chuyển từ cỏ dày sang đất.

Bố cục theo cụm (dày / thưa / khoảng trống) bằng value-noise + blob + Poisson-disc, có **seed** cố định (`scripts/patch_layout.py`) – không phải lưới đều.

## 6. Ảnh render (Cycles, dựng từ chính các file GLB đã xuất)

| Ảnh | Nội dung |
|---|---|
| `renders/clumps/<Asset>.png` | mỗi cụm một ảnh, nền trong suốt, góc chếch |
| `renders/overview_sheet.png`, `overview_lineup_labeled.png` | bảng tổng quan (từng cụm lấp đầy ô / tỷ lệ thật) |
| `renders/closeups/*.png`, `atlas_views.png`, `silhouettes.png` | cận cảnh silhouette & texture, atlas trên nền caro / nền tối / RGB (kiểm viền) |
| `renders/lod/<Asset>_LODs.png`, `lod_sheet.png` | LOD0 / LOD1 / LOD2 cùng ánh sáng |
| `renders/light/<Asset>_sun.png / _shade.png` | cảnh nắng và cảnh bóng râm |
| `renders/patches/*_eye_*.png`, `*_top_*.png` | patch nhìn tầm mắt người và nhìn chếch từ trên (nắng; cỏ tự nhiên & cỏ nhiều hoa có thêm bản bóng râm) |
| `renders/threejs/*.png` | ảnh chụp từ three.js / R3F thật (Chromium headless, software GL) |

Ánh sáng: nắng hơi ấm + bóng mềm + sky; render patch dùng nền cỏ / đất đơn giản. Trong ảnh patch, LOD được chọn theo khoảng cách camera (như app sẽ làm).

## 7. Kiểm chứng & giới hạn (đọc kỹ)

**Đã kiểm bằng máy:**
* Mọi mesh (84 mesh = 28 × 3 LOD) import vào three.js r170: chân ở y = 0, chiều cao khớp metadata, LOD2/LOD1 không cao hơn LOD0, có `normal`, `uv`, `_wind` (gốc = 0), material `alphaTest 0.5`, `DoubleSide`.
* `GrassField.jsx` thật được bundle (esbuild) và mount trong `@react-three/fiber` 8 / `drei` 9 trên Chromium headless: chạy không lỗi, số draw call / triangle khớp bản three.js thuần.
* Chọn alpha cutoff dựa trên phân tích diện tích còn lại theo từng mip.

**Số đo three.js** (patch `Patch_2_LawnNatural`, 960×540, DPR 1, Chromium headless + **SwiftShader (render bằng CPU)**): xem `docs/THREEJS_CHECK.md`.
**Chưa đo / chưa kiểm chứng:** FPS và frame time **trên GPU / điện thoại thật** (số ms ở trên là của bộ render phần mềm, không đại diện cho thiết bị thật – không thể kết luận “chạy mượt”); độ tin cậy của các ngưỡng LOD và mật độ gợi ý; bóng đổ của cỏ; hiệu năng khi nhiều patch cùng lúc; hình ảnh so với ảnh tham chiếu (không có ảnh).

## 8. Dựng lại

```bash
pip install bpy numpy pillow            # Blender 5.x dạng module
python3 -I scripts/run_all.py           # texture -> kit -> GLB -> alpha check -> patch -> render -> sheets
THREE_NM=/path/to/node_modules python3 -I scripts/run_all.py --no-render   # thêm bước kiểm three.js (cần playwright + three)
```
Chạy riêng: `atlas.py textures` · `build_kit.py` · `patch_layout.py` · `patches_blend.py` · `render_clumps.py` · `render_extra.py` · `render_patches.py` · `make_sheets.py`.
Tham số hình dáng từng asset nằm ở bảng `ASSETS` trong `scripts/grasskit_lib.py`.
