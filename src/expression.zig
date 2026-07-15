const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer/Lexer.zig");
const composed = @import("composed.zig");
const Expression = @import("eval/Expression.zig");
const expect = std.testing.expect;

pub const Errors = error{
    InvalidExpression,
    InvalidString,
} || composed.Errors || std.fmt.ParseIntError || Allocator.Error;

pub fn parse(l: *Lexer, alloc: Allocator) Errors!Expression {
    const tok = l.peek() orelse return Errors.InvalidExpression;
    return switch (tok.kind) {
        .function_beg => (try composed.parseFunction(l, alloc)).interface,
        .reference => (try composed.parseReference(l, alloc)).interface,
        .boolean => (try parseBoolean(l, alloc)).interface,
        .number => (try parseNumber(l, alloc)).interface,
        .string_delimiter => (try composed.parseString(l, alloc)).interface,
        .string_content => (try parseLiteralString(l, alloc)).interface,
        .list_beg => (try composed.parseList(l, alloc)).interface,
        .variable => try composed.parseVariable(l, alloc),
        else => Errors.InvalidExpression,
    };
}

pub fn parseBoolean(l: *Lexer, alloc: Allocator) !*Expression.Boolean {
    const tok = l.next().?;
    return try Expression.Boolean.init(alloc, std.mem.eql(u8, tok.content, "true"));
}

test "boolean" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var l = Lexer{ .iterator = .{ .bytes = "true", .i = 0 } };
    var s = try parseBoolean(&l, alloc);
    var res = try s.interface.eval(alloc, &dummy);
    try expect(res.as(Expression.Boolean).content);

    l = Lexer{ .iterator = .{ .bytes = "false", .i = 0 } };
    s = try parseBoolean(&l, alloc);
    res = try s.interface.eval(alloc, &dummy);
    try expect(!res.as(Expression.Boolean).content);
}

pub fn parseNumber(l: *Lexer, alloc: Allocator) !*Expression.Number {
    const tok = l.next().?;
    const i = try std.fmt.parseUnsigned(u64, tok.content, 0);
    return try Expression.Number.init(alloc, i);
}

test "number" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var l = Lexer{ .iterator = .{ .bytes = "0", .i = 0 } };
    var s = try parseNumber(&l, alloc);
    var res = try s.interface.eval(alloc, &dummy);
    try expect(res.as(Expression.Number).content == 0);

    l = Lexer{ .iterator = .{ .bytes = "10", .i = 0 } };
    s = try parseNumber(&l, alloc);
    res = try s.interface.eval(alloc, &dummy);
    try expect(res.as(Expression.Number).content == 10);

    l = Lexer{ .iterator = .{ .bytes = "6234567", .i = 0 } };
    s = try parseNumber(&l, alloc);
    res = try s.interface.eval(alloc, &dummy);
    try expect(res.as(Expression.Number).content == 6234567);
}

pub fn parseLiteralString(l: *Lexer, alloc: Allocator) !*Expression.String {
    const tok = l.next().?;
    //if (l.peek()) |it| if (it.kind != .separator) return Errors.InvalidString;
    return try Expression.String.init(alloc, tok.content);
}

test "string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var l = Lexer{ .iterator = .{ .bytes = "hey", .i = 0 } };
    var s = try parseLiteralString(&l, alloc);
    var res = try s.interface.eval(alloc, &dummy);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "hey"));

    l = Lexer{ .iterator = .{ .bytes = "hello_world-éè ", .i = 0 } };
    s = try parseLiteralString(&l, alloc);
    res = try s.interface.eval(alloc, &dummy);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "hello_world-éè"));
}
