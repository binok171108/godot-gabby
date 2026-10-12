# WorldGridManager — nền tảng quản lý thế giới Web

`WorldGridManager.gd` đã đăng ký Autoload trong `project.godot`. Manager chỉ hoạt động sau khi gọi `configure()`, không chạy song song với pipeline cũ khi chưa chuyển hệ thống sang nó.

## Hợp đồng

- Grid toán học 64×64 m, một bán kính hoạt động 64 m cho mọi loại thực thể. Quyết định dùng vị trí player và footprint của entity, không dùng camera hoặc bán kính theo loại entity.
- `entities` giữ vị trí, trạng thái, scene key, footprint và ô hiện tại; `active_nodes` chỉ giữ Node đang tồn tại. Despawn không xóa dữ liệu entity.
- `scene_cache` chỉ nhận PackedScene hoặc MultiMesh đã chuẩn bị trong RAM. Manager không có FileAccess, ResourceLoader, Thread, Worker, raycast hay đọc/ghi chunk runtime.
- Tối đa một spawn và bốn thay đổi Node mỗi frame; vòng quét grid và queue nhường frame khi dùng hết khoảng 2 ms. Một lần `PackedScene.instantiate()` không thể bị ngắt giữa chừng: prefab/cụm phải đủ nhỏ, không đặt nguyên thế giới vào một scene.
- Khi đang chờ despawn, Node ngoài vùng được ẩn ngay; queue kiểm lại vị trí hiện tại trước khi spawn/despawn để tránh thao tác cũ sau teleport.
- Simulation/gameplay cập nhật Dictionary qua `move_entity()`/`set_entity_state()`; không để Node con tự điều khiển streaming. State Dictionary cũng được gắn vào metadata `world_state` trước khi `_ready` chạy.

## Khởi tạo từ hệ thống trung tâm

```gdscript
WorldGridManager.configure(player, world_root)
WorldGridManager.bind_terrain(terrain_node)
WorldGridManager.register_scene(&"npc", cached_npc_scene)
WorldGridManager.register_entity(&"npc_001", &"npc", spawn_position, {"hp": 100})
WorldGridManager.register_multimesh_scene(&"foliage_0_0", baked_scatter_multimesh, foliage_material)
WorldGridManager.register_entity(&"foliage_0_0", &"foliage_0_0", chunk_origin, {}, false, Vector2(32, 32))
```

Các biến trong ví dụ phải được cấp từ cache RAM hoặc tài nguyên đã chuẩn bị lúc khởi tạo; không gọi loader file trong callback spawn. `resource_needed` báo scene key chưa có cache, không tự dựng model thay thế. `request_refresh()` dùng sau teleport để cập nhật ngay.

## Terrain3D / ProtonScatter

- Terrain3D hiện dùng `terrain.data.get_height(position)`; API `storage.get_height` thuộc phiên bản cũ. `bind_terrain()` hỗ trợ cả hai, không giả định một class plugin chưa cài. Cao độ được truy vấn trực tiếp khi spawn và khi `move_entity()`; NAN/lỗ/ngoài terrain sẽ báo `spawn_failed`, không spawn fallback. [API Terrain3DData](https://terrain3d.readthedocs.io/en/stable/api/class_terrain3ddata.html).
- ProtonScatter phải cung cấp output MultiMesh đã bake theo cụm, không chạy node generator/rebuild lúc chơi; mã upstream có đường rebuild bằng thread. [Mã ProtonScatter](https://github.com/HungryProton/scatter/blob/main/addons/proton_scatter/src/scatter.gd).
- Hai plugin chưa cài trong project này. Terrain3D công bố Web export còn experimental; cần xác minh binary Web/GDExtension và Safari riêng trước khi thay địa hình thật. [Nền tảng Terrain3D](https://github.com/TokisanGames/Terrain3D/blob/main/doc/docs/platforms.md).

## Trạng thái kiểm thử

`test_world_grid_manager.gd`: kiểm Autoload, spawn chia frame, state HP còn sau despawn/revisit, chuyển ô khi entity di chuyển, tọa độ world khi parent lệch, adapter data/storage, NAN không tạo fallback, cache MultiMesh và dọn thế giới.

Đây là script nền tảng đầu tiên. Pipeline game hiện tại vẫn có loader/provider cũ; chưa chuyển toàn bộ game sang manager này, chưa tích hợp plugin thực hoặc xác nhận Safari.
