const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const panic = std.debug.panic;
const rng = std.Random;

const noise = @import("fastnoise.zig");

pub const Map2 = struct {
    gen: noise.Noise(f32),
    min: f32,
    max: f32,

    pub const Noise = struct {
        const SharpPatches = noise.Noise(f32){
            .noise_type = .cellular,
            .frequency = 0.15,

            .fractal_type = .none,

            .cellular_distance = .hybrid,
            .cellular_return = .cell_value,

            .domain_warp_amp = 1.0,
            .domain_warp_type = .simplex,
        };
    };

    pub fn init(seed: i32, min: f32, max: f32) @This() {
        var gen = Noise.SharpPatches;
        gen.seed = seed;
        return @This(){
            .gen = gen,
            .min = min,
            .max = max,
        };
    }

    pub fn at(this: @This(), x: f32, y: f32) f32 {
        return this.gen.genNoise2DRange(x, y, f32, this.min, this.max);
    }
};
