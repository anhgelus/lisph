const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");

pub const Var = struct {
    const Self = @This();

    name: []const u8,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{
            .eval = eval,
        },
        .typ = .variable,
    },

    pub fn init(alloc: Allocator, name: []const u8) !*Self {
        const self = try alloc.create(Self);
        self.name = name;
        self.interface.ptr = self;
        return self;
    }

    pub fn eval(ptr: *anyopaque, alloc: Allocator, ctx: Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const res = ctx.variables.get(self.name) orelse return Expression.Errors.UnknownVariable;
        return try res.eval(alloc, ctx);
    }

    pub fn set(self: *Self, alloc: Allocator, ctx: Expression.Context, value: Expression) !void {
        var res: ?Expression = null;
        if (!ctx.variables.contains(self.name)) {
            res = try value.eval(alloc, ctx);
            self.interface.typ = res.?.typ;
        }
        if (self.interface.typ != value.typ) return Expression.Errors.InvalidCast;
        if (res == null) res = value.eval(alloc, ctx);
        try ctx.variables.put(self.name, res.?);
    }
};

pub const Evaluate = struct {
    const Self = @This();

    call: *Expression.function.Call,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{
            .eval = eval,
        },
        .typ = .evaluate,
    },

    pub fn init(alloc: Allocator, call: *Expression.function.Call) !*Self {
        const self = try alloc.create(Self);
        self.call = call;
        self.interface.ptr = self;
        return self;
    }

    pub fn eval(ptr: *anyopaque, alloc: Allocator, ctx: Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return try self.call.interface.eval(alloc, ctx);
    }
};
