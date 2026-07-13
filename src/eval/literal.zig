const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");

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

    pub fn eval(ptr: *anyopaque, _: Allocator, _: Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.interface;
    }
};

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

    pub fn eval(ptr: *anyopaque, _: Allocator, _: Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.interface;
    }
};

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

    pub fn eval(ptr: *anyopaque, _: Allocator, _: Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.interface;
    }
};
