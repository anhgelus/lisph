const std = @import("std");
const Lexer = @import("lexer/Lexer.zig");

const Script = struct {};

pub fn parse(content: []const u8) Script {
    var lexer = Lexer{ .iterator = std.unicode.Utf8Iterator{
        .bytes = content,
        .i = 0,
    } };
    _ = lexer.next();
    return .{};
}

pub fn evaluate(s: Script) void {
    _ = s;
}

test {
    std.testing.refAllDecls(@This());
}
