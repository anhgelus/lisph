const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");

const Self = @This();

content: []Expression,
interface: Expression = .{
    .ptr = undefined,
    .vtable = .{
        .eval = eval,
    },
    .typ = .string_composed,
},

pub fn init(alloc: Allocator, content: []Expression) !*Self {
    const self = try alloc.create(Self);
    self.* = .{ .content = content };
    self.interface.ptr = self;
    return self;
}

pub fn eval(ptr: *anyopaque, alloc: Allocator, ctx: Expression.Context) Expression.Errors!Expression {
    const self: *Self = @ptrCast(@alignCast(ptr));
    var content = try std.ArrayList(u8).initCapacity(alloc, self.content.len);
    for (self.content) |it| {
        const res = try it.eval(alloc, ctx);
        switch (res.typ) {
            .boolean => {
                const b: *Expression.literal.Boolean = @ptrCast(@alignCast(res.ptr));
                try content.appendSlice(alloc, if (b.content) "true" else "false");
            },
            .string_literal => {
                const s: *Expression.literal.String = @ptrCast(@alignCast(res.ptr));
                try content.appendSlice(alloc, s.content);
            },
            .number => {
                const n: *Expression.literal.Number = @ptrCast(@alignCast(res.ptr));
                const fmt = try std.fmt.allocPrint(alloc, "{}", .{n.content});
                defer alloc.free(fmt);
                try content.appendSlice(alloc, fmt);
            },
            .evaluate => {},
            .variable => {},
            .list => {},
            else => return Expression.Errors.InvalidComposedStringContent,
        }
    }
    return (try Expression.literal.String.init(alloc, try content.toOwnedSlice(alloc))).interface;
}
