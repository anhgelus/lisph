const std = @import("std");
const Lexer = @import("lexer/Lexer.zig");
const expression = @import("expression.zig");
const Expression = @import("eval/Expression.zig");

pub const Errors = error{ InvalidFunction, InvalidList };

pub fn parseFunction(l: *Lexer, alloc: std.mem.Allocator) !*Expression.Function.Call {
    var tok = l.next().?;
    const hard_finish = tok.kind == .function_beg;
    if (hard_finish) tok = l.next() orelse return Errors.InvalidFunction;
    if (!tok.is_identifier) return Errors.InvalidFunction;
    const id = tok.content;
    var args = try std.ArrayList(Expression).initCapacity(alloc, 2);
    tok = l.next() orelse return Errors.InvalidFunction;
    if (tok.kind != .separator) return Errors.InvalidFunction;
    while (l.next()) |it| {
        if (hard_finish and it.kind == .function_end) break;
        if (!hard_finish and it.kind == .function_separator and it.content.len >= 2) break;
        try args.append(alloc, try expression.parse(l, alloc));
        if (!l.skipSeparator()) return Errors.InvalidFunction;
    }
    return try Expression.Function.Call.init(alloc, id, try args.toOwnedSlice(alloc));
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
