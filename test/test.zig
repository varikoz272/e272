const std = @import("std");
const e = @import("e272");

const CameraChangeData = struct {
    camera: *e.Camera,
    scene: *e.Scene,
    map: *e.gen.Map2,
    tile_size: f32,
    ctx: *e.OpenGLContext,
    io: std.Io,
    allocator: std.mem.Allocator,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var window = e.Window.init(240 * 5, 160 * 5, "MAIIIUHA272", allocator);
    defer window.deinit();

    var ctx = try e.OpenGLContext.init(allocator);
    defer ctx.deinit();

    var scene = try e.Scene.empty(allocator);
    defer scene.deinit();

    const tile_size: f32 = 8.0;

    var map = e.gen.Map2.init(100, 0, 0.9999999);

    try scene.objs.ensureTotalCapacity(100 * 100);
    var speed: f32 = 0.5;
    var cam_listener = e.Listener(e.Camera).init(cam_press, &speed, window, io);
    window.cam.input_listener = &cam_listener;
    var cam_change_data = CameraChangeData{
        .camera = &window.cam,
        .scene = &scene,
        .map = &map,
        .tile_size = tile_size,
        .ctx = &ctx,
        .io = io,
        .allocator = allocator,
    };
    var change_listener = e.Listener(e.View).init(view_change, &cam_change_data, window, io);
    window.cam.view.change_listener = &change_listener;

    var map_reset_data = .{ &map, &window.cam.view };
    var map_reset_listener = e.Listener(e.Scene).init(map_reset_press, &map_reset_data, window, io);
    scene.input_listener = &map_reset_listener;

    window.loop(&scene);
}

pub fn map_reset_press(this: *e.Listener(e.Scene), scene: *e.Scene, data: *anyopaque, _: i64) void {
    if (this.is_pressing_key(e.c.GLFW_KEY_R)) {
        const tuple_data: *struct { *e.gen.Map2, *e.View } = @ptrCast(@alignCast(data));
        var map = tuple_data.@"0";
        map.gen.seed +%= 1;
        scene.clear();
        tuple_data.@"1".move(0, 0, 0);
    }
}

pub fn view_change(_: *e.Listener(e.View), view: *e.View, data: *anyopaque, _: i64) void {
    _ = view;
    const tuple_data: *CameraChangeData = @ptrCast(@alignCast(data));
    var cam = tuple_data.camera;
    var scene = tuple_data.scene;
    _ = &scene;
    const tile_size = tuple_data.tile_size;
    const ctx = tuple_data.ctx;
    const io = tuple_data.io;
    const allocator = tuple_data.allocator;
    const map = tuple_data.map;

    cam.pull.clearAndFree();

    var tiles_in_row: i32 = @ceil((240 / tile_size) * cam.view.zoom);
    tiles_in_row += 1;
    var tiles_in_column: i32 = @ceil((160 / tile_size) * cam.view.zoom);
    tiles_in_column += 1;
    const first_tile_x: i32 = @floor(cam.view.x / tile_size);
    const first_tile_y: i32 = @floor(cam.view.y / tile_size);

    var x: i32 = first_tile_x;
    var y: i32 = first_tile_y;

    while (y < tiles_in_column + first_tile_y) : (y += 1) {
        while (x < tiles_in_row + first_tile_x) : (x += 1) {
            const xf: f32 = @floatFromInt(x);
            const yf: f32 = @floatFromInt(y);

            const model = e.Model.init2D(xf * tuple_data.tile_size, yf * tuple_data.tile_size, tile_size, tile_size);
            const obj = scene.objs.get(&model) orelse blk: {
                var new_obj = allocator.create(e.Object) catch unreachable;
                new_obj.* = e.Object.init(
                    model,
                    e.Visual.init2D(io, allocator) catch unreachable,
                );

                const value = map.at(@floatFromInt(x), @floatFromInt(y));
                e.debug.log("{d}", .{map.gen.seed}, .{"CURRENT SEED"});
                const texture_file_name = if (value < 0.5) "res/pesok_tile.png" else "res/dark_pesok_tile.png";
                new_obj.visual.?.setTexture(texture_file_name, ctx, io, allocator) catch unreachable;

                scene.objs.put(&new_obj.model, new_obj) catch unreachable;

                break :blk new_obj;
            };

            cam.pull.put(&obj.model, obj) catch unreachable;
        }
        x = first_tile_x;
    }
    e.debug.log("{d}", .{scene.objs.count()}, .{"scene.obj.count()"});
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
