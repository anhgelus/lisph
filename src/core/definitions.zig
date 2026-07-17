const std = @import("std");
const Allocator = std.mem.Allocator;
const lisph = @import("interpreter");
const Expression = lisph.Expression;
const Custom = Expression.CustomFunction;
const Errors = Expression.Errors;
const expect = std.testing.expect;

fn parseCommandArgs(alloc: Allocator, io: std.Io, ctx: *lisph.Context) !Expression.FunctionDef {
    const raw_args = ctx.getVariable("args").?.local;
    var args: [][]const u8 = undefined;
    var deconstruct = false;
    switch (raw_args.typ) {
        .list => {
            const l = raw_args.as(Expression.List);
            std.debug.assert(l.iter_order == .first_to_last);
            var a = try std.ArrayList([]const u8).initCapacity(alloc, l.len);
            var current = l.content.first;
            while (current) |it| : (current = it.next) {
                const content = Expression.List.Item.from(it).content;
                const res = try content.eval(alloc, io, ctx);
                if (res.typ != .string) return Errors.InvalidCast;
                try a.append(alloc, res.as(Expression.String).content);
            }
            args = try a.toOwnedSlice(alloc);
            deconstruct = true;
        },
        .string => {
            args = try alloc.alloc([]const u8, 1);
            args[0] = raw_args.as(Expression.String).content;
        },
        else => return Errors.InvalidCast,
    }
    const body = ctx.getVariable("body").?.local;
    return Expression.FunctionDef{
        .args = args,
        .deconstruct_args = deconstruct,
        .body = body,
    };
}

fn evalDefn(_: *anyopaque, alloc: Allocator, io: std.Io, ctx: *lisph.Context) Errors!Expression {
    const raw_name = ctx.getVariable("name").?.local;
    if (raw_name.typ != .string) return Errors.InvalidCast;
    const name = raw_name.as(Expression.String);
    const defn = try alloc.create(Expression.FunctionDef);
    defn.* = try parseCommandArgs(alloc, io, ctx);
    try ctx.functions.put(name.content, defn);
    return (try Expression.Empty.init(alloc)).interface;
}

pub const Defn = Custom(
    "defn",
    &[_][]const u8{ "name", "args", "body" },
    true,
    evalDefn,
);

test "defn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = std.testing.io;

    var dummy = Expression.Context.dummy(alloc);

    try dummy.variables.put("name", (try Expression.String.init(alloc, "foo")).interface);
    try dummy.variables.put("args", (try Expression.String.init(alloc, "owo")).interface);
    try dummy.variables.put("body", (try Expression.String.init(alloc, "uwu")).interface);

    _ = try Defn.eval(&dummy, alloc, io, &dummy);
    const defn = dummy.functions.get("foo").?;
    try expect(!defn.deconstruct_args);
    try expect(defn.args.len == 1);
    try expect(std.mem.eql(u8, defn.args[0], "owo"));
    try expect(defn.body.typ == .string);
    var res = try defn.eval(alloc, io, &dummy);
    try expect(res.typ == .string);
    try expect(std.mem.eql(u8, res.as(Expression.String).content, "uwu"));
}

fn evalLambda(_: *anyopaque, alloc: Allocator, io: std.Io, ctx: *lisph.Context) Errors!Expression {
    return (try Expression.Reference.init(
        alloc,
        Expression.KindRef{ .lambda = try parseCommandArgs(alloc, io, ctx) },
    )).interface;
}

pub const Lambda = Custom(
    "lambda",
    &[_][]const u8{ "args", "body" },
    true,
    evalLambda,
);

test "lambda" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = std.testing.io;

    var dummy = Expression.Context.dummy(alloc);

    try dummy.variables.put("args", (try Expression.String.init(alloc, "owo")).interface);
    try dummy.variables.put("body", (try Expression.String.init(alloc, "uwu")).interface);

    const l = try Lambda.eval(&dummy, alloc, io, &dummy);
    try expect(l.typ == .reference);
    const ref = l.as(Expression.Reference).content.lambda;
    try expect(ref.body.typ == .string);
    try expect(!ref.deconstruct_args);
    try expect(ref.args.len == 1);
    try expect(std.mem.eql(u8, ref.args[0], "owo"));
}

fn evalSet(_: *anyopaque, alloc: Allocator, io: std.Io, ctx: *lisph.Context) Errors!Expression {
    const raw_name = ctx.getVariable("name").?.local;
    const name = try raw_name.eval(alloc, io, ctx);
    if (name.typ != .string) return Errors.InvalidCast;
    try ctx.variables.put(name.as(Expression.String).content, ctx.getVariable("value").?.local);
    return (try Expression.Empty.init(alloc)).interface;
}

pub const Set = Custom(
    "set",
    &[_][]const u8{ "name", "value" },
    true,
    evalSet,
);

fn evalExport(_: *anyopaque, alloc: Allocator, io: std.Io, ctx: *lisph.Context) Errors!Expression {
    const raw_args = ctx.getVariable("args").?.local;
    const args = try raw_args.eval(alloc, io, ctx);
    const l = args.as(Expression.List);
    std.debug.assert(l.iter_order == .first_to_last);
    var current = l.content.first;
    while (current) |it| : (current = it.next) {
        const res = try Expression.List.Item.from(it).content.eval(alloc, io, ctx);
        if (res.typ != .string) return Errors.InvalidCast;
        const name = res.as(Expression.String).content;
        const variable = ctx.getVariable(name) orelse return Errors.UnknownVariable;
        try ctx.environ.put(name, switch (variable) {
            .environ => |v| v,
            .local => |expr| blk: {
                const r = try expr.eval(alloc, io, ctx);
                if (r.typ != .string) return Errors.InvalidCast;
                break :blk r.as(Expression.String).content;
            },
        });
    }
    return (try Expression.Empty.init(alloc)).interface;
}

pub const Export = Custom(
    "export",
    &[_][]const u8{"args"},
    false,
    evalExport,
);
