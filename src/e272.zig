const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const panic = std.debug.panic;
pub const gen = @import("gen.zig");
pub const out = @import("out.zig");

pub const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("stdio.h");
    @cInclude("glad/gl.h");
    @cInclude("GLFW/glfw3.h");
});

const img = @import("zigimg");
const m = @import("zmath");

pub const Game = struct {
    window: Window,
    scenes: std.ArrayList(Scene),
};

pub const Scene = struct {
    objs: std.ArrayList(Object),
    allocator: Allocator,

    pub fn default(io: Io, allocator: Allocator) !@This() {
        var objs = try std.ArrayList(Object).initCapacity(allocator, 1);
        try objs.append(allocator, try Object.default(io, allocator));

        return @This(){
            .objs = objs,
            .allocator = allocator,
        };
    }

    pub fn listen(this: *@This()) void {
        for (this.objs.items) |*obj| {
            if (obj.input_listener == null) continue;
            if (obj.input_listener.?.deaf) continue;
            var listener = obj.input_listener.?;
            listener.listen(obj);
        }
    }

    pub fn deinit(this: *@This()) void {
        for (this.objs.items) |*obj|
            obj.deinit();
        this.objs.deinit(this.allocator);
    }
};

pub const Object = struct {
    model: Model,
    visual: ?Visual = null,
    physical: ?Physical = null,

    draw: *const fn (*@This(), prog: c_uint, anything: u64) void,
    input_listener: ?*InputListener(@This()),

    pub fn default(io: Io, allocator: Allocator) !Object {
        return @This(){
            .model = Model.xy(0, 0),
            .visual = try Visual.init(io, allocator),
            .draw = default_draw,
            .input_listener = null,
        };
    }

    fn default_draw(this: *@This(), prog: c_uint, _: u64) void {
        const model_loc = c.glGetUniformLocation(prog, "model");
        const model = this.model.vec();
        c.glUniformMatrix4fv(model_loc, 1, c.GL_FALSE, @ptrCast(&model));
    }

    pub fn deinit(this: *@This()) void {
        if (this.visual) |*v| v.deinit();
    }
};

pub const Camera = struct {
    view: View,
    projection: Projection,

    input_listener: ?*InputListener(@This()),

    pub fn gba() @This() {
        return @This(){ .view = .zero(), .projection = .gba(), .input_listener = null };
    }

    // WARNING: HARD CODED ONLY FOR 2D
    pub fn draw(this: @This(), objs: []Object) void {
        for (objs) |*obj| {
            if (obj.visual == null) continue;
            const visual = obj.visual.?;

            c.glUseProgram(visual.gl.prog);
            c.glBindVertexArray(visual.gl.vao);

            const prog = visual.gl.prog;

            obj.draw(obj, prog, undefined);

            const view_loc = c.glGetUniformLocation(prog, "view");
            const view = this.view.vec();
            c.glUniformMatrix4fv(view_loc, 1, c.GL_FALSE, @ptrCast(&view));

            const proj_loc = c.glGetUniformLocation(prog, "projection");
            const proj = this.projection.vec();
            c.glUniformMatrix4fv(proj_loc, 1, c.GL_FALSE, @ptrCast(&proj));

            c.glActiveTexture(c.GL_TEXTURE0);
            c.glUniform1i(c.glGetUniformLocation(prog, "tex"), 0);

            c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
            checkGLError();
        }
    }
};

pub const Visual = struct {
    gl: struct {
        prog: c.GLuint,
        vao: c.GLuint,
        vbo: c.GLuint,
    },

    texs: std.StringHashMap(c_uint),

    // TODO: add support for changing buffer values
    fn default_gl() struct { vao: c.GLuint, vbo: c.GLuint } {
        const buffer = [_]f32{
            // positions        // texture coords
            0.0, 0.0, 0.0, 0.0, 0.0, // bottom-left
            1.0, 0.0, 0.0, 1.0, 0.0, // bottom-right
            0.0, 1.0, 0.0, 0.0, 1.0, // top-left
            1.0, 1.0, 0.0, 1.0, 1.0, // top-right
        };

        var vbo: c.GLuint = undefined;
        c.glGenBuffers(1, &vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(buffer.len * @sizeOf(f32)), @ptrCast(@alignCast(&buffer)), c.GL_STATIC_DRAW);

        // WARNING: HARD CODED
        var vao: c.GLuint = undefined;
        c.glGenVertexArrays(1, &vao);
        c.glBindVertexArray(vao);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(f32), @ptrFromInt(0));
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
        c.glEnableVertexAttribArray(1);

        return .{ .vao = vao, .vbo = vbo };
    }

    pub fn init(io: Io, allocator: Allocator) !@This() {
        // WARNING: HARD CODED
        var vert_code = try readFile("./res/shaders/ortho3dtextured.vert", io, allocator);
        defer allocator.free(vert_code);
        // WARNING: HARD CODED
        var frag_code = try readFile("./res/shaders/ortho3dtextured.frag", io, allocator);
        defer allocator.free(frag_code);

        const vert = c.glCreateShader(c.GL_VERTEX_SHADER);
        const frag = c.glCreateShader(c.GL_FRAGMENT_SHADER);

        c.glShaderSource(vert, 1, &vert_code.ptr, null);
        c.glShaderSource(frag, 1, &frag_code.ptr, null);

        c.glCompileShader(vert);
        try checkCompileStatus("VERTEX", vert);

        c.glCompileShader(frag);
        try checkCompileStatus("FRAGMENT", frag);

        const prog = c.glCreateProgram();
        c.glAttachShader(prog, vert);
        c.glAttachShader(prog, frag);
        c.glLinkProgram(prog);

        c.glDeleteShader(vert);
        c.glDeleteShader(frag);

        c.glUseProgram(prog);

        const gl = default_gl();

        var this = @This(){
            .gl = .{ .prog = prog, .vao = gl.vao, .vbo = gl.vbo },
            .texs = .init(allocator),
        };
        try this.addTexture("pesok_tile.png", 0, io, allocator);
        return this;
    }

    fn checkCompileStatus(T: []const u8, d: c.GLuint) error{CompilationFailed}!void {
        var success: c_int = 0;
        const log_size = 1024;
        var info_log: [log_size]u8 = undefined;

        c.glGetShaderiv(d, c.GL_COMPILE_STATUS, &success);
        if (success == 0) {
            c.glGetShaderInfoLog(d, log_size, null, &info_log);
            _ = c.printf("ERROR::SHADER::%s::COMPILATION_FAILED\n%s\n", &T.ptr, &info_log);
            return error.CompilationFailed;
        }
    }

    pub fn addTexture(this: *@This(), comptime path: []const u8, slot: c_int, io: std.Io, allocator: Allocator) !void {
        c.glUseProgram(this.gl.prog);
        c.glActiveTexture(@intCast(c.GL_TEXTURE0 + slot));

        var read_buffer: [img.io.DEFAULT_BUFFER_SIZE]u8 = undefined;

        var file = try std.Io.Dir.cwd().openFile(io, "./res/" ++ path, .{ .mode = .read_only });
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

        try this.texs.put(path, texture_id);
    }

    pub fn deinit(this: *@This()) void {
        this.texs.deinit();
        c.glDeleteBuffers(1, &this.gl.vbo);
        c.glDeleteVertexArrays(1, &this.gl.vao);
    }
};

pub const Physical = struct {
    hitbox: struct { x: f32, y: f32, z: f32 },

    pub fn init() @This() {
        return @This(){ .hitbox = .{ .x = 1, .y = 1, .z = 1 } };
    }
};

pub const Model = struct {
    x: f32,
    y: f32,
    z: f32,

    rx: f32,
    ry: f32,
    rz: f32,

    width: f32,
    height: f32,
    length: f32,

    pub fn xy(x: f32, y: f32) @This() {
        return @This(){
            .x = x,
            .y = y,
            .z = 0,
            .rx = 0,
            .ry = 0,
            .rz = 0,
            .width = 16,
            .height = 16,
            .length = 1,
        };
    }

    pub fn vec(this: @This()) [4]@Vector(4, f32) {
        var model = m.identity();

        // 1. Scale
        model = m.mul(model, m.scaling(this.width, this.height, this.length));

        // 2. Rotation (with center offset)
        // First move to center, then rotate, then move back
        var rotation = m.identity();
        rotation = m.mul(rotation, m.translation(-this.width / 2, -this.height / 2, -this.length / 2));
        rotation = m.mul(rotation, m.rotationZ(this.rz));
        rotation = m.mul(rotation, m.rotationY(this.ry));
        rotation = m.mul(rotation, m.rotationX(this.rx));
        rotation = m.mul(rotation, m.translation(this.width / 2, this.height / 2, this.length / 2));

        model = m.mul(model, rotation);

        // 3. Translation to world position
        model = m.mul(model, m.translation(this.x, this.y, this.z));

        return model;
    }
};

pub const View = struct {
    x: f32,
    y: f32,
    z: f32,

    rx: f32,
    ry: f32,
    rz: f32,

    zoom: f32,

    pub fn zero() @This() {
        return @This(){ .x = 0, .y = 0, .z = 0, .rx = 0, .ry = 0, .rz = 0, .zoom = 1 };
    }

    pub fn vec(this: @This()) [4]@Vector(4, f32) {
        var view = m.identity();

        const inv_zoom = 1.0 / this.zoom;
        view = m.mul(view, m.scaling(inv_zoom, inv_zoom, inv_zoom));

        view = m.mul(view, m.rotationZ(-this.rz));
        view = m.mul(view, m.rotationY(-this.ry));
        view = m.mul(view, m.rotationX(-this.rx));

        view = m.mul(view, m.translation(-this.x, -this.y, -this.z));

        return view;
    }
};

pub const Projection = struct {
    near: f32,
    far: f32,

    width: f32,
    height: f32,

    pub fn gba() @This() {
        return @This(){ .near = 1, .far = -1, .width = 240, .height = 160 };
    }

    pub fn vec(this: @This()) [4]@Vector(4, f32) {
        return m.orthographicOffCenterLhGl(0, this.width, 0, this.height, this.near, this.far);
    }
};

pub const Window = struct {
    glfw: *c.GLFWwindow,
    cam: Camera,
    clock: std.Io.Clock,

    pub fn init(width: usize, height: usize, title: []const u8) @This() {
        if (c.glfwInit() == 0)
            panic("GLFW init", .{});

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 5);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

        const window = c.glfwCreateWindow(@intCast(width), @intCast(height), title.ptr, null, null);
        if (window == null)
            panic("GLFWwindow init", .{});

        c.glfwMakeContextCurrent(window);
        _ = c.glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

        if (c.gladLoadGL(@as(c.GLADloadfunc, @ptrCast(&c.glfwGetProcAddress))) == 0)
            panic("Failed to initialize GLAD\n", .{});

        _ = c.printf("OpenGL Version: %s\n", c.glGetString(c.GL_VERSION));
        _ = c.printf("OpenGL Renderer: %s\n", c.glGetString(c.GL_RENDERER));
        _ = c.printf("OpenGL Vendor: %s\n", c.glGetString(c.GL_VENDOR));

        return @This(){
            .glfw = window.?,
            .cam = .gba(),
            .clock = std.Io.Clock.real,
        };
    }

    fn framebuffer_size_callback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
        c.glViewport(0, 0, width, height);
        _ = window;
    }

    pub fn loop(window: *Window, scene: *Scene) void {
        while (c.glfwWindowShouldClose(window.glfw) == 0) {
            c.glClearColor(0.1, 0.1, 0.15, 1.0);
            c.glClear(c.GL_COLOR_BUFFER_BIT);

            scene.listen();
            if (window.cam.input_listener) |li| li.listen(&window.cam);
            window.cam.draw(scene.objs.items);

            c.glfwSwapBuffers(window.glfw);
            c.glfwPollEvents();
        }
    }

    pub fn deinit(this: *@This()) void {
        c.glfwDestroyWindow(this.glfw);
        c.glfwTerminate();
    }
};

// WARNING: HARDCODED: add delta interface instead of manually calculating it
pub fn InputListener(comptime T: type) type {
    return switch (T) {
        Object, Camera => struct {

            // WARNING: remove glfw enum
            action: *const fn (*@This(), *T, delta: i64) void,
            target: Window,
            deaf: bool,
            time_prev: i64,

            io: std.Io,

            pub fn init(action: *const fn (*@This(), *T, delta: i64) void, target: Window, io: std.Io) @This() {
                return @This(){
                    .action = action,
                    .target = target,
                    .deaf = false,
                    .time_prev = std.Io.Clock.real.now(io).toMilliseconds(),
                    .io = io,
                };
            }

            pub fn listen(this: *@This(), obj: *T) void {
                const now = std.Io.Clock.real.now(this.io).toMilliseconds();
                const delta = now - this.time_prev;
                this.time_prev = now;

                this.action(this, obj, delta);
            }

            pub fn is_pressing_key(this: *@This(), glfw_key: c_int) bool {
                return c.glfwGetKey(this.target.glfw, glfw_key) == c.GLFW_PRESS;
            }
        },
        else => @compileError("This type is not supported"),
    };
}

pub fn readFile(file_path: []const u8, io: std.Io, allocator: Allocator) ![:0]u8 {
    var file = try std.Io.Dir.cwd().openFile(io, file_path, .{});
    defer file.close(io);

    const stat = try file.stat(io);
    if (stat.size == 0) return error.EmptyFile;

    var buffer = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(buffer);

    const bytes_read = try file.readPositionalAll(io, buffer, 0);

    const actual_size = bytes_read;
    if (actual_size != stat.size) {
        buffer = try allocator.realloc(buffer, actual_size);
    }

    var null_terminated = try allocator.alloc(u8, actual_size + 1);
    errdefer allocator.free(null_terminated);

    @memcpy(null_terminated[0..actual_size], buffer[0..actual_size]);
    null_terminated[actual_size] = 0;

    allocator.free(buffer);

    return null_terminated[0..actual_size :0];
}

pub fn checkGLError() void {
    while (true) {
        const err = c.glGetError();
        if (err == c.GL_NO_ERROR) break;
        const err_str = switch (err) {
            c.GL_INVALID_ENUM => "GL_INVALID_ENUM",
            c.GL_INVALID_VALUE => "GL_INVALID_VALUE",
            c.GL_INVALID_OPERATION => "GL_INVALID_OPERATION",
            c.GL_STACK_OVERFLOW => "GL_STACK_OVERFLOW",
            c.GL_STACK_UNDERFLOW => "GL_STACK_UNDERFLOW",
            c.GL_OUT_OF_MEMORY => "GL_OUT_OF_MEMORY",
            c.GL_INVALID_FRAMEBUFFER_OPERATION => "GL_INVALID_FRAMEBUFFER_OPERATION",
            else => "UNKNOWN_ERROR",
        };
        std.debug.print("OpenGL Error: {s}\n", .{err_str});
    }
}
