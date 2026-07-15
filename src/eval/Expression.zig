const std = @import("std");
const Allocator = std.mem.Allocator;
const function = @import("function.zig");
pub const Function = function.Call;
pub const FunctionDef = function.Def;
pub const Reference = function.Ref;
const literal = @import("literal.zig");
pub const String = literal.String;
pub const Boolean = literal.Boolean;
pub const Number = literal.Number;
pub const ComposedString = @import("ComposedString.zig");
pub const List = @import("List.zig");
const variable = @import("variable.zig");
pub const Variable = variable.Variable;
pub const Evaluate = variable.Evaluate;
pub const Context = @import("Context.zig");
const Expression = @This();

pub const Errors = error{
    InvalidCast,
    UnknownFunction,
    UnknownVariable,
    InvalidFunctionArguments,
    InvalidComposedStringContent,
} || Allocator.Error;

pub fn isInternalError(err: Errors) bool {
    return switch (err) {
        Allocator.Error => true,
        else => false,
    };
}

pub const Type = enum {
    function,
    number,
    variable,
    evaluate,
    boolean,
    string,
    list,
    reference,
    subprocess_finished,

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
    eval: *const fn (*anyopaque, Allocator, std.Io, *Context) Errors!Expression,
},
typ: Type,

pub fn eval(self: Expression, alloc: Allocator, io: std.Io, ctx: *Context) Errors!Expression {
    return try self.vtable.eval(self.ptr, alloc, io, ctx);
}

pub inline fn as(self: Expression, comptime T: type) *T {
    comptime {
        if (@FieldType(T, "interface") != Expression)
            @compileError(@typeName(T) ++ " is not an expression.");
    }
    const sub: *T = @ptrCast(@alignCast(self.ptr));
    return sub;
}

pub fn Literal(comptime V: type, comptime t: Type) type {
    return struct {
        content: V,
        interface: Expression = .{
            .ptr = undefined,
            .vtable = undefined,
            .typ = t,
        },

        const Self = @This();

        pub fn init(alloc: Allocator, content: V) !*Self {
            const self = try alloc.create(Self);
            self.* = .{ .content = content };
            self.interface.ptr = self;
            self.interface.vtable = .{
                .eval = Self.eval,
            };
            return self;
        }

        pub fn eval(ptr: *anyopaque, _: Allocator, _: std.Io, _: *Expression.Context) Expression.Errors!Expression {
            const self: *Self = @ptrCast(@alignCast(ptr));
            return self.interface;
        }

        pub fn from(expr: Expression) Expression.Errors.InvalidCast!*Self {
            if (expr.typ != t) return Expression.Errors.InvalidCast;
            return @ptrCast(@alignCast(expr.ptr));
        }
    };
}

pub const Root = struct {
    expr: Expression,

    const Self = @This();

    pub fn eval(self: Root, parent: Allocator, io: std.Io, ctx: *Expression.Context) Expression.Errors!void {
        var arena = std.heap.ArenaAllocator.init(parent);
        defer arena.deinit();
        const alloc = arena.allocator();
        var sub = Expression.Context{
            .functions = ctx.functions,
            .variables = try ctx.variables.cloneWithAllocator(alloc),
        };
        const res = try self.expr.eval(alloc, &sub, io);
        if (res.typ != .subprocess_finished) return;

        const result = res.as(Context.SubprocessFinished).content;

        var writer = std.Io.File.stdout().writer(io, .{});
        try writer.interface.writeAll(result.stdout);
        try writer.flush();

        writer = std.Io.File.stderr().writer(io, .{});
        try writer.interface.writeAll(result.stderr);
        try writer.flush();

        if (result.term.exited != 0) {
            try writer.interface.print("Exit code: {}\n", .{result.term.exited});
        }
    }
};
