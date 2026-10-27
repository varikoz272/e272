const std = @import("std");
const e = @import("e272");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var window = e.Window.init(240 * 5, 160 * 5, "MAIIIUHA272");
    defer window.deinit();

    var ctx = try e.OpenGLContext.init(allocator);
    defer ctx.deinit();

    var scene = try e.Scene.empty(allocator);
    defer scene.deinit();

    const map = e.gen.Map2.init(100, 0, 0.9999999);

    try scene.objs.ensureTotalCapacity(scene.allocator, 30 * 30);
    for (0..30) |x| {
        for (0..30) |y| {
            var obj = e.Object.init(
                e.Model.xy(@floatFromInt(x * 16), @floatFromInt(y * 16)),
                try e.Visual.init2D(io, allocator),
            );

            const value = map.at(@floatFromInt(x), @floatFromInt(y));
            const texture_file_name = if (value < 0.5) "res/pesok_tile.png" else "res/dark_pesok_tile.png";
            try obj.visual.?.setTexture(texture_file_name, &ctx, io, allocator);

            try scene.objs.append(scene.allocator, obj);
        }
    }
    var speed: f32 = 0.5;
    var cam_listener = e.Listener(e.Camera).init(cam_press, &speed, window, io);
    window.cam.input_listener = &cam_listener;
    var change_listener = e.Listener(e.View).init(view_change, undefined, window, io);
    window.cam.view.change_listener = &change_listener;

    window.loop(&scene);
}

pub fn view_change(_: *e.Listener(e.View), view: *e.View, _: *anyopaque, delta: i64) void {
    const delta_f: f32 = @floatFromInt(delta);
    view.x += delta_f * 0.05;
}

pub fn cam_press(this: *e.Listener(e.Camera), cam: *e.Camera, data: *anyopaque, delta: i64) void {
    const delta_f: f32 = @floatFromInt(delta);
    const speed: f32 = @as(*f32, @ptrCast(@alignCast(data))).*;
    if (this.is_pressing_key(e.c.GLFW_KEY_D)) {
        cam.view.move(speed * delta_f, 0, 0);
    }
    if (this.is_pressing_key(e.c.GLFW_KEY_A)) {
        cam.view.move(-speed * delta_f, 0, 0);
    }
    if (this.is_pressing_key(e.c.GLFW_KEY_S)) {
        cam.view.move(0, speed * delta_f, 0);
    }
    if (this.is_pressing_key(e.c.GLFW_KEY_W)) {
        cam.view.move(0, -speed * delta_f, 0);
    }
    if (this.is_pressing_key(e.c.GLFW_KEY_EQUAL)) {
        cam.view.zoomIn(-0.0003 * delta_f, .expanded);
    }
    if (this.is_pressing_key(e.c.GLFW_KEY_MINUS)) {
        cam.view.zoomIn(0.0003 * delta_f, .expanded);
    }
}
