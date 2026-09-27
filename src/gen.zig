const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const panic = std.debug.panic;
const rng = std.Random;

const noise = @import("fastnoise.zig");

pub const Map2 = struct {
    gen: noise.Noise(f32),

    pub fn init(seed: i32) @This() {
        const gen = noise.Noise(f32){ .seed = seed };
        return @This(){
            .gen = gen,
        };
    }

    pub fn at(this: @This(), x: f32, y: f32) f32 {
        return this.gen.genNoise2D(x, y);
    }
};
