const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");
const expect = std.testing.expect;

pub const Variable = struct {
    name: []const u8,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{
            .eval = eval,
        },
        .typ = .variable,
    },

    const Self = @This();

    pub fn init(alloc: Allocator, name: []const u8) !*Self {
        const self = try alloc.create(Self);
        self.* = .{ .name = name };
        self.interface.ptr = self;
        return self;
    }

    pub fn eval(ptr: *anyopaque, alloc: Allocator, ctx: *Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const res = ctx.variables.get(self.name) orelse return Expression.Errors.UnknownVariable;
        return try res.eval(alloc, ctx);
    }

    pub fn set(self: *Self, alloc: Allocator, ctx: *Expression.Context, value: Expression) !void {
        var res: ?Expression = null;
        if (!ctx.variables.contains(self.name)) {
            res = try value.eval(alloc, ctx);
            self.interface.typ = res.?.typ;
        }
        if (self.interface.typ != value.typ) return Expression.Errors.InvalidCast;
        if (res == null) res = try value.eval(alloc, ctx);
        try ctx.variables.put(self.name, res.?);
    }
};

test "var eval" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);
    try dummy.variables.put("foo", (try Expression.String.init(alloc, "bar")).interface);

    var v = try Variable.init(alloc, "foo");
    var res = try v.interface.eval(alloc, &dummy);
    try expect(res.typ == .string);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "bar"));

    v = try Variable.init(alloc, "bar");
    try std.testing.expectError(
        Expression.Errors.UnknownVariable,
        v.interface.eval(alloc, &dummy),
    );
}

test "var set" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var v = try Variable.init(alloc, "foo");
    try v.set(alloc, &dummy, (try Expression.String.init(alloc, "bar")).interface);
    var res = try v.interface.eval(alloc, &dummy);
    try expect(res.typ == .string);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "bar"));

    v = try Variable.init(alloc, "foo");
    try std.testing.expectError(
        Expression.Errors.InvalidCast,
        v.set(alloc, &dummy, (try Expression.Number.init(alloc, 0)).interface),
    );
}

pub const Evaluate = struct {
    call: *Expression.Function,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{
            .eval = eval,
        },
        .typ = .evaluate,
    },

    const Self = @This();

    pub fn init(alloc: Allocator, call: *Expression.Function) !*Self {
        const self = try alloc.create(Self);
        self.* = .{ .call = call };
        self.interface.ptr = self;
        return self;
    }

    pub fn eval(ptr: *anyopaque, alloc: Allocator, ctx: *Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return try self.call.interface.eval(alloc, ctx);
    }
};
