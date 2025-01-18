const std = @import("std");
const log = std.log.scoped(.tokenize);

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const Tag = enum {
        nil,
        true,
        int,
        float,
        string,
        char,
        symbol,
        l_paren,
        r_paren,
        l_brace,
        r_brace,
        l_bracket,
        r_bracket,
        quote,
        comma,
        invalid,
        eof,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "true", .true },
        .{ "nil", .nil },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }
};

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    pub fn init(buffer: [:0]const u8) Tokenizer {
        return Tokenizer{ .buffer = buffer, .index = 0 };
    }

    const State = enum {
        start,
        int,
        int_exponent,
        int_period,
        float,
        float_exponent,
        string,
        string_backslash,
        backslash,
        symbol,

        line_comment_start,
        line_comment,
        expect_newline,
        invalid,
    };

    pub fn next(self: *Tokenizer) Token {
        var result = Token{
            .tag = undefined,
            .loc = .{ .start = self.index, .end = undefined },
        };

        var open_tag: u8 = undefined;
        state: switch (State.start) {
            .start => switch (self.buffer[self.index]) {
                0 => {
                    log.debug("Got a zero: {d} == {d}", .{ self.index, self.buffer.len });
                    if (self.index == self.buffer.len) {
                        return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    } else {
                        continue :state .invalid;
                    }
                },
                ' ', '\t', '\n', '\r' => {
                    self.index += 1;
                    result.loc.start = self.index;
                    continue :state .start;
                },
                '"', '\'' => |c| {
                    result.tag = .string;
                    open_tag = c;
                    continue :state .string;
                },

                '\\' => {
                    continue :state .backslash;
                },

                '(' => {
                    result.tag = .l_paren;
                    self.index += 1;
                },
                '[' => {
                    result.tag = .l_brace;
                    self.index += 1;
                },
                '{' => {
                    result.tag = .l_bracket;
                    self.index += 1;
                },
                ')' => {
                    result.tag = .r_paren;
                    self.index += 1;
                },
                ']' => {
                    result.tag = .r_brace;
                    self.index += 1;
                },
                '}' => {
                    result.tag = .r_bracket;
                    self.index += 1;
                },
                '0'...'9' => {
                    result.tag = .int;
                    continue :state .int;
                },
                '.' => {
                    result.tag = .float;
                    continue :state .float;
                },
                ';' => {
                    continue :state .line_comment_start;
                },
                else => {
                    result.tag = .symbol;
                    continue :state .symbol;
                },
            },

            .symbol => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .symbol,
                    else => {
                        const ident = self.buffer[result.loc.start..self.index];
                        if (Token.getKeyword(ident)) |tag| {
                            result.tag = tag;
                        }
                    },
                }
            },

            .string => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            continue :state .invalid;
                        } else {
                            result.tag = .invalid;
                        }
                    },
                    '\n' => result.tag = .invalid,
                    '\\' => continue :state .string_backslash,
                    '"' => if (open_tag == '"') {
                        self.index += 1;
                    } else continue :state .string,
                    '\'' => if (open_tag == '\'') {
                        self.index += 1;
                    } else continue :state .string,
                    0x01...0x09, 0x0b...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => continue :state .string,
                }
            },
            .string_backslash => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0, '\n' => result.tag = .invalid,
                    else => continue :state .string,
                }
            },
            .backslash => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => result.tag = .invalid,
                    '\n' => result.tag = .invalid,
                    'a'...'z', 'A'...'Z' => {
                        self.index += 1;
                        result.tag = .char;
                    },
                    else => continue :state .invalid,
                }
            },

            .int => switch (self.buffer[self.index]) {
                '.' => continue :state .int_period,
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                    self.index += 1;
                    continue :state .int;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .int_exponent;
                },
                else => {},
            },
            .int_exponent => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '-', '+' => {
                        self.index += 1;
                        continue :state .float;
                    },
                    else => continue :state .int,
                }
            },
            .int_period => {
                std.debug.print("In int_period: {c} -> {c}\n", .{ self.buffer[self.index], self.buffer[self.index + 1] });
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                        std.debug.print("Going to float\n", .{});
                        self.index += 1;
                        result.tag = .float;
                        continue :state .float;
                    },
                    'e', 'E', 'p', 'P' => {
                        continue :state .float_exponent;
                    },
                    else => self.index -= 1,
                }
            },
            .float => switch (self.buffer[self.index]) {
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                    self.index += 1;
                    continue :state .float;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .float_exponent;
                },
                else => {},
            },
            .float_exponent => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '-', '+' => {
                        self.index += 1;
                        continue :state .float;
                    },
                    else => continue :state .float,
                }
            },

            .line_comment_start => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            continue :state .invalid;
                        } else return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    },
                    '\n' => {
                        self.index += 1;
                        result.loc.start = self.index;
                        continue :state .start;
                    },
                    '\r' => continue :state .expect_newline,
                    0x01...0x09, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => continue :state .line_comment,
                }
            },
            .line_comment => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            continue :state .invalid;
                        } else return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    },
                    '\n' => {
                        self.index += 1;
                        result.loc.start = self.index;
                        continue :state .start;
                    },

                    '\r' => continue :state .expect_newline,
                    0x01...0x09, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => continue :state .line_comment,
                }
            },
            .expect_newline => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index == self.buffer.len) {
                            result.tag = .invalid;
                        } else {
                            continue :state .invalid;
                        }
                    },
                    '\n' => {
                        self.index += 1;
                        result.loc.start = self.index;
                        continue :state .start;
                    },
                    else => continue :state .invalid,
                }
            },

            .invalid => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => if (self.index == self.buffer.len) {
                        result.tag = .invalid;
                    } else {
                        continue :state .invalid;
                    },
                    '\n' => result.tag = .invalid,
                    else => continue :state .invalid,
                }
            },
        }

        result.loc.end = self.index;
        return result;
    }

    pub fn rawForToken(self: *Tokenizer, tok: Token) []const u8 {
        return self.buffer[tok.loc.start..tok.loc.end];
    }
};

const expectEqual = @import("std").testing.expectEqual;

fn testTokenize(input: [:0]const u8, expected: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(input);

    for (expected, 0..) |tag, i| {
        const next = tokenizer.next();
        std.debug.print("tag: {d} - {any}\n", .{ i, next.tag });
        try expectEqual(tag, next.tag);
    }
    try expectEqual(.eof, tokenizer.next().tag);
}
test "tokenizing" {
    const input: [:0]const u8 = "(+ 1 1.2 (parse '123')) [a \\a z \\z] {- \"subtract\"}";

    const tokens = [_]Token.Tag{ .l_paren, .symbol, .int, .float, .l_paren, .symbol, .string, .r_paren, .r_paren, .l_brace, .symbol, .char, .symbol, .char, .r_brace, .l_bracket, .symbol, .string, .r_bracket };
    try testTokenize(input, tokens[0..]);
}

test "comments" {
    const input =
        \\ ; this is a comment
        \\ (+ 1 2)
        \\ ; and so is this
    ;

    const expected = [_]Token.Tag{ .l_paren, .symbol, .int, .int, .r_paren };
    try testTokenize(input, expected[0..]);
}
