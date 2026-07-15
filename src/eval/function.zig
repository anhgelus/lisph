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

    pub fn eval(ptr: *anyopaque, parent: Allocator, ctx: *Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const body = ctx.functions.get(self.ref.content) orelse return Expression.Errors.UnknownFunction;
        var arena = std.heap.ArenaAllocator.init(parent);
        defer arena.deinit();
        const alloc = arena.allocator();
        var sub = Expression.Context{
            .functions = ctx.functions,
            .variables = try ctx.variables.cloneWithAllocator(alloc),
        };
        if (body.deconstruct_args) {
            if (body.args.len != self.args.len) return Expression.Errors.InvalidFunctionArguments;
            for (0.., body.args) |i, k| try sub.variables.put(k, self.args[i]);
        } else {
            if (body.args.len != 1) @panic("internal invalid function definition");
            const l = try Expression.List.init(alloc);
            for (self.args) |arg| try l.append(arg);
            try sub.variables.put(body.args[0], l.interface);
        }
        return try body.eval(alloc, &sub);
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

    var dummy = Expression.Context.init(alloc);

    var f = try Def.init(
        &[_][]const u8{"args"},
        false,
        (try Ref.init(alloc, "uwu")).interface,
    );
    try dummy.functions.put("foo", &f);
    const ref = try Ref.init(alloc, "foo");

    var c = try Call.init(alloc, ref, &[_]Expression{});
    var res = try c.interface.eval(alloc, &dummy);
    try expect(res.typ == .reference);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "uwu"));

    f = try Def.init(
        &[_][]const u8{"val"},
        true,
        (try Expression.variable.Var.init(alloc, "val")).interface,
    );

    c = try Call.init(
        alloc,
        ref,
        &[_]Expression{(try Expression.Number.init(alloc, 0)).interface},
    );
    res = try c.interface.eval(alloc, &dummy);
    try expect(res.typ == .number);
    try expect(res.as(Expression.Number).content == 0);

    c = try Call.init(
        alloc,
        ref,
        &[_]Expression{(try Expression.Boolean.init(alloc, true)).interface},
    );
    res = try c.interface.eval(alloc, &dummy);
    try expect(res.typ == .boolean);
    try expect(res.as(Expression.Boolean).content == true);
}

pub const Def = struct {
    args: []const []const u8,
    deconstruct_args: bool,
    body: Expression,

    const Self = @This();

    pub fn init(args: []const []const u8, deconstruct_args: bool, body: Expression) !Self {
        return .{
            .args = args,
            .deconstruct_args = deconstruct_args,
            .body = body,
        };
    }

    pub fn eval(self: Self, alloc: Allocator, ctx: *Expression.Context) Expression.Errors!Expression {
        return try self.body.eval(alloc, ctx);
    }
};

test "def_ref" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var s = try Def.init(
        &[_][]const u8{},
        false,
        (try Ref.init(alloc, "uwu")).interface,
    );
    var res = try s.eval(alloc, &dummy);
    try expect(res.typ == .reference);
    try expect(std.mem.eql(u8, res.as(Ref).content, "uwu"));
}

pub const Ref = Expression.Literal([]const u8, .reference);
