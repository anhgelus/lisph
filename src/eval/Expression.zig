const std = @import("std");
const Allocator = std.mem.Allocator;
pub const Function = @import("Function.zig");
const Expression = @This();

pub const Errors = error{
    InvalidCast,
    UnknownFunction,
    UnknownVariable,
    InvalidFunctionArguments,
} || Allocator.Error;

pub const Type = enum {
    function,
    number,
    variable,
    evaluate,
    boolean,
    string,
};

ptr: *anyopaque,
vtable: struct {
    eval: *const fn (*anyopaque, Allocator, Context) Errors!Expression,
},
typ: Type,

pub fn eval(self: Expression, alloc: Allocator, ctx: Context) Errors!Expression {
    return try self.vtable.eval(self.ptr, alloc, ctx);
}

pub const Context = struct {
    variables: std.StringHashMap(Expression),
    functions: std.StringHashMap(*Function.Def),
};
