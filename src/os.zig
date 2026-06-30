const std = @import("std");
const Allocator = std.mem.Allocator;
const core = @import("e272.zig");

window: Window,

pub const Window = struct {
    width: usize,
    height: usize,
    c_window: ?*core.c.GLFWwindow,

    pub fn init(width: usize, height: usize) !@This() {
        if (core.c.glfwInit() == 0) {
            _ = core.c.printf("Failed to initialize GLFW\n");
            return error.GLFWInitFailed;
        }

        core.c.glfwWindowHint(core.c.GLFW_CONTEXT_VERSION_MAJOR, 4);
        core.c.glfwWindowHint(core.c.GLFW_CONTEXT_VERSION_MINOR, 5);
        core.c.glfwWindowHint(core.c.GLFW_OPENGL_PROFILE, core.c.GLFW_OPENGL_CORE_PROFILE);

        const c_width: c_int = @intCast(@as(u32, (@truncate(width))));
        const c_height: c_int = @intCast(@as(u32, (@truncate(height))));

        const window = core.c.glfwCreateWindow(c_width, c_height, "Zig Sprite Renderer", null, null);
        if (window == null) {
            _ = core.c.printf("Failed to create GLFW window\n");
            return error.GLFWWindowCreationFailed;
        }

        core.c.glfwMakeContextCurrent(window);
        _ = core.c.glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

        return @This(){
            .width = width,
            .height = height,
            .c_window = window,
        };
    }

    fn framebuffer_size_callback(window: ?*core.c.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
        core.c.glViewport(0, 0, width, height);
        _ = window;
    }

    pub fn deinit(this: @This()) void {
        core.c.glfwDestroyWindow(this.c_window);
        core.c.glfwTerminate();
    }
};

pub fn readShaderFile(file_path: []const u8, io: std.Io, allocator: Allocator) ![:0]u8 {
    var file = try std.Io.Dir.cwd().openFile(io, file_path, .{});
    defer file.close(io);

    // Fetch the file size to allocate the exact amount of memory
    const stat = try file.stat(io);
    if (stat.size == 0) return error.EmptyFile;

    // Allocate exact size (no +1 yet)
    var buffer = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(buffer);

    // Read everything directly into the allocated memory block
    const bytes_read = try file.readPositionalAll(io, buffer, 0);

    // Trim to actual bytes read (in case it's less than stat.size)
    const actual_size = bytes_read;
    if (actual_size != stat.size) {
        // Reallocate to actual size if needed
        buffer = try allocator.realloc(buffer, actual_size);
    }

    // Now create null-terminated version
    var null_terminated = try allocator.alloc(u8, actual_size + 1);
    errdefer allocator.free(null_terminated);

    @memcpy(null_terminated[0..actual_size], buffer[0..actual_size]);
    null_terminated[actual_size] = 0;

    // Free the original buffer
    allocator.free(buffer);

    // std.debug.print("Dynamic file content: {s}\n", .{null_terminated});

    return null_terminated[0..actual_size :0];
}
