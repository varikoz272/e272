const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.Random;
const env = @import("../environment.zig");
const Body = env.Body(floor_dimentions, FloorType);
const Rng = std.Random.DefaultPrng;

scale: *env.Scale(floor_dimentions, FloorType),
tiles: *TilesType,
allocator: Allocator,
generator: TileGenerator,

const TilesType = std.HashMap(Body, Tile, tiles_hash_context, std.hash_map.default_max_load_percentage);
const tiles_hash_context = struct {
    pub fn hash(_: @This(), body: Body) u64 {
        return (@as(u64, body.x()) << 32 & 0xFFFFFFFF00000000) | (body.y() & 0xFFFFFFFF);
    }

    pub fn eql(_: @This(), b1: Body, b2: Body) bool {
        return b1.x() == b2.x() and b1.y() == b2.y();
    }
};

const FloorType = u32;
const floor_dimentions: usize = 2;

pub fn init(width: usize, height: usize, seed: u64, allocator: Allocator) @This() {
    const tiles = allocator.create(TilesType) catch unreachable;
    tiles.* = .init(allocator);

    const scale = allocator.create(env.Scale(floor_dimentions, FloorType)) catch unreachable;
    scale.* = .init(@truncate(width), @truncate(height), .meter);

    return @This(){
        .allocator = allocator,
        .scale = scale,
        .tiles = tiles,
        .generator = .init(seed, tiles, @constCast(&TileGenerator.default_at)),
    };
}

pub fn destroy(this: *@This()) void {
    this.generator.tiles.deinit();
    this.allocator.destroy(this.tiles);
    this.allocator.destroy(this.scale);
}

const TileGenerator = struct {
    seed: u64,
    rng: Rng,
    tiles: *TilesType,
    at_fn: *fn (@This(), x: FloorType, y: FloorType) Tile,

    pub fn init(seed: u64, tiles: *TilesType, at_fn: *fn (@This(), x: FloorType, y: FloorType) Tile) @This() {
        const rng = Rng.init(seed);
        return @This(){
            .seed = seed,
            .rng = rng,
            .tiles = tiles,
            .at_fn = at_fn,
        };
    }

    pub fn at(this: @This(), x: FloorType, y: FloorType) Tile {
        const body: Body = .init(x, y, .meter);
        if (this.tiles.get(body)) |tile| return tile;

        const tile = this.at_fn(this, x, y);
        this.tiles.put(body, tile) catch unreachable;
        return tile;
    }

    pub fn default_at(_: @This(), _: FloorType, _: FloorType) Tile {
        return .init(.sand);
    }
};

pub const TileType = enum { sand };

pub const Tile = struct {
    T: TileType,

    pub fn init(T: TileType) @This() {
        return @This(){
            .T = T,
        };
    }
};
