const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");

pub const Call = struct {
    ref: *Ref,
    args: []Expression,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{
            .eval = eval,
        },
        .typ = .function,
    },

    const Self = @This();

    pub fn init(alloc: Allocator, ref: *Ref, args: []Expression) !*Self {
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

pub const Def = struct {
    name: []const u8,
    args: [][]const u8,
    deconstruct_args: bool,
    body: Expression,

    const Self = @This();

    pub fn init(name: []const u8, args: [][]const u8, deconstruct_args: bool, body: Expression) !Self {
        return .{
            .name = name,
            .args = args,
            .deconstruct_args = deconstruct_args,
            .body = body,
        };
    }

    pub fn eval(self: Self, alloc: Allocator, ctx: *Expression.Context) Expression.Errors!Expression {
        return try self.body.eval(alloc, ctx);
    }
};

pub const Ref = Expression.Literal([]const u8, .reference);
