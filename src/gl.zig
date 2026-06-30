const std = @import("std");
const Allocator = std.mem.Allocator;
const core = @import("e272.zig");
const c = core.c;
const os = @import("os.zig");

const Idx = c.GLuint;

pub fn init() !void {
    if (c.gladLoadGL(@as(c.GLADloadfunc, @ptrCast(&c.glfwGetProcAddress))) == 0) {
        _ = c.printf("Failed to initialize GLAD\n");
        return error.GLADInitFailed;
    }

    _ = c.printf("OpenGL Version: %s\n", c.glGetString(c.GL_VERSION));
    _ = c.printf("OpenGL Renderer: %s\n", c.glGetString(c.GL_RENDERER));
    _ = c.printf("OpenGL Vendor: %s\n", c.glGetString(c.GL_VENDOR));
}

pub const Projection = struct {
    pub const View = enum(u2) {
        clamped,
        stretched,
    };

    pub const Type = enum(u2) {
        orthographic,
        perspective,
    };

    view: View,
    T: Type,

    data: [4][4]f32 align(16),

    pub fn GBA() @This() {
        var data: [4][4]f32 align(16) = undefined;
        c.glm_ortho(0, 240, 160, 0.0, -1, 1, @ptrCast(@alignCast(&data)));

        return @This(){
            .view = .stretched,
            .T = .orthographic,
            .data = data,
        };
    }
};

pub const Object = struct {
    pub var unbind_afterwards = true;

    /// dont change the fields manualy
    pub fn VBO(comptime T: type) type {
        return struct {
            idx: Idx,
            data: []T,

            pub fn init(data: []T) @This() {
                var idx: Idx = undefined;
                c.glGenBuffers(1, &idx);

                c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
                c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(data)), &data, c.GL_DYNAMIC_DRAW);
                if (unbind_afterwards) c.glBindBuffer(core.c.GL_ARRAY_BUFFER, 0);
                return @This(){ .idx = idx, .data = data };
            }
        };
    }
    fn unbindVBO() void {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    }

    /// dont change the fields manualy
    pub fn VAO(comptime T: type) type {
        return struct {
            idx: Idx,
            attr: usize,
            data: VBO(T),
            size: usize,
            first: usize,
            stride: usize,

            pub fn init(attr: usize, vbo: VBO(T), size: usize, first: usize, stride: usize) @This() {
                c.glGenVertexArrays(1, &VAO);
                c.glBindVertexArray(VAO);

                c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo.idx);

                c.glVertexAttribPointer(attr, size, if (@typeInfo(T).float) c.GL_FLOAT else unreachable, c.GL_FALSE, stride * @sizeOf(f32), @ptrFromInt(first * @sizeOf(@TypeOf(T))));
                c.glEnableVertexAttribArray(attr);
                if (unbind_afterwards) c.glBindVertexArray(0);
                if (unbind_afterwards) unbindVBO();
            }
        };
    }
};

pub const Program = struct {
    idx: Idx,

    vertex: Shader,
    fragment: Shader,

    pub fn init(vertex: Shader, fragment: Shader) !@This() {
        const idx = c.glCreateProgram();
        c.glAttachShader(idx, vertex.idx);
        c.glAttachShader(idx, fragment.idx);
        c.glLinkProgram(idx);

        const this = @This(){
            .idx = idx,
            .vertex = vertex,
            .fragment = fragment,
        };

        try this.checkLinkStatus();

        return this;
    }

    fn checkLinkStatus(this: @This()) !void {
        var success: c_int = 0;
        var infoLog: [512]u8 = undefined;
        c.glGetProgramiv(this.idx, c.GL_LINK_STATUS, &success);
        if (success == 0) {
            c.glGetProgramInfoLog(this.idx, 512, null, &infoLog);
            _ = c.printf("ERROR::PROGRAM::LINKING_FAILED\n%s\n", &infoLog);
            return error.CompilationFailed;
        }
    }

    // pub fn setAttr() !void {}
};

pub const Shader = struct {
    idx: Idx,
    name: []const u8,
    T: Type,

    pub const Type = union(enum) {
        vertex,
        fragment,

        fn c_enum(this: @This()) c_int {
            return switch (this) {
                .vertex => c.GL_VERTEX_SHADER,
                .fragment => c.GL_FRAGMENT_SHADER,
            };
        }

        fn string(this: @This()) []const u8 {
            return switch (this) {
                .vertex => "VERTEX",
                .fragment => "FRAGMENT",
            };
        }
    };

    pub fn init(name: []const u8, T: Type) @This() {
        const idx = c.glCreateShader(T.c_enum());

        return @This(){
            .idx = idx,
            .name = name,
            .T = T,
        };
    }

    pub fn compile(this: @This(), io: std.Io, allocator: Allocator) !void {
        const postfix = switch (this.T) {
            .vertex => "vert",
            .fragment => "frag",
        };
        const path = try std.fmt.allocPrint(allocator, "res/shaders/{s}.{s}", .{ this.name, postfix });
        defer allocator.free(path);
        const code = try os.readShaderFile(path, io, allocator);
        defer allocator.free(code);

        c.glShaderSource(this.idx, 1, &code.ptr, null);
        c.glCompileShader(this.idx);
        try checkCompileStatus(this);
    }

    fn checkCompileStatus(this: @This()) error{CompilationFailed}!void {
        var success: c_int = 0;
        var infoLog: [512]u8 = undefined;

        c.glGetShaderiv(this.idx, c.GL_COMPILE_STATUS, &success);
        if (success == 0) {
            c.glGetShaderInfoLog(this.idx, 512, null, &infoLog);
            _ = c.printf("ERROR::SHADER::%s::COMPILATION_FAILED\n%s\n", this.T.string().ptr, &infoLog);
            return error.CompilationFailed;
        }
    }

    pub fn delete(this: @This()) void {
        c.glDeleteShader(this.idx);
    }
};

pub const GLSL = struct {
    pub const Types = enum {
        vec2,
        vec3,
        mat4,
    };
};
