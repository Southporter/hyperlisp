const std = @import("std");
const assert = std.debug.assert;
const StringIndexAdapter = std.hash_map.StringIndexAdapter;
const StringIndexContext = std.hash_map.StringIndexContext;

const log = std.log.scoped(.parser);

const Parser = @This();

const vals = @import("values.zig");
const tokenize = @import("tokenize.zig");
const Token = tokenize.Token;
const Value = vals.Value;

pub const List = std.MultiArrayList(Value);
const NodeIndex = usize;

const OpenCollection = struct {
    const Tag = enum {
        paren,
        brace,
        bracket,
    };
    tag: Tag,
    node: NodeIndex,
};

pub const Ast = struct {
    tree: std.MultiArrayList(Value),
    symbol_pool: std.HashMapUnmanaged(u32, void, StringIndexContext, std.hash_map.default_max_load_percentage) = .empty,
    string_bytes: std.ArrayListUnmanaged(u8) = .empty,

    pub fn deinit(ast: *Ast, allocator: std.mem.Allocator) void {
        const data = ast.tree.items(.data);
        for (ast.tree.items(.tag), 0..) |tag, i| {
            if (tag == .string) {
                allocator.free(data[i].string);
            }
        }
        ast.tree.deinit(allocator);
        ast.symbol_pool.deinit(allocator);
        ast.string_bytes.deinit(allocator);
    }
};

allocator: std.mem.Allocator,
tokenizer: tokenize.Tokenizer,
unclosed: std.ArrayListUnmanaged(OpenCollection) = .empty,
ast: Ast = .{
    .tree = .empty,
    .symbol_pool = .empty,
    .string_bytes = .empty,
},

pub fn init(allocator: std.mem.Allocator, source: [:0]const u8) Parser {
    return .{
        .allocator = allocator,
        .tokenizer = tokenize.Tokenizer.init(source),
    };
}

pub fn parse(self: *Parser) !Ast {
    errdefer self.ast.deinit(self.allocator);
    defer self.unclosed.deinit(self.allocator);
    while (self.next()) |tok| {
        switch (tok.tag) {
            .nil => {
                self.addListItem();
                try self.ast.tree.append(self.allocator, .{
                    .tag = .nil,
                    .data = .{ .nil = {} },
                });
            },
            .true => {
                self.addListItem();
                try self.ast.tree.append(self.allocator, .{
                    .tag = .true,
                    .data = .{ .true = {} },
                });
            },
            .quote, .comma => {
                return error.Unimplemented;
            },
            .symbol => {
                self.addListItem();
                const name = self.tokenizer.rawForToken(tok);
                const string_bytes = &self.ast.string_bytes;
                const name_index: u32 = @intCast(string_bytes.items.len);
                try self.ast.string_bytes.appendSlice(self.allocator, name);
                const gop = try self.ast.symbol_pool.getOrPutContextAdapted(self.allocator, name, StringIndexAdapter{
                    .bytes = string_bytes,
                }, StringIndexContext{
                    .bytes = string_bytes,
                });

                if (gop.found_existing) {
                    self.ast.string_bytes.shrinkRetainingCapacity(name_index);
                } else {
                    gop.key_ptr.* = name_index;
                }
                try self.ast.tree.append(self.allocator, .{
                    .tag = .symbol,
                    .data = .{
                        .symbol = .{
                            .offset = name_index,
                            .len = name.len,
                        },
                    },
                });
            },
            .int => {
                self.addListItem();
                const raw = self.tokenizer.rawForToken(tok);
                const parsed = try std.fmt.parseInt(i64, raw, 10);
                try self.ast.tree.append(self.allocator, .{ .tag = .int, .data = .{
                    .int = parsed,
                } });
            },
            .float => {
                self.addListItem();
                const raw = self.tokenizer.rawForToken(tok);
                const parsed = try std.fmt.parseFloat(f64, raw);
                try self.ast.tree.append(self.allocator, .{
                    .tag = .float,
                    .data = .{
                        .float = parsed,
                    },
                });
            },
            .char => {
                self.addListItem();
                const raw = self.tokenizer.rawForToken(tok);
                try self.ast.tree.append(self.allocator, .{
                    .tag = .char,
                    .data = .{ .char = raw[raw.len - 1] },
                });
            },
            .string => {
                self.addListItem();
                const raw = self.tokenizer.rawForToken(tok);
                try self.ast.tree.append(self.allocator, .{
                    .tag = .string,
                    .data = .{
                        .string = try self.allocator.dupe(u8, raw),
                    },
                });
            },
            .l_brace => {
                self.addListItem();
                const nodeIndex = self.ast.tree.items(.tag).len;
                try self.ast.tree.append(self.allocator, .{
                    .tag = .list,
                    .data = .{
                        .list = .{},
                    },
                });
                try self.unclosed.append(self.allocator, .{
                    .tag = .brace,
                    .node = nodeIndex,
                });
            },
            .l_paren => {
                self.addListItem();
                const nodeIndex = self.ast.tree.items(.tag).len;
                try self.ast.tree.append(self.allocator, .{
                    .tag = .list,
                    .data = .{
                        .list = .{},
                    },
                });
                try self.unclosed.append(self.allocator, .{
                    .tag = .paren,
                    .node = nodeIndex,
                });
            },
            .l_bracket => {
                self.addListItem();
                const nodeIndex = self.ast.tree.items(.tag).len;
                try self.ast.tree.append(self.allocator, .{
                    .tag = .list,
                    .data = .{
                        .list = .{},
                    },
                });
                try self.unclosed.append(self.allocator, .{
                    .tag = .bracket,
                    .node = nodeIndex,
                });
            },
            .r_brace, .r_paren, .r_bracket => |closing| {
                const opening_tag: OpenCollection.Tag = switch (closing) {
                    Token.Tag.r_brace => .brace,
                    Token.Tag.r_paren => .paren,
                    Token.Tag.r_bracket => .bracket,
                    else => unreachable,
                };
                const last = self.unclosed.popOrNull();
                if (last) |opened| {
                    std.debug.print("Closing {s} at {d}\n", .{ @tagName(opened.tag), opened.node });
                    if (opened.tag != opening_tag) return error.Unclosed;
                    const data = self.ast.tree.items(.data);
                    data[opened.node].list.next = data.len;
                } else {
                    return error.Unopened;
                }
            },
            .eof => unreachable,
            .invalid => {
                // TODO: Handle skipping to the next valid form
                return error.Invalid;
            },
        }
    }

    return self.ast;
}

fn addListItem(self: *Parser) void {
    const last = self.unclosed.getLastOrNull();
    if (last) |unclosed| {
        assert(self.ast.tree.items(.tag)[unclosed.node] == .list);
        const data = self.ast.tree.items(.data);
        data[unclosed.node].list.len += 1;
    }
}

fn next(self: *Parser) ?Token {
    const tok = self.tokenizer.next();
    log.debug("Next token is: {s} at ({d}-{d})", .{ @tagName(tok.tag), tok.loc.start, tok.loc.end });
    if (tok.tag == .eof) return null;
    return tok;
}

test "simple list" {
    const input: [:0]const u8 = "(+ 1 2)";
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator, input);

    var ast = try parser.parse();
    defer ast.deinit(allocator);

    try std.testing.expectEqualSlices(Value.Tag, &.{ .list, .symbol, .int, .int }, ast.tree.items(.tag));
    try std.testing.expectEqualSlices(Value.Data, &.{
        .{ .list = .{ .len = 3, .next = 4 } },
        .{ .symbol = .{ .len = 1, .offset = 0 } },
        .{ .int = 1 },
        .{ .int = 2 },
    }, ast.tree.items(.data));
    try std.testing.expectEqualSlices(u8, "+", ast.string_bytes.items);
}

test "nested lists" {
    const input: [:0]const u8 = "(+ 1 (* 2 (/ 10 2) 2) 4 )";
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator, input);

    var ast = try parser.parse();
    defer ast.deinit(allocator);

    try std.testing.expectEqualSlices(u8, "+*/", ast.string_bytes.items);

    const tags = ast.tree.items(.tag);
    try std.testing.expectEqualSlices(Value.Tag, &.{
        .list, .symbol, .int, .list, .symbol, .int, .list, .symbol, .int, .int, .int, .int,
    }, tags);
    const data = ast.tree.items(.data);
    const outer_list = data[0];
    try std.testing.expectEqual(Value.Data{ .list = .{ .len = 4, .next = data.len } }, outer_list);

    const first_inner_list = data[3];
    try std.testing.expectEqual(Value.Data{ .list = .{ .len = 4, .next = data.len - 1 } }, first_inner_list);

    const most_inner_list = data[6];
    try std.testing.expectEqual(Value.Data{ .list = .{ .len = 3, .next = data.len - 2 } }, most_inner_list);
}
