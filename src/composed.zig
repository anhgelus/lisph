const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer/Lexer.zig");
const expression = @import("expression.zig");
const Expression = @import("eval/Expression.zig");
const expect = std.testing.expect;

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
    var content = try std.ArrayList(Expression).initCapacity(alloc, 2);
    var tok = l.peek();
    iter: while (tok) |it| : (tok = l.peek()) {
        try content.append(alloc, switch (it.kind) {
            .string_delimiter => {
                l.consume();
                break :iter;
            },
            .variable, .boolean, .number => try expression.parse(l, alloc),
            else => brk: {
                l.consume();
                break :brk (try Expression.String.init(alloc, it.content)).interface;
            },
        });
    }
    if (tok == null) return Errors.InvalidString;
    return try Expression.ComposedString.init(alloc, try content.toOwnedSlice(alloc));
}

test "string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var l = Lexer{ .iterator = .{ .bytes = "\"hey\"", .i = 0 } };
    _ = l.peek();
    var s = try parseString(&l, alloc);
    var res = try s.interface.eval(alloc, &dummy);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "hey"));

    l = Lexer{ .iterator = .{ .bytes = "\"123 hey\"", .i = 0 } };
    _ = l.peek();
    s = try parseString(&l, alloc);
    res = try s.interface.eval(alloc, &dummy);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "123 hey"));

    l = Lexer{ .iterator = .{ .bytes = "\"[] () hehe\"", .i = 0 } };
    _ = l.peek();
    s = try parseString(&l, alloc);
    res = try s.interface.eval(alloc, &dummy);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "[] () hehe"));

    l = Lexer{ .iterator = .{ .bytes = "\"invalid", .i = 0 } };
    _ = l.peek();
    try std.testing.expectError(
        Errors.InvalidString,
        parseString(&l, alloc),
    );

    //TODO: missing verifying escape
}

pub fn parseList(l: *Lexer, alloc: Allocator) !*Expression.List {
    l.consume();
    const list = try Expression.List.init(alloc);
    var tok = l.peek();
    while (tok) |it| : (tok = l.peek()) {
        if (it.kind == .list_end) break;
        try list.append(try expression.parse(l, alloc));
        if (!l.skipSeparator()) if (l.peek()) |p| if (p.kind != .list_end) return Errors.InvalidList;
    }
    if (tok == null) return Errors.InvalidList;
    l.consume();
    return list;
}

test "list" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var l = Lexer{ .iterator = .{ .bytes = "[]", .i = 0 } };
    _ = l.peek();
    var s = try parseList(&l, alloc);
    var res = try s.interface.eval(alloc, &dummy);
    try expect(res.as(Expression.List).len == 0);

    l = Lexer{ .iterator = .{ .bytes = "[foo]", .i = 0 } };
    _ = l.peek();
    s = try parseList(&l, alloc);
    var r = (try s.interface.eval(alloc, &dummy)).as(Expression.List);
    try expect(r.len == 1);
    try expect(r.content.first == r.content.last);
    var sub = Expression.List.Item.from(r.content.first.?);
    try expect(sub.content.typ == .string_literal);
    try expect(std.mem.eql(u8, sub.content.as(Expression.String).content, "foo"));

    l = Lexer{ .iterator = .{ .bytes = "[foo 123]", .i = 0 } };
    _ = l.peek();
    s = try parseList(&l, alloc);
    r = (try s.interface.eval(alloc, &dummy)).as(Expression.List);
    try expect(r.len == 2);
    try expect(r.content.first != r.content.last);
    sub = Expression.List.Item.from(r.content.first.?);
    try expect(sub.content.typ == .string_literal);
    try expect(std.mem.eql(u8, sub.content.as(Expression.String).content, "foo"));
    try expect(r.content.first.?.next == r.content.last);
    sub = Expression.List.Item.from(r.content.last.?);
    try expect(sub.content.typ == .number);
    try expect(sub.content.as(Expression.Number).content == 123);
}

pub fn parseVariable(l: *Lexer, alloc: Allocator) !Expression {
    l.consume();
    var tok = l.peek() orelse return Errors.InvalidVariable;
    // is an evaluate
    if (tok.kind == .function_beg) {
        const call = parseFunction(l, alloc) catch |err| switch (err) {
            Errors.InvalidFunction => return Errors.InvalidEvaluate,
            else => return err,
        };
        return (try Expression.variable.Evaluate.init(alloc, call)).interface;
    }
    const sep = tok.kind == .variable_beg;
    if (sep) {
        l.consume();
        tok = l.peek() orelse return Errors.InvalidVariable;
    }
    if (!tok.is_identifier) return Errors.InvalidVariable;
    l.consume();
    const name = tok.content;
    if (sep) {
        tok = l.next() orelse return Errors.InvalidVariable;
        if (tok.kind != .variable_end) return Errors.InvalidVariable;
    }
    return (try Expression.variable.Var.init(alloc, name)).interface;
}
