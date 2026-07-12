const std = @import("std");
const Lexer = @import("lexer/Lexer.zig");
const composed = @import("composed.zig");

const Script = struct {};

pub fn parse(content: []const u8) !Script {
    var lexer = Lexer{ .iterator = std.unicode.Utf8Iterator{
        .bytes = content,
        .i = 0,
    } };
    while (lexer.peek()) |_| {
        try composed.parseFunction(&lexer);
    }
    _ = lexer.next();
    return .{};
}

pub fn evaluate(s: Script) void {
    _ = s;
}

test {
    std.testing.refAllDecls(@This());
}
