const std = @import("std");
const Lexer = @import("lexer/Lexer.zig");
const composed = @import("composed.zig");

pub const Errors = error{ InvalidExpression, InvalidVariable, InvalidEvaluate } || composed.Errors || std.fmt.ParseIntError;

pub fn parse(l: *Lexer) Errors!void {
    const tok = l.peek() orelse return Errors.InvalidExpression;
    switch (tok.kind) {
        .function_beg => try composed.parseFunction(l),
        .boolean => try parseBoolean(l),
        .number => try parseNumber(l),
        .string_delimiter => try composed.parseString(l),
        .list_beg => try composed.parseList(l),
        .variable => try parseVariable(l),
        else => return Errors.InvalidExpression,
    }
}

pub fn parseBoolean(l: *Lexer) !void {
    const tok = l.next().?;
    if (std.mem.eql(u8, tok.content, "true")) {} // todo
    return; //
}

pub fn parseNumber(l: *Lexer) !void {
    const tok = l.next().?;
    _ = try std.fmt.parseUnsigned(u64, tok.content, 0);
}

pub fn parseVariable(l: *Lexer) !void {
    l.consume();
    var tok = l.next() orelse return Errors.InvalidVariable;
    // evaluate here
    if (tok.kind == .function_beg) {
        const is_func = l.peek() orelse return Errors.InvalidVariable != .string_content;
        if (is_func) l.consume();
        try parse(l);
        if (!is_func) {
            tok = l.next() orelse return Errors.InvalidEvaluate;
            if (tok.kind != .function_end) return Errors.InvalidEvaluate;
        }
        return;
    }
    if (!tok.is_identifier) return Errors.InvalidVariable;
}
