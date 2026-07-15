const std = @import("std");
const Allocator = std.mem.Allocator;
const Expression = @import("Expression.zig");

variables: std.StringHashMap(Expression),
functions: std.StringHashMap(*Expression.FunctionDef),
environ: std.process.Environ.Map,

const Context = @This();

pub fn dummy(alloc: Allocator) Context {
    return init(alloc, .init(alloc));
}

pub fn init(alloc: Allocator, environ: std.process.Environ.Map) Context {
    return .{
        .functions = .init(alloc),
        .variables = .init(alloc),
        .environ = environ,
    };
}

pub fn getFunction(self: @This(), alloc: Allocator, name: []const u8) !Expression.FunctionDef {
    if (self.functions.get(name)) |it| return it.*;
    return Expression.FunctionDef{
        .args = &[_][]const u8{"args"},
        .deconstruct_args = false,
        .body = (try Subprocess.init(alloc, name, "args")).interface,
    };
}

const Subprocess = struct {
    name: []const u8,
    arg_name: []const u8,
    interface: Expression = .{
        .ptr = undefined,
        .vtable = .{ .eval = eval },
        .typ = .function,
    },

    const Self = @This();

    pub fn init(alloc: Allocator, name: []const u8, comptime arg_name: []const u8) !*Self {
        const self = try alloc.create(Self);
        self.* = .{ .name = name, .arg_name = arg_name };
        self.interface.ptr = self;
        return self;
    }

    pub fn eval(ptr: *anyopaque, parent: Allocator, io: std.Io, ctx: *Expression.Context) Expression.Errors!Expression {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const raw_args = ctx.variables.get(self.arg_name).?.as(Expression.List);
        std.debug.assert(raw_args.iter_order == .first_to_last);
        var arena = std.heap.ArenaAllocator.init(parent);
        defer arena.deinit();
        var alloc = arena.allocator();
        const argv = try alloc.alloc([]const u8, raw_args.len + 1);
        argv[0] = self.name;
        var current = raw_args.content.first;
        var i: usize = 1;
        while (current) |it| : (current = it.next) {
            const item = Expression.List.Item.from(it);
            const res = try item.content.eval(alloc, io, ctx);
            var content = try std.ArrayList(u8).initCapacity(alloc, 2);
            try Expression.ComposedString.from(alloc, res, &content);
            argv[i] = try content.toOwnedSlice(alloc);
            i += 1;
        }
        const res = std.process.run(parent, io, .{
            .argv = argv,
            .environ_map = &ctx.environ,
        }) catch |err| switch (err) {
            error.FileNotFound => return Expression.Errors.UnknownFunction,
            else => @panic(@errorName(err)),
        };
        return (try SubprocessFinished.init(parent, res)).interface;
    }
};

pub const SubprocessFinished = Expression.Literal(std.process.RunResult, .subprocess_finished);
