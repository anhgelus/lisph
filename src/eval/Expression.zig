const std = @import("std");
const Allocator = std.mem.Allocator;
const function = @import("function.zig");
pub const Function = function.Call;
pub const FunctionDef = function.Def;
pub const FunctionRef = function.Ref;
const literal = @import("literal.zig");
pub const String = literal.String;
pub const Boolean = literal.Boolean;
pub const Number = literal.Number;
pub const ComposedString = @import("ComposedString.zig");
pub const List = @import("List.zig");
pub const variable = @import("variable.zig");
const Expression = @This();

pub const Errors = error{
    InvalidCast,
    UnknownFunction,
    UnknownVariable,
    InvalidFunctionArguments,
    InvalidComposedStringContent, // this is an internal error
} || Allocator.Error;

pub const Type = enum {
    function,
    number,
    variable,
    evaluate,
    boolean,
    string,
    list,
    reference,

    pub inline fn name(t: Type) []const u8 {
        return switch (t) {
            .function => "function",
            .number => "number",
            .variable, .evaluate => "unknown",
            .boolean => "boolean",
            .string, .string_composed => "string",
            .list => "list",
        };
    }
};

ptr: *anyopaque,
vtable: struct {
    eval: *const fn (*anyopaque, Allocator, *Context) Errors!Expression,
},
typ: Type,

pub fn eval(self: Expression, alloc: Allocator, ctx: *Context) Errors!Expression {
    return try self.vtable.eval(self.ptr, alloc, ctx);
}

pub inline fn as(self: Expression, comptime T: type) *T {
    comptime {
        if (@FieldType(T, "interface") != Expression)
            @compileError(@typeName(T) ++ " is not an expression.");
    }
    const sub: *T = @ptrCast(@alignCast(self.ptr));
    return sub;
}

pub const Context = struct {
    variables: std.StringHashMap(Expression),
    functions: std.StringHashMap(*function.Def),

    pub fn init(alloc: Allocator) Context {
        return .{
            .functions = .init(alloc),
            .variables = .init(alloc),
        };
    }
};
