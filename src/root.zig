const std = @import("std");
const Value = @import("hyperlisp/values.zig").Value;
const Parser = @import("hyperlisp/Parser.zig");
const List = Parser.List;

pub fn eval(allocator: std.mem.Allocator, input: [:0]const u8) !Parser.Ast {
    var parser = Parser.init(allocator, input);
    const list = parser.parse();
    return list;
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
