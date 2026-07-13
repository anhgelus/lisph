const std = @import("std");
const Iterator = std.unicode.Utf8Iterator;
const eql = std.mem.eql;
const expect = std.testing.expect;

const Self = @This();

pub const Kind = enum {
    string_delimiter,
    string_content,
    number,
    boolean,
    variable,
    function_beg,
    function_end,
    list_beg,
    list_end,
    empty,
    function_separator,
    separator,

    inline fn compatibleWith(self: @This(), kind: @This()) bool {
        if (self == .boolean and kind == .string_content) return true;
        if (self == .string_content and kind == .boolean) return true;
        if (self == .number and kind == .string_content) return true;
        if (self == .function_separator and kind == .string_content) return true;
        return switch (self) {
            .string_delimiter, .function_beg, .function_end, .list_beg, .list_end, .empty, .variable => false,
            else => self == kind,
        };
    }
};

pub const Token = struct {
    kind: Kind,
    content: []const u8,
    is_identifier: bool,
};

iterator: Iterator,
before: ?Token = null,
next_string: bool = false,

pub fn next(self: *Self) ?Token {
    if (self.before) |it| {
        self.consume();
        return it;
    }
    const beg = self.iterator.i;
    var end = beg;
    var current_kind: ?Kind = null;
    var is_identifier = false;
    iter: while (self.iterator.nextCodepointSlice()) |rune| {
        end = self.iterator.i;
        if (self.next_string or rune.len > 1) {
            self.next_string = false;
            current_kind = .string_content;
            continue;
        }
        if (eql(u8, self.iterator.bytes[beg..end], "true") or
            eql(u8, self.iterator.bytes[beg..end], "false"))
        {
            current_kind = .boolean;
            continue;
        }
        switch (rune[0]) {
            '\\' => self.next_string = true,
            '\r' => {},
            else => {
                current_kind = self.kindOf(rune[0], current_kind);
                const next_rune = self.iterator.peek(1);
                if (next_rune.len == 0) break;
                const next_kind = if (next_rune.len == 1)
                    self.kindOf(next_rune[0], current_kind)
                else
                    .string_content;
                if (current_kind == .string_content and next_kind == .separator) is_identifier = true;
                if (!current_kind.?.compatibleWith(next_kind)) break :iter;
            },
        }
    }
    return .{
        .kind = current_kind orelse return null,
        .content = self.iterator.bytes[beg..end],
        .is_identifier = is_identifier,
    };
}

pub fn skipSeparator(self: *Self) bool {
    var skipped = false;
    while (self.peek()) |it|
        if (it.kind == .separator) {
            skipped = true;
            self.consume();
        } else break;
    return skipped;
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
            if (self.peek()) |tok| {
                if (tok.kind == .function_end) {
                    self.consume();
                    kind = .empty;
                }
            }
            break :blk kind;
        },
        ')' => .function_end,
        '[' => .list_beg,
        ']' => .list_end,
        '\n', ';' => .function_separator,
        ' ' => .separator,
        '"' => .string_delimiter,
        else => if ((rune <= '9' and rune >= '0') and (before == null or before.? == .number))
            .number
        else
            .string_content,
    };
}

fn testNext() ?Token {
    return null;
}

fn testNext2() ?Token {
    return Token{ .content = ")", .kind = .function_end };
}

fn testBasicLexer(content: []const u8, k: Kind) !void {
    var lex = Self{ .iterator = Iterator{ .bytes = content, .i = 0 } };
    const n = lex.next().?;
    expect(n.kind == k) catch {
        std.debug.print("invalid result: {} ({s}), wanted {}\n", .{ n.kind, n.content, k });
        try expect(false);
    };
    try expect(lex.next() == null);
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
    try testBasicLexer("0a", .string_content);
    try testBasicLexer("9a", .string_content);
    try testBasicLexer("\\(", .string_content);
    try testBasicLexer("\"", .string_delimiter);
    try testBasicLexer("hey", .string_content);
    try testBasicLexer("true", .boolean);
    try testBasicLexer("false", .boolean);
}

test "complexe" {
    var l = Self{ .iterator = Iterator{
        .bytes = "(id arg content)",
        .i = 0,
    } };

    var tok = l.next().?;
    try expect(tok.kind == .function_beg);
    tok = l.next().?;
    try expect(tok.kind == .string_content);
    try expect(tok.is_identifier);
    try expect(eql(u8, tok.content, "id"));
    tok = l.next().?;
    try expect(tok.kind == .separator);
    tok = l.next().?;
    try expect(tok.kind == .string_content);
    try expect(eql(u8, tok.content, "arg"));
    tok = l.next().?;
    try expect(tok.kind == .separator);
    tok = l.next().?;
    try expect(tok.kind == .string_content);
    try expect(eql(u8, tok.content, "content"));
    tok = l.next().?;
    try expect(tok.kind == .function_end);
}
