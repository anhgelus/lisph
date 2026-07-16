const std = @import("std");
const Allocator = std.mem.Allocator;
const lisph = @import("interpreter");
const Expression = lisph.Expression;
const Errors = Expression.Errors;
const expect = std.testing.expect;

fn evalType(_: *anyopaque, alloc: Allocator, _: std.Io, ctx: *lisph.Context) Errors!Expression {
    const t = ctx.getVariable("value").?.local.typ.name();
    return (try Expression.String.init(alloc, t)).interface;
}

pub const Type = Expression.CustomFunction(
    "type",
    &[_][]const u8{"value"},
    true,
    evalType,
);

fn evalString(_: *anyopaque, alloc: Allocator, io: std.Io, ctx: *lisph.Context) Errors!Expression {
    const raw = ctx.getVariable("value").?.local;
    const val = try raw.eval(alloc, io, ctx);
    var content = std.ArrayList(u8).empty;
    try Expression.ComposedString.from(alloc, val, &content);
    return (try Expression.String.init(alloc, try content.toOwnedSlice(alloc))).interface;
}

pub const String = Expression.CustomFunction(
    "string",
    &[_][]const u8{"value"},
    true,
    evalString,
);

fn evalNumber(_: *anyopaque, alloc: Allocator, io: std.Io, ctx: *lisph.Context) Errors!Expression {
    const raw = ctx.getVariable("value").?.local;
    const val = try raw.eval(alloc, io, ctx);
    if (val.typ != .string) return Errors.InvalidCast;
    const res = std.fmt.parseUnsigned(
        u8,
        val.as(Expression.String).content,
        0,
    ) catch return Errors.InvalidFunctionArguments;
    return (try Expression.Number.init(alloc, res)).interface;
}

pub const Number = Expression.CustomFunction(
    "number",
    &[_][]const u8{"value"},
    true,
    evalNumber,
);

fn evalBoolean(_: *anyopaque, alloc: Allocator, io: std.Io, ctx: *lisph.Context) Errors!Expression {
    const raw = ctx.getVariable("value").?.local;
    const val = try raw.eval(alloc, io, ctx);
    return switch (val.typ) {
        .boolean => val,
        .number => (try Expression.Boolean.init(
            alloc,
            val.as(Expression.Number).content == 0,
        )).interface,
        .string => blk: {
            const s = val.as(Expression.String).content;
            break :blk (try Expression.Boolean.init(
                alloc,
                if (std.mem.eql(u8, s, "true"))
                    true
                else if (std.mem.eql(u8, s, "false"))
                    false
                else
                    return Errors.InvalidFunctionArguments,
            )).interface;
        },
        else => return Errors.InvalidCast,
    };
}

pub const Boolean = Expression.CustomFunction(
    "boolean",
    &[_][]const u8{"value"},
    true,
    evalBoolean,
);
