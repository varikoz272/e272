const std = @import("std");
const core = @import("e272.zig");

pub const DimentionUnit = enum {
    meter,
};

/// an physical entity that belongs to Scene
pub fn Body(comptime dimentions: usize, comptime T: type) type {
    if (dimentions != 2) @compileError("Only 2 dimentions are supported");

    return struct {
        pos: [dimentions]T,
        unit: DimentionUnit,

        pub fn init(x_: T, y_: T, unit: DimentionUnit) @This() {
            return @This(){
                .pos = [dimentions]T{ x_, y_ },
                .unit = unit,
            };
        }

        pub fn x(this: @This()) T {
            return this.pos[0];
        }

        pub fn y(this: @This()) T {
            return this.pos[1];
        }
    };
}

pub fn Scale(comptime dimentions: usize, comptime T: type) type {
    if (dimentions != 2) @compileError("Only 2 dimentions are supported");

    return struct {
        size: [dimentions]T,
        unit: DimentionUnit,

        pub fn init(x: T, y: T, unit: DimentionUnit) @This() {
            return @This(){
                .size = [dimentions]T{ x, y },
                .unit = unit,
            };
        }

        pub fn width(this: @This()) T {
            return this.size[0];
        }

        pub fn height(this: @This()) T {
            return this.size[1];
        }
    };
}

pub fn Camera(comptime dimentions: usize, comptime T: type) type {
    return struct {
        body: Body(dimentions, T),

        pub fn init(body: Body(T, dimentions)) @This() {
            return @This(){
                .body = body,
            };
        }
    };
}
