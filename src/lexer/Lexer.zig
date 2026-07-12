const std = @import("std");
const unicode = std.unicode;
const eql = std.mem.eql;

const Self = @This();

pub const Kind = enum {
    string,
    number,
    boolean,
    variable,
    function_beg,
    function_end,
    list_beg,
    list_end,
    empty,

    fn compatibleWith(self: @This(), kind: @This()) bool {
        if (self == .boolean and kind == .string) return true;
        if (self == .string and kind == .boolean) return true;
        if (self == .number and kind == .string) return true;
        return self == kind;
    }
};

pub const Token = struct {
    kind: Kind,
    content: []const u8,
};

iterator: unicode.Utf8Iterator,
before: ?Token = null,
next_literal: bool = false,

pub fn next(self: *Self) ?Token {
    if (self.before) |it| {
        self.consume();
        return it;
    }
    const beg = self.iterator.i;
    var end = beg;
    var current_kind: ?Kind = null;
    var is_string = false;
    iter: while (self.iterator.nextCodepointSlice()) |rune| {
        end = self.iterator.i;
        if (self.next_literal or is_string or rune.len > 1) {
            self.next_literal = false;
            current_kind = .string;
            continue;
        }
        if (eql(u8, self.iterator.bytes[beg..end], "true") or eql(u8, self.iterator.bytes[beg..end], "false")) {
            current_kind = .boolean;
            continue;
        }
        switch (rune[0]) {
            ' ' => break :iter,
            '\\' => self.next_literal = true,
            '\r', '\n' => {},
            '"' => is_string = true,
            else => {
                current_kind = self.kindOf(rune[0], current_kind);
                const next_rune = self.iterator.peek(1);
                if (next_rune.len == 0) break;
                const next_kind = if (next_rune.len == 1)
                    self.kindOf(next_rune[0], current_kind)
                else
                    .string;
                if (!current_kind.?.compatibleWith(next_kind)) break :iter;
            },
        }
    }
    return .{
        .kind = current_kind orelse return null,
        .content = self.iterator.bytes[beg..end],
    };
}

pub fn peek(self: *Self) ?Token {
    self.before = self.next();
    return self.before;
}

pub fn consume(self: *Self) void {
    self.before = null;
}

pub fn kindOf(self: *Self, rune: u8, before: ?Kind) Kind {
    return switch (rune) {
        '(' => blk: {
            var kind: Kind = .function_beg;
            if (self.next()) |tok| {
                if (tok.kind == .function_end) kind = .empty;
            }
            break :blk kind;
        },
        ')' => .function_end,
        '[' => .list_beg,
        ']' => .list_end,
        else => if ((rune <= '9' and rune >= '0') and (before == null or before.? == .number))
            .number
        else
            .string,
    };
}

fn testNext() ?Token {
    return null;
}

fn testNext2() ?Token {
    return Token{ .content = ")", .kind = .function_end };
}

fn testBasicLexer(content: []const u8, k: Kind) !void {
    var lex = Self{ .iterator = unicode.Utf8Iterator{ .bytes = content, .i = 0 } };
    const n = lex.next().?;
    std.testing.expect(n.kind == k) catch {
        std.debug.print("invalid result: {} ({s}), wanted {}\n", .{ n.kind, n.content, k });
        try std.testing.expect(false);
    };
    try std.testing.expect(lex.next() == null);
}

test "basic kind" {
    try testBasicLexer("(", .function_beg);
    try testBasicLexer(")", .function_end);
    try testBasicLexer("()", .empty);
    try testBasicLexer("[", .list_beg);
    try testBasicLexer("]", .list_end);
    try testBasicLexer("0", .number);
    try testBasicLexer("9", .number);
    try testBasicLexer("00", .number);
    try testBasicLexer("09", .number);
    try testBasicLexer("0a", .string);
    try testBasicLexer("9a", .string);
    try testBasicLexer("\\(", .string);
    try testBasicLexer("\"hello world, this is an example\"", .string);
    try testBasicLexer("hey", .string);
    try testBasicLexer("true", .boolean);
    try testBasicLexer("false", .boolean);
}
