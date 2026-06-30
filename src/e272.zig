const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const gl = @import("gl.zig");
const os = @import("os.zig");
const Map = @import("tools/Map.zig");

const input = @import("input.zig");

pub const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("stdio.h");
    @cInclude("glad/gl.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("cglm/cglm.h");
});
const img = @import("zigimg");

const window_width = 1920;
const window_height = 1080;

const tile_width = window_width / 240 * 16;
const tile_height = window_height / 160 * 16;

// var shaderProgram: c_uint = 0;
var VAO: c_uint = 0;
var VBO: c_uint = 0;
var EBO: c_uint = 0;
var transformLoc: c_int = 0;

fn initDrawResources() !void {
    // Set up vertex data for a quad (unit square from -0.5 to 0.5)
    const vertices = [_]f32{
        // positions          // texture coordinates
        -0.5, -0.5, 0.0, 0.0, // bottom-left
        0.5, -0.5, 1.0, 0.0, // bottom-right
        0.5, 0.5, 1.0, 1.0, // top-right
        -0.5, 0.5, 0.0, 1.0, // top-left
        0.5, 0.5, 1.0, 1.0, // top-right
        -0.5, -0.5, 0.0, 0.0, // bottom-left
    };

    // const indices = [_]c_uint{
    //     0, 1, 2, // first triangle
    //     2, 3, 0, // second triangle
    // };

    c.glGenVertexArrays(1, &VAO);
    c.glGenBuffers(1, &VBO);
    // c.glGenBuffers(1, &EBO);

    c.glBindVertexArray(VAO);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_DYNAMIC_DRAW);

    // Position attribute
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 4 * @sizeOf(f32), @ptrFromInt(0));
    c.glEnableVertexAttribArray(0);

    // Texture coordinate attribute
    c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, 4 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    c.glEnableVertexAttribArray(1);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindVertexArray(0);
}

fn setupOrthographicProjection(prog: gl.Program) void {
    var projection = gl.Projection.GBA();

    const projectionLoc = c.glGetUniformLocation(prog.idx, "projection");
    c.glUniformMatrix4fv(projectionLoc, 1, c.GL_FALSE, @ptrCast(&projection.data));
}

// With orthographic projection, vertex shader becomes:
// gl_Position = projection * transform * vec4(aPos, 1.0);
// And you can use pixel coordinates directly in your draw function:

fn drawWithProjection(prog: gl.Program, texture: c_uint, x: f32, y: f32, width: f32, height: f32) void {
    c.glUseProgram(prog.idx); // Make sure program is active
    c.glActiveTexture(c.GL_TEXTURE0);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);

    const matrix = [_]f32{
        width,           0.0,              0.0, 0.0,
        0.0,             height,           0.0, 0.0,
        0.0,             0.0,              1.0, 0.0,
        x + width / 2.0, y + height / 2.0, 0.0, 1.0,
    };

    c.glUniformMatrix4fv(transformLoc, 1, c.GL_FALSE, &matrix);
    c.glBindVertexArray(VAO);
    c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
    // c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);
}

pub fn init() os.Window {
    const window = os.Window.init(1920, 1080) catch unreachable;
    gl.init() catch unreachable;

    return window;
}

pub fn deinit(window: os.Window) void {
    window.deinit();
}

pub fn run(io: std.Io, allocator: Allocator) !void {
    const window = init();
    defer deinit(window);

    // const vertex_shader = try gl.Shader.init(.vertex, "static", io, allocator);
    // const fragment_shader = try gl.Shader.init(.fragment, "static", io, allocator);

    const vertex_shader = gl.Shader.init("static", .vertex);
    vertex_shader.compile(io, allocator) catch unreachable;
    const fragment_shader = gl.Shader.init("static", .fragment);
    fragment_shader.compile(io, allocator) catch unreachable;
    const shader_program = gl.Program.init(vertex_shader, fragment_shader) catch unreachable;

    // c.glDeleteShader(vertex_shader.idx);
    vertex_shader.delete();
    fragment_shader.delete();
    // c.glDeleteShader(fragment_shader.idx);

    // const program = gl.Program.init(vertex_shader, fragment_shader);
    // shaderProgram = c.glCreateProgram();
    // c.glAttachShader(shaderProgram, vertex_shader.idx);
    // c.glAttachShader(shaderProgram, fragment_shader.idx);
    // c.glLinkProgram(shaderProgram);
    // checkProgramLinkStatus(shaderProgram);

    // Get transform uniform location
    const transformLoc = c.glGetUniformLocation(shader_program.idx, "transform");

    // Initialize draw resources (VAO, VBO, EBO)
    try initDrawResources();

    // Load texture using zigimg
    const texture = try loadTexture(allocator, io, "res/pesok_tile.png");
    defer c.glDeleteTextures(1, &texture);

    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    var xoff: f32 = 1;

    c.glUseProgram(shader_program.idx);
    setupOrthographicProjection();

    var listener = input.Listener(.Keyboard).init(allocator);
    listener.observe(.W, w_callback) catch unreachable;
    defer listener.deinit();

    var map: Map = .init(1, 1, 5, allocator);
    for (0..10) |x| {
        for (0..10) |y| _ = map.generator.at(@truncate(x), @truncate(y));
    }
    defer map.destroy();

    // Main render loop
    while (c.glfwWindowShouldClose(window.c_window) == 0) {
        // Clear screen with dark teal color
        c.glClearColor(0.1, 0.1, 0.15, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        listener.check(window.c_window, &xoff);

        var iter = map.tiles.iterator();
        while (iter.next()) |e| {
            const x: f32 = @floatFromInt(e.key_ptr.x());
            const y: f32 = @floatFromInt(e.key_ptr.y());
            drawWithProjection(texture, x * 16 + xoff, y * 16, 16.0, 16.0);
        }

        c.glfwSwapBuffers(window.c_window);
        c.glfwPollEvents();
    }

    // Cleanup
    c.glDeleteVertexArrays(1, &VAO);
    c.glDeleteProgram(shaderProgram);
}

fn w_callback(x: *f32) void {
    x.* += 0.05;
    // std.debug.print("hui{d}\n", .{x.*});
}

fn loadTexture(allocator: std.mem.Allocator, io: std.Io, file_path: [:0]const u8) !c_uint {
    var read_buffer: [img.io.DEFAULT_BUFFER_SIZE]u8 = undefined;

    var file = try std.Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only });
    defer file.close(io);

    var image = try img.Image.fromFile(allocator, io, file, read_buffer[0..]);
    defer image.deinit(allocator);

    if (image.pixelFormat() != .rgba32) {
        try image.convert(allocator, .rgba32);
    }

    const width = @as(c_int, @intCast(image.width));
    const height = @as(c_int, @intCast(image.height));

    var texture_id: c_uint = 0;
    c.glGenTextures(1, &texture_id);
    c.glBindTexture(c.GL_TEXTURE_2D, texture_id);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

    const raw_bytes = image.rawBytes();
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, width, height, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, raw_bytes.ptr);
    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    return texture_id;
}
