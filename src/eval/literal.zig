const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");
const expect = std.testing.expect;

pub const String = Expression.Literal([]const u8, .string);

test "string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = std.testing.io;

    var dummy = Expression.Context.dummy(alloc);

    var s = try String.init(alloc, "");
    var res = try s.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .string);
    try expect(res.as(String).content.len == 0);

    s = try String.init(alloc, "hello world");
    res = try s.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .string);
    try expect(std.mem.eql(u8, res.as(String).content, "hello world"));
}

pub const Number = Expression.Literal(u64, .number);

test "number" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = std.testing.io;

    var dummy = Expression.Context.dummy(alloc);

    var s = try Number.init(alloc, 0);
    var res = try s.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .number);
    try expect(res.as(Number).content == 0);

    s = try Number.init(alloc, 2345678);
    res = try s.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .number);
    try expect(res.as(Number).content == 2345678);
}

pub const Boolean = Expression.Literal(bool, .boolean);

test "boolean" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = std.testing.io;

    var dummy = Expression.Context.dummy(alloc);

    var s = try Boolean.init(alloc, false);
    var res = try s.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .boolean);
    try expect(!res.as(Boolean).content);

    s = try Boolean.init(alloc, true);
    res = try s.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .boolean);
    try expect(res.as(Boolean).content);
}
