const std = @import("std");
const t = std.testing;
const e = @import("e272");

test "true" {
    const allocator = std.testing.allocator;

    // Build the underlying threaded IO mapping
    const io = t.io;
    // Pass mock_init to your functions
    try e.run(io, allocator);
}
