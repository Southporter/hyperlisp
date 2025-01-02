const std = @import("std");
const lib = @import("hyperlisp");

const readline = @cImport({
    @cInclude("stdio.h");
    @cInclude("readline/readline.h");
    @cInclude("readline/history.h");
});

const prompt: [:0]const u8 = "λ> ";

fn toSlice(ptr: [*c]u8) []u8 {
    var len: usize = 0;
    while (ptr[len] != 0) {
        len += 1;
    }
    const new_ptr = @as([*]u8, ptr);
    return new_ptr[0..len];
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    _ = allocator;

    const stdout = std.io.getStdOut().writer();

    var input = readline.readline(prompt.ptr);

    while (input != null) {
        readline.add_history(input);
        defer std.c.free(input);
        const slice = toSlice(input);
        const val = try lib.eval(slice);
        const output = lib.print(val);
        try stdout.writeAll(output);
        try stdout.writeByte('\n');

        input = readline.readline(prompt.ptr);
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const global = struct {
        fn testOne(input: []const u8) anyerror!void {
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(global.testOne, .{});
}
