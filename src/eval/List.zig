const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");
const expect = std.testing.expect;

const Self = @This();

content: std.DoublyLinkedList = .{},
arena: std.heap.ArenaAllocator,
interface: Expression = .{
    .ptr = undefined,
    .vtable = .{
        .eval = eval,
    },
    .typ = .list,
},
iter_order: enum { first_to_last, last_to_first } = .first_to_last,
len: usize = 0,

pub fn init(parent: Allocator) !*Self {
    var arena = std.heap.ArenaAllocator.init(parent);
    var alloc = arena.allocator();
    const self = try alloc.create(Self);
    self.* = .{ .arena = arena };
    self.interface.ptr = self;
    return self;
}

pub fn eval(ptr: *anyopaque, _: Allocator, _: std.Io, _: *Expression.Context) Expression.Errors!Expression {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.interface;
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn append(self: *Self, expr: Expression) !void {
    const item = try Item.init(self.arena.allocator(), expr);
    self.len += 1;
    if (self.iter_order == .first_to_last)
        self.content.append(&item.node)
    else
        self.content.prepend(&item.node);
}

pub fn clone(self: *Self, parent: Allocator) !*Self {
    const new = try init(parent);
    new.iter_order = self.iter_order;
    var current = self.headNode();
    while (current) |it| : (current = if (self.iter_order == .first_to_last) it.next else it.prev) {
        try new.append(Item.from(it).content);
    }
    return new;
}

pub fn reverse(self: *Self, parent: Allocator) !*Self {
    const new = try self.clone(parent);
    new.iter_order = if (new.iter_order == .first_to_last) .last_to_first else .first_to_last;
    return new;
}

inline fn headNode(self: *Self) ?*std.DoublyLinkedList.Node {
    return if (self.iter_order == .first_to_last) self.content.first else self.content.last;
}

pub fn head(self: *Self) ?Expression {
    return Item.from(self.headNode() orelse return null).content;
}

pub fn tail(self: *Self, parent: Allocator) !?*Self {
    if (self.len < 2) return null;
    const new = try self.clone(parent);
    new.len -= 1;
    const del = if (new.iter_order == .first_to_last) new.content.popFirst() else new.content.pop();
    parent.destroy(Item.from(del.?));
    return new;
}

pub fn get(self: *Self, i: usize) ?Expression {
    if (i >= self.len) return null;
    if (i <= self.len / 2) {
        var current = self.headNode().?;
        for (0..i) |_| current = if (self.iter_order == .first_to_last) current.next.? else current.prev.?;
        return Item.from(current).content;
    }
    var current = if (self.iter_order == .first_to_last) self.content.last.? else self.content.first.?;
    for (i..self.len - 1) |_| current = if (self.iter_order == .first_to_last) current.prev.? else current.next.?;
    return Item.from(current).content;
}

test {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const Number = Expression.Number;
    const io = std.testing.io;

    var dummy = Expression.Context.dummy(alloc);

    var l = try init(alloc);
    for (0..5) |i| {
        const nbr = try Number.init(alloc, i);
        try l.append(nbr.interface);
    }

    const res = try l.interface.eval(alloc, io, &dummy);
    try expect(res.typ == .list);
    l = res.as(Self);

    for (0..5) |i| try expect(l.get(i).?.as(Number).content == i);
    var current = l;
    for (0..5) |i| {
        try expect(current.head().?.as(Number).content == i);
        if (i != 4) current = (try current.tail(alloc)).? else try expect(try current.tail(alloc) == null);
    }
    const rev = try l.reverse(alloc);
    for (0..5) |i| try expect(rev.get(i).?.as(Number).content == 4 - i);
    current = rev;
    for (0..5) |i| {
        try expect(current.head().?.as(Number).content == 4 - i);
        if (i != 4) current = (try current.tail(alloc)).? else try expect(try current.tail(alloc) == null);
    }
}

pub const Item = struct {
    content: Expression,
    node: std.DoublyLinkedList.Node = .{},

    pub fn init(alloc: Allocator, content: Expression) !*Item {
        const self = try alloc.create(Item);
        self.content = content;
        return self;
    }

    pub fn from(node: *std.DoublyLinkedList.Node) *Item {
        const self: *Item = @fieldParentPtr("node", node);
        return self;
    }
};
