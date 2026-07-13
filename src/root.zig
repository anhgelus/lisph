const std = @import("std");
const Lexer = @import("lexer/Lexer.zig");
const Expression = @import("eval/Expression.zig");
const composed = @import("composed.zig");

const Script = struct {
    root: []*Expression.function.Call,
};

pub fn parse(alloc: std.mem.Allocator, content: []const u8) !Script {
    var lexer = Lexer{ .iterator = std.unicode.Utf8Iterator{
        .bytes = content,
        .i = 0,
    } };
    var root = try std.ArrayList(*Expression.function.Call).initCapacity(alloc, 2);
    while (lexer.peek()) |_| {
        try root.append(alloc, try composed.parseFunction(&lexer, alloc));
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
