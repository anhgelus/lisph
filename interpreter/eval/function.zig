const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");
const expect = std.testing.expect;

pub const Call = struct {
    ref: *Ref,
    args: []const Expression,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{
            .eval = eval,
        },
        .typ = .function,
    },

    const Self = @This();

    pub fn init(alloc: Allocator, ref: *Ref, args: []const Expression) !*Self {
        const self = try alloc.create(Self);
        self.* = .{ .ref = ref, .args = args };
        self.interface.ptr = self;
        return self;
    }

    pub fn eval(ptr: *anyopaque, alloc: Allocator, io: std.Io, ctx: *Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const body = try ctx.getFunction(alloc, self.ref.content);
        if (body.deconstruct_args) {
            if (body.args.len != self.args.len) return Expression.Errors.InvalidFunctionArguments;
            for (0.., body.args) |i, k| try ctx.variables.put(k, self.args[i]);
        } else {
            std.debug.assert(body.args.len == 1);
            const l = try Expression.List.init(alloc);
            for (self.args) |arg| try l.append(arg);
            try ctx.variables.put(body.args[0], l.interface);
        }
        return try body.eval(alloc, io, ctx);
    }

    pub fn from(expr: Expression) Expression.Errors.InvalidCast!*Self {
        if (expr.typ != .function) return Expression.Errors.InvalidCast;
        return @ptrCast(@alignCast(expr.ptr));
    }
};

test "call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = std.testing.io;

    var dummy = Expression.Context.dummy(alloc);

    var f = Def.init(
        &[_][]const u8{"args"},
        false,
        (try Ref.init(alloc, KindRef{ .basic = "uwu" })).interface,
    );
    try dummy.functions.put("foo", &f);
    const ref = try Ref.init(alloc, KindRef{ .basic = "foo" });

    var c = try Call.init(alloc, ref, &[_]Expression{});
    var res = try c.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .reference);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "uwu"));

    f = Def.init(
        &[_][]const u8{"val"},
        true,
        (try Expression.Variable.init(alloc, "val")).interface,
    );

    c = try Call.init(
        alloc,
        ref,
        &[_]Expression{(try Expression.Number.init(alloc, 0)).interface},
    );
    res = try c.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .number);
    try expect(res.as(Expression.Number).content == 0);

    c = try Call.init(
        alloc,
        ref,
        &[_]Expression{(try Expression.Boolean.init(alloc, true)).interface},
    );
    res = try c.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .boolean);
    try expect(res.as(Expression.Boolean).content == true);
}

pub const Def = struct {
    args: []const []const u8,
    deconstruct_args: bool,
    body: Expression,

    const Self = @This();

    pub fn init(args: []const []const u8, deconstruct_args: bool, body: Expression) Self {
        return .{
            .args = args,
            .deconstruct_args = deconstruct_args,
            .body = body,
        };
    }

    pub fn eval(self: Self, alloc: Allocator, io: std.Io, ctx: *Expression.Context) Expression.Errors!Expression {
        return try self.body.eval(alloc, io, ctx);
    }
};

test "def_ref" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = std.testing.io;

    var dummy = Expression.Context.dummy(alloc);

    var s = Def.init(
        &[_][]const u8{},
        false,
        (try Ref.init(alloc, KindRef{ .basic = "uwu" })).interface,
    );
    var res = try s.eval(alloc, io, &dummy);
    try expect(res.typ == .reference);
    try expect(std.mem.eql(u8, res.as(Ref).content.basic, "uwu"));
}

pub const KindRef = union(enum) {
    basic: []const u8,
    lambda: Def,
};

pub const Ref = Expression.Literal(KindRef, .reference);
