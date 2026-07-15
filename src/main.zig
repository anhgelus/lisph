const std = @import("std");
const lisph = @import("lisph-interpreter");

pub fn main(init: std.process.Init) !void {
    var iter = try init.minimal.args.iterateAllocator(init.gpa);
    defer iter.deinit();
    _ = iter.skip();
    const alloc = init.arena.allocator();
    var ctx = lisph.Context.init(alloc, init.environ_map.*);
    if (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-c")) {
            const r = iter.next() orelse @panic("requires an argument after '-c'");
            if (iter.skip()) @panic("only one argument can be used with '-c'");
            var script = try lisph.parse(alloc, r);
            try script.run(alloc, init.io, &ctx);
            return;
        }
        try handleFile(init, &ctx, arg);
        while (iter.next()) |a| try handleFile(init, &ctx, a);
    } else {}
}

fn handleFile(init: std.process.Init, ctx: *lisph.Context, file: []const u8) !void {
    const alloc = init.arena.allocator();
    const b = try std.Io.Dir
        .cwd()
        .readFileAlloc(init.io, file, alloc, .unlimited);
    const script = try lisph.parse(alloc, b);
    try script.run(alloc, init.io, ctx);
}
