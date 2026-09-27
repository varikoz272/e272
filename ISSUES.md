# 1

Opengl renderes only 1 texture, which should not be an issue, considering which textures are different opengl programs with different buffers and tex slots

```zig
// passing different texture files to addTexture, but getting the same result (depending on map.seed)
const texture_file_name = if (x % 2 == 0) "res/pesok_tile.png" else "res/dark_pesok_tile.png";
try obj.visual.?.addTexture(texture_file_name, @intCast(x % 2), io, allocator);
```
