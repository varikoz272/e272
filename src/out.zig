const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const panic = std.debug.panic;

pub fn printBgRed(x: u8, y: u8, r: u8) void {
    std.debug.print("\x1b[48;2;{d};{d};{d}m", .{ r, 0, 0 });
    std.debug.print("\x1b[{d};{d}H", .{ y, x });
    std.debug.print(" ", .{});
    std.debug.print("\x1b[0m", .{});
    std.debug.print("\x1b[1;1H", .{});
}
