const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer/Lexer.zig");
const expression = @import("expression.zig");
const Expression = @import("eval/Expression.zig");

pub const Errors = error{
    InvalidFunction,
    InvalidList,
    InvalidString,
    InvalidVariable,
    InvalidEvaluate,
};

pub fn parseFunction(l: *Lexer, alloc: Allocator) !*Expression.function.Call {
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
    return try Expression.function.Call.init(alloc, id, try args.toOwnedSlice(alloc));
}

pub fn parseString(l: *Lexer, alloc: Allocator) !*Expression.ComposedString {
    l.consume();
    var tok = l.peek();
    var content = try std.ArrayList(Expression).initCapacity(alloc, 2);
    iter: while (tok) |it| : (tok = l.peek()) {
        try content.append(alloc, switch (it.kind) {
            .string_delimiter => {
                l.consume();
                break :iter;
            },
            .variable, .boolean, .string_content, .separator, .number => try expression.parse(l, alloc),
            else => return Errors.InvalidString,
        });
    }
    if (tok == null) return Errors.InvalidString;
    return try Expression.ComposedString.init(alloc, try content.toOwnedSlice(alloc));
}

pub fn parseList(l: *Lexer, alloc: Allocator) !*Expression.List {
    l.consume();
    const list = try Expression.List.init(alloc);
    var tok = l.next();
    while (tok) |it| : (tok = l.next()) {
        if (it.kind == .list_end) break;
        try list.append(try expression.parse(l, alloc));
        if (!l.skipSeparator()) if (l.peek()) |p| if (p.kind != .list_end) return Errors.InvalidList;
    }
    if (tok == null) return Errors.InvalidList;
    return list;
}

pub fn parseVariable(l: *Lexer, alloc: Allocator) !void {
    l.consume();
    const tok = l.peek() orelse return Errors.InvalidVariable;
    // is an evaluate
    if (tok.kind == .function_beg) {
        _ = try parseFunction(l, alloc);
    }
    if (!tok.is_identifier) return Errors.InvalidVariable;
}
