const std = @import("std");
const e = @import("e272");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var window = e.Window.init(240 * 5, 160 * 5, "MAIIIUHA272");
    defer window.deinit();

    var scene = try e.Scene.empty(allocator);
    defer scene.deinit();

    try scene.objs.ensureTotalCapacity(scene.allocator, 1000);
    for (0..10) |x| {
        for (0..100) |y| {
            var obj = e.Object.init(
                e.Model.xy(@floatFromInt(x * 16), @floatFromInt(y * 16)),
                try e.Visual.init2D(io, allocator),
            );

            // const value = map.at(@floatFromInt(x), @floatFromInt(y));
            // const color: u8 = @trunc(value * 256);
            // e.debug.printBgRed(@intCast(x + 10), @intCast(y + 10), color);
            //
            // const texture_file_name = if (value < 0.5) "res/pesok_tile.png" else "res/dark_pesok_tile.png";
            const texture_file_name = if (x % 2 == 0) "res/pesok_tile.png" else "res/dark_pesok_tile.png";
            try obj.visual.?.addTexture(texture_file_name, @intCast(x % 2), io, allocator);

            try scene.objs.append(scene.allocator, obj);
        }
    }
    var cam_listener = e.InputListener(e.Camera).init(cam_press, window, io);
    window.cam.input_listener = &cam_listener;

    window.loop(&scene);
}

pub fn cam_press(this: *e.InputListener(e.Camera), cam: *e.Camera, delta: i64) void {
    const delta_f: f32 = @floatFromInt(delta);
    if (this.is_pressing_key(e.c.GLFW_KEY_D)) {
        cam.view.x += 0.1 * delta_f;
    }
    if (this.is_pressing_key(e.c.GLFW_KEY_A)) {
        cam.view.x -= 0.1 * delta_f;
    }
    if (this.is_pressing_key(e.c.GLFW_KEY_S)) {
        cam.view.y += 0.1 * delta_f;
    }
    if (this.is_pressing_key(e.c.GLFW_KEY_W)) {
        cam.view.y -= 0.1 * delta_f;
    }
    if (this.is_pressing_key(e.c.GLFW_KEY_EQUAL)) {
        cam.view.zoom -= 0.0003 * delta_f;
    }

    if (this.is_pressing_key(e.c.GLFW_KEY_MINUS)) {
        cam.view.zoom += 0.0003 * delta_f;
    }
}
