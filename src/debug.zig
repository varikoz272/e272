const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const panic = std.debug.panic;

// TODO: fix windows behaviour on printing - text position is messed up

pub fn printBgRed(x: u8, y: u8, r: u8) void {
    std.debug.print("\x1b[48;2;{d};{d};{d}m", .{ r, 0, 0 });
    std.debug.print("\x1b[{d};{d}H", .{ y, x });
    std.debug.print(" ", .{});
    std.debug.print("\x1b[0m", .{});
    std.debug.print("\x1b[1;1H", .{});
}

pub fn log(comptime fmt: []const u8, args: anytype, comptime tags: anytype) void {
    std.debug.print("\x1b[97;106m   LOG   \x1b[0m", .{});
    printTags(tags);
    std.debug.print(" ", .{});
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

pub fn warn(comptime fmt: []const u8, args: anytype, comptime tags: anytype) void {
    std.debug.print("\x1b[97;103m WARNING \x1b[0m", .{});
    printTags(tags);
    std.debug.print(" ", .{});
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

pub fn err(comptime fmt: []const u8, args: anytype, comptime tags: anytype) void {
    std.debug.print("\x1b[97;101m  ERROR  \x1b[0m", .{});
    printTags(tags);
    std.debug.print(" ", .{});
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

fn printTags(comptime tags: anytype) void {
    const tuple = @typeInfo(@TypeOf(tags)).@"struct";
    const array = tuple.fields;
    inline for (array) |tag| {
        const string: []const u8 = @field(tags, tag.name);
        const bg: u4 = blk: {
            var sum: usize = 0;
            for (0..string.len) |i|
                sum *%= string[i];
            break :blk @truncate(sum);
        };
        const fg: u4 = switch (bg) {
            7 => 0,
            else => 7,
        };
        std.debug.print("\x1b[{d};{d}m {s} \x1b[0m", .{ 90 + @as(u8, fg), 100 + @as(u8, bg), string });
    }
}
