const std = @import("std");
const Allocator = std.mem.Allocator;
const core = @import("e272.zig");
const MultiArrayList = std.MultiArrayList;

pub const Device = enum {
    Keyboard,
};

pub fn Listener(device: Device) type {
    return switch (device) {
        .Keyboard => struct {
            pub const Key = enum(c_int) { W = 87, A = 65, S = 83, D = 68 };

            // Define the callback function type explicitly
            pub const Callback = *const fn (*f32) void;
            // keys: std.ArrayList(Key),
            // callbacks: std.ArrayList(KeyCallback),
            input: MultiArrayList(struct { key: Key, callback: Callback }),
            allocator: Allocator,

            pub fn init(allocator: Allocator) @This() {
                return @This(){
                    // .keys = std.ArrayList(Key).empty,
                    // .callbacks = std.ArrayList(KeyCallback).empty,
                    .input = .empty,
                    .allocator = allocator,
                };
            }

            pub fn deinit(this: *@This()) void {
                this.input.deinit(this.allocator);
                // this.keys.deinit(this.allocator);
                // this.callbacks.deinit(this.allocator);
            }

            pub fn observe(this: *@This(), key: Key, callback: Callback) !void {
                try this.input.append(this.allocator, .{ .key = key, .callback = callback });
                // try this.keys.append(this.allocator, key);
                // try this.callbacks.append(this.allocator, callback);
            }

            pub fn check(this: *@This(), window: ?*core.c.struct_GLFWwindow, input: *f32) void {
                for (this.input.items(.key), 0..) |k, i| {
                    if (core.c.glfwGetKey(window, @intFromEnum(k)) == core.c.GLFW_PRESS)
                        this.input.items(.callback)[i](input);
                }
            }
        },
    };
}
