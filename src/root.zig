const std = @import("std");
const Lexer = @import("lexer/Lexer.zig");
const Expression = @import("eval/Expression.zig");
const composed = @import("composed.zig");

const Script = struct {
    root: []Expression.Root,
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
    _ = lexer.next();
    return .{ .root = try root.toOwnedSlice(alloc) };
}

pub fn evaluate(_: std.mem.Allocator, s: Script) void {
    _ = s;
}

test {
    std.testing.refAllDecls(@This());
}
