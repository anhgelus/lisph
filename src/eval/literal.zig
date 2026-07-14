const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");
const expect = std.testing.expect;

pub const String = struct {
    content: []const u8,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{
            .eval = eval,
        },
        .typ = .string_literal,
    },

    const Self = @This();

    pub fn init(alloc: Allocator, content: []const u8) !*Self {
        const self = try alloc.create(Self);
        self.* = .{ .content = content };
        self.interface.ptr = self;
        return self;
    }

    pub fn eval(ptr: *anyopaque, _: Allocator, _: *Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.interface;
    }
};

test "string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var s = try String.init(alloc, "");
    var res = try s.interface.eval(alloc, &dummy);
    try expect(res.typ == .string_literal);
    try expect(res.as(String).content.len == 0);

    s = try String.init(alloc, "hello world");
    res = try s.interface.eval(alloc, &dummy);
    try expect(res.typ == .string_literal);
    try expect(std.mem.eql(u8, res.as(String).content, "hello world"));
}

pub const Number = struct {
    content: u64,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{
            .eval = eval,
        },
        .typ = .number,
    },

    const Self = @This();

    pub fn init(alloc: Allocator, content: u64) !*Self {
        const self = try alloc.create(Self);
        self.* = .{ .content = content };
        self.interface.ptr = self;
        return self;
    }

    pub fn eval(ptr: *anyopaque, _: Allocator, _: *Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.interface;
    }
};

test "number" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var s = try Number.init(alloc, 0);
    var res = try s.interface.eval(alloc, &dummy);
    try expect(res.typ == .number);
    try expect(res.as(Number).content == 0);

    s = try Number.init(alloc, 2345678);
    res = try s.interface.eval(alloc, &dummy);
    try expect(res.typ == .number);
    try expect(res.as(Number).content == 2345678);
}

pub const Boolean = struct {
    content: bool,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{
            .eval = eval,
        },
        .typ = .boolean,
    },

    const Self = @This();

    pub fn init(alloc: Allocator, content: bool) !*Self {
        const self = try alloc.create(Self);
        self.* = .{ .content = content };
        self.interface.ptr = self;
        return self;
    }

    pub fn eval(ptr: *anyopaque, _: Allocator, _: *Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.interface;
    }
};

test "boolean" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var s = try Boolean.init(alloc, false);
    var res = try s.interface.eval(alloc, &dummy);
    try expect(res.typ == .boolean);
    try expect(!res.as(Boolean).content);

    s = try Boolean.init(alloc, true);
    res = try s.interface.eval(alloc, &dummy);
    try expect(res.typ == .boolean);
    try expect(res.as(Boolean).content);
}
