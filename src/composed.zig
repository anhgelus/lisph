const std = @import("std");
const Lexer = @import("lexer/Lexer.zig");
const expression = @import("expression.zig");

pub const Errors = error{ InvalidFunction, InvalidList };

pub fn parseFunction(l: *Lexer) !void {
    var tok = l.next().?;
    const hard_finish = tok.kind == .function_beg;
    if (hard_finish) tok = l.next() orelse return Errors.InvalidFunction;
    if (!tok.is_identifier) return Errors.InvalidFunction;
    if (std.mem.containsAtLeast(u8, tok.content, 1, "\""))
        return Errors.InvalidFunction;
    const id = tok.content;
    _ = id;
    while (l.next()) |it| {
        if (hard_finish and it.kind == .function_end) break;
        if (!hard_finish and it.kind == .function_separator and it.content.len >= 2) break;
        try expression.parse(l);
        if (!l.skipSeparator()) return Errors.InvalidFunction;
    }
}

pub fn parseString(l: *Lexer) !void {
    l.consume();
    while (l.next()) |it| {
        if (it.kind == .string_delimiter) break;
    }
}

pub fn parseList(l: *Lexer) !void {
    l.consume();
    while (l.next()) |it| {
        if (it.kind == .list_end) break;
        try expression.parse(l);
        if (!l.skipSeparator()) return Errors.InvalidList;
    }
}
