const std = @import("std");
const Allocator = std.mem.Allocator;
const lisph = @import("lisph-interpreter");
const definitions = @import("core/definitions.zig");

pub fn register(alloc: Allocator, ctx: *lisph.Context) !void {
    try definitions.Defn.register(alloc, ctx);
    try definitions.Lambda.register(alloc, ctx);
    try definitions.Type.register(alloc, ctx);
}

test {
    std.testing.refAllDecls(@This());
}
