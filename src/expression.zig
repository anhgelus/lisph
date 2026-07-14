const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer/Lexer.zig");
const composed = @import("composed.zig");
const Expression = @import("eval/Expression.zig");

pub const Errors = error{
    InvalidExpression,
    InvalidString,
} || composed.Errors || std.fmt.ParseIntError || Allocator.Error;

pub fn parse(l: *Lexer, alloc: Allocator) Errors!Expression {
    const tok = l.peek() orelse return Errors.InvalidExpression;
    return switch (tok.kind) {
        .function_beg => (try composed.parseFunction(l, alloc)).interface,
        .boolean => (try parseBoolean(l, alloc)).interface,
        .number => (try parseNumber(l, alloc)).interface,
        .string_delimiter => (try composed.parseString(l, alloc)).interface,
        .string_content => (try parseLiteralString(l, alloc)).interface,
        .list_beg => (try composed.parseList(l, alloc)).interface,
        .variable => try composed.parseVariable(l, alloc),
        else => Errors.InvalidExpression,
    };
}

pub fn parseBoolean(l: *Lexer, alloc: Allocator) !*Expression.literal.Boolean {
    const tok = l.next().?;
    return try Expression.literal.Boolean.init(alloc, std.mem.eql(u8, tok.content, "true"));
}

pub fn parseNumber(l: *Lexer, alloc: Allocator) !*Expression.literal.Number {
    const tok = l.next().?;
    const i = try std.fmt.parseUnsigned(u64, tok.content, 0);
    return try Expression.literal.Number.init(alloc, i);
}

pub fn parseLiteralString(l: *Lexer, alloc: Allocator) !*Expression.literal.String {
    const tok = l.next().?;
    if (l.next()) |it| if (it.kind != .separator) return Errors.InvalidString;
    l.consume();
    return try Expression.literal.String.init(alloc, tok.content);
}
