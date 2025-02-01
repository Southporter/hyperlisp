const std = @import("std");
const log = std.log.scoped(.hyperlisp);
const compiler_builtins = @import("builtin");
pub const Value = @import("hyperlisp/values.zig").Value;
pub const Parser = @import("hyperlisp/Parser.zig");
const builtins = @import("hyperlisp/builtins.zig");
const List = Parser.List;
pub const Env = @import("hyperlisp/Env.zig");

pub const NativeFn = builtins.NativeFn;
pub const NativeFnError = builtins.NativeFnError;

pub const hash = @import("hyperlisp/hashing.zig").hash;

pub fn eval(env: Env, allocator: std.mem.Allocator, input: [:0]const u8) !Parser.Ast {
    var parser = Parser.init(allocator, input);
    const list = try parser.parse();
    defer parser.ast.tree.deinit(allocator);

    if (parser.ast.tree.len == 0) {
        return error.EmptyInput;
    }
    // if (compiler_builtins.mode == .Debug) {
    //     try parser.printAst(std.debug.global_writer(), list);
    // }
    var res: Parser.Ast = .{
        .string_bytes = list.string_bytes,
        .symbol_pool = list.symbol_pool,
    };
    try evalElement(env, list, 0, &res);
    return res;
}

fn evalElement(env: Env, ast: Parser.Ast, offset: usize, result: *Parser.Ast) !void {
    const tags = ast.tree.items(.tag);
    const node = tags[offset];
    const data = ast.tree.items(.data);
    log.debug("Eval: {s}", .{@tagName(node)});
    try switch (node) {
        .nil => result.tree.append(env.allocator, Value{ .tag = .nil, .data = .{ .nil = {} } }),
        .true => result.tree.append(env.allocator, Value{ .tag = .true, .data = .{ .true = {} } }),
        .int => result.tree.append(env.allocator, Value{ .tag = .int, .data = .{ .int = data[offset].int } }),
        .float => result.tree.append(env.allocator, Value{ .tag = .float, .data = .{ .float = data[offset].float } }),
        .char => result.tree.append(env.allocator, Value{ .tag = .char, .data = .{ .char = data[offset].char } }),
        .string => result.tree.append(env.allocator, Value{ .tag = .string, .data = .{ .string = data[offset].string } }),
        .list => {
            const d = data[offset];
            if (tags[offset + 1] != .symbol) {
                return error.InvalidFunction;
            }
            const fn_name = data[offset + 1].symbol;
            var args: Parser.Ast = .{
                .symbol_pool = ast.symbol_pool,
                .string_bytes = ast.string_bytes,
            };
            defer args.tree.deinit(env.allocator);

            var sub_offset = offset + 2;
            while (sub_offset < d.list.next) {
                try evalElement(env, ast, sub_offset, &args);
                if (ast.tree.items(.tag)[sub_offset] == .list) {
                    sub_offset = data[sub_offset].list.next;
                } else {
                    sub_offset += 1;
                }
            }
            log.debug("Symbol lookup: ({d}) {s}", .{ fn_name.id, args.symbolName(fn_name) });
            const entry = env.get(fn_name.id) orelse return error.SymbolNotFound;
            switch (entry.tag) {
                .lambda => {
                    const lambda = entry.data.lambda;
                    try result.tree.append(env.allocator, try lambda(env.allocator, args));
                },
                .extern_fn => return error.NotImplemented,
                else => return error.SymbolNotAFunction,
            }
        },
        else => unreachable,
    };
}

pub fn print(writer: anytype, value: Parser.Ast) !void {
    const tags = value.tree.items(.tag);
    const data = value.tree.items(.data);

    std.debug.assert(tags.len > 0);
    return printElement(writer, 0, tags, data, value.string_bytes.items, .first);
}

const Position = enum { first, other };

fn printElement(writer: anytype, offset: usize, tags: []Value.Tag, data: []Value.Data, bytes: []const u8, position: Position) !void {
    const node = tags[offset];
    if (position == .other) {
        _ = try writer.write(" ");
    }
    switch (node) {
        .nil, .true => {
            try writer.writeAll(@tagName(node));
        },
        .symbol => {
            const d = data[offset];
            const end = d.symbol.offset + d.symbol.len;
            const name = bytes[d.symbol.offset..end];
            try writer.writeAll(name);
        },
        .string => {
            const d = data[offset];
            try writer.writeAll(d.string);
        },
        .int => {
            const d = data[offset];
            try writer.print("{d}", .{d.int});
        },
        .float => {
            const d = data[offset];
            try writer.print("{d}", .{d.float});
        },
        .char => {
            const d = data[offset];
            // TODO Change this to support unicode points
            const byte: u8 = @truncate(d.char);
            try writer.print("\\{c}", .{byte});
        },
        .list => {
            _ = try writer.write("(");
            var sub_position = Position.first;
            const d = data[offset];
            var sub_offset = offset + 1;

            while (sub_offset < d.list.next) {
                _ = try printElement(writer, sub_offset, tags, data, bytes, sub_position);
                sub_position = .other;
                if (tags[sub_offset] == .list) {
                    sub_offset = data[sub_offset].list.next;
                } else {
                    sub_offset += 1;
                }
            }
            _ = try writer.write(")");
        },
    }
}
