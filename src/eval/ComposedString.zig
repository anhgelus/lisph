const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");
const expect = std.testing.expect;

const Self = @This();

content: []const Expression,
interface: Expression = .{
    .ptr = undefined,
    .vtable = .{
        .eval = eval,
    },
    .typ = .string,
},

pub fn init(alloc: Allocator, content: []const Expression) !*Self {
    const self = try alloc.create(Self);
    self.* = .{ .content = content };
    self.interface.ptr = self;
    return self;
}

pub fn eval(ptr: *anyopaque, alloc: Allocator, ctx: *Expression.Context) Expression.Errors!Expression {
    const self: *Self = @ptrCast(@alignCast(ptr));
    var content = try std.ArrayList(u8).initCapacity(alloc, self.content.len);
    for (self.content) |it| {
        const res = try it.eval(alloc, ctx);
        switch (res.typ) {
            .boolean => {
                try content.appendSlice(
                    alloc,
                    if (res.as(Expression.Boolean).content) "true" else "false",
                );
            },
            .string => {
                try content.appendSlice(alloc, res.as(Expression.String).content);
            },
            .number => {
                const fmt = try std.fmt.allocPrint(
                    alloc,
                    "{}",
                    .{res.as(Expression.Number).content},
                );
                defer alloc.free(fmt);
                try content.appendSlice(alloc, fmt);
            },
            else => return Expression.Errors.InvalidComposedStringContent,
        }
    }
    return (try Expression.String.init(alloc, try content.toOwnedSlice(alloc))).interface;
}

test {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dummy = Expression.Context.init(alloc);

    var s = try init(alloc, &[_]Expression{
        (try Expression.String.init(alloc, "hello")).interface,
    });
    var res = try s.interface.eval(alloc, &dummy);
    try expect(res.typ == .string);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "hello"));

    s = try init(alloc, &[_]Expression{
        (try Expression.String.init(alloc, "hey ")).interface,
        (try Expression.Number.init(alloc, 123)).interface,
        (try Expression.Boolean.init(alloc, true)).interface,
    });
    res = try s.interface.eval(alloc, &dummy);
    try expect(res.typ == .string);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "hey 123true"));
}
