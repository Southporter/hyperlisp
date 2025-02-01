const std = @import("std");
const lib = @import("hyperlisp");

const readline = @cImport({
    @cInclude("stdio.h");
    @cInclude("readline/readline.h");
    @cInclude("readline/history.h");
});

const prompt: [:0]const u8 = "λ> ";

fn toSlice(ptr: [*c]u8) [:0]u8 {
    var len: usize = 0;
    while (ptr[len] != 0) {
        len += 1;
    }
    const new_ptr = @as([*:0]u8, ptr);
    return new_ptr[0..len :0];
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    var input = readline.readline(prompt.ptr);
    var env = lib.Env.init(allocator);
    defer env.deinit();
    env.addBuiltins() catch unreachable;
    env.addLambda(lib.hash("print"), &print) catch unreachable;

    while (input != null) : (input = readline.readline(prompt.ptr)) {
        defer std.c.free(input);
        defer input = null;

        const slice = toSlice(input);
        if (slice.len == 0) {
            continue;
        }
        readline.add_history(input);
        var val = lib.eval(env, allocator, slice) catch |err| {
            _ = try stdout.write("Error: Unable to eval - ");
            try stdout.print("{any}\n", .{err});
            continue;
        };
        defer val.deinit(allocator);
        try lib.print(stdout, val);
        try stdout.writeByte('\n');
    }
}

fn print(allocator: std.mem.Allocator, ast: lib.Parser.Ast) lib.NativeFnError!lib.Value {
    _ = allocator;
    const stdout = std.io.getStdOut().writer();
    lib.print(stdout, ast) catch return lib.NativeFnError.Unknown;
    return lib.Value.Nil;
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
