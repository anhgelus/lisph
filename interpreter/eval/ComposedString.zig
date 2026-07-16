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

pub fn eval(ptr: *anyopaque, alloc: Allocator, io: std.Io, ctx: *Expression.Context) Expression.Errors!Expression {
    const self: *Self = @ptrCast(@alignCast(ptr));
    var content = try std.ArrayList(u8).initCapacity(alloc, self.content.len);
    for (self.content) |it| {
        const res = try it.eval(alloc, io, ctx);
        try from(alloc, res, &content);
    }
    return (try Expression.String.init(alloc, try content.toOwnedSlice(alloc))).interface;
}

pub fn from(alloc: Allocator, expr: Expression, acc: *std.ArrayList(u8)) !void {
    switch (expr.typ) {
        .boolean => {
            try acc.appendSlice(
                alloc,
                if (expr.as(Expression.Boolean).content) "true" else "false",
            );
        },
        .string => {
            try acc.appendSlice(alloc, expr.as(Expression.String).content);
        },
        .number => {
            const fmt = try std.fmt.allocPrint(
                alloc,
                "{}",
                .{expr.as(Expression.Number).content},
            );
            defer alloc.free(fmt);
            try acc.appendSlice(alloc, fmt);
        },
        .list => {
            const l = expr.as(Expression.List);
            var current = if (l.iter_order == .first_to_last) l.content.first else l.content.last;
            var i: usize = 0;
            while (current) |it| : (current = if (l.iter_order == .first_to_last) it.next else it.prev) {
                try from(alloc, Expression.List.Item.from(it).content, acc);
                if (i != l.len - 1) try acc.append(alloc, ':');
                i += 1;
            }
        },
        .subprocess_finished => {
            const result = expr.as(Expression.Context.SubprocessFinished).content;
            try acc.appendSlice(alloc, result.stdout);
        },
        .reference => {
            const result = expr.as(Expression.Reference).content;
            switch (result) {
                .basic => |r| {
                    try acc.append(alloc, '&');
                    try acc.appendSlice(alloc, r);
                },
                .lambda => try acc.appendSlice(alloc, "&<lambda>"),
            }
        },
        else => return Expression.Errors.InvalidComposedStringContent,
    }
}

test {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = std.testing.io;

    var dummy = Expression.Context.dummy(alloc);

    var s = try init(alloc, &[_]Expression{
        (try Expression.String.init(alloc, "hello")).interface,
    });
    var res = try s.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .string);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "hello"));

    s = try init(alloc, &[_]Expression{
        (try Expression.String.init(alloc, "hey ")).interface,
        (try Expression.Number.init(alloc, 123)).interface,
        (try Expression.Boolean.init(alloc, true)).interface,
    });
    res = try s.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .string);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "hey 123true"));
}
