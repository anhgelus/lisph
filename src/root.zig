const std = @import("std");
const Allocator = std.mem.Allocator;
const lisph = @import("interpreter");
const definitions = @import("core/definitions.zig");
const types = @import("core/types.zig");

pub fn register(alloc: Allocator, ctx: *lisph.Context) !void {
    // core
    try definitions.Defn.register(alloc, ctx);
    try definitions.Lambda.register(alloc, ctx);
    try definitions.Set.register(alloc, ctx);
    try definitions.Export.register(alloc, ctx);
    try types.Type.register(alloc, ctx);
    try types.String.register(alloc, ctx);
    try types.Number.register(alloc, ctx);
    try types.Boolean.register(alloc, ctx);
}

test {
    std.testing.refAllDecls(@This());
}
