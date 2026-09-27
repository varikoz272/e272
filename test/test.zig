const std = @import("std");
const e = @import("e272");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const map = e.gen.Map2.init(10);

    for (0..20) |x| {
        for (0..20) |y| {
            const xf: f32 = @floatFromInt(x);
            const yf: f32 = @floatFromInt(y);
            const color: u8 = @intFromFloat(map.at(xf, yf) * 256);

            e.debug.printBgRed(@intCast(x + 10), @intCast(y + 10), color);
        }
    }

    var window = e.Window.init(240 * 5, 160 * 5, "MAIIIUHA272");
    defer window.deinit();

    var scene = try e.Scene.default(io, allocator);
    defer scene.deinit();

    var cam_listener = e.InputListener(e.Camera).init(cam_press, window, io);
    window.cam.input_listener = &cam_listener;

    e.debug.log("LOG");
    e.debug.warn("WARNING");
    e.debug.err("ERROR");

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
