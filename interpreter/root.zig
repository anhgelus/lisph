const std = @import("std");
const Lexer = @import("lexer/Lexer.zig");
pub const Expression = @import("eval/Expression.zig");
const composed = @import("composed.zig");
pub const Context = Expression.Context;

const Script = struct {
    root: []Expression.Root,

    pub fn run(self: @This(), alloc: std.mem.Allocator, io: std.Io, ctx: *Context) !void {
        for (self.root) |it| {
            try it.eval(alloc, io, ctx);
        }
    }
};

pub fn parse(alloc: std.mem.Allocator, content: []const u8) !Script {
    var lexer = Lexer{ .iterator = std.unicode.Utf8Iterator{
        .bytes = content,
        .i = 0,
    } };
    var root = try std.ArrayList(Expression.Root).initCapacity(alloc, 2);
    while (lexer.peek()) |_| {
        const expr = try composed.parseFunction(&lexer, alloc);
        try root.append(alloc, .{ .expr = expr.interface });
    }
    return .{ .root = try root.toOwnedSlice(alloc) };
}

test {
    std.testing.refAllDecls(@This());
}
