const std = @import("std");
const lib = @import("hyperlisp");

pub const std_options = std.Options{
    .logFn = wasmLog,
};

pub fn wasmLog(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = @tagName(scope);
    const prefix = "[" ++ comptime level.asText() ++ "](" ++ scope_prefix ++ ")";

    var buf: [4096]u8 = undefined;

    const message = std.fmt.bufPrint(&buf, prefix ++ format, args) catch return;
    nosuspend sendString(message.ptr, message.len);
}

pub extern fn sendString(offset: [*]const u8, len: usize) void;
pub const LogLevel = enum(u32) {
    debug = 3,
    info = 2,
    warn = 1,
    err = 0,
};
pub extern fn log(level: LogLevel, offset: [*]const u8, len: usize) void;
pub extern fn logUint(level: LogLevel, value: u64) void;

const Str = packed struct {
    ptr: [*]const u8,
    len: usize,
};

const allocator = std.heap.wasm_allocator;

export fn alloc(len: usize) usize {
    const buf = allocator.alloc(u8, len) catch return 0;
    return @intFromPtr(buf.ptr);
}

export fn free(ptr: [*]u8, len: usize) void {
    allocator.free(ptr[0..len]);
}

export fn eval(ptr: [*:0]u8, len: usize) u32 {
    logUint(.debug, @intFromPtr(ptr));
    logUint(.info, len);
    const input: [:0]const u8 = ptr[0..len :0];
    std.debug.assert(input[len] == 0);

    const res = lib.eval(allocator, input) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "Error: Unable to eval - {any}", .{err}) catch
        // return .{ .ptr = @ptrFromInt(1), .len = 0 };
            return 254;
        sendString(msg.ptr, msg.len);
        // return .{ .ptr = msg.ptr, .len = msg.len };
        return 255;
    };
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    lib.print(out.writer(), res) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "Error: Unable to print - {any}", .{err}) catch
        // return .{ .ptr = @ptrFromInt(1), .len = 0 };
            return 259;
        sendString(msg.ptr, msg.len);
        // return .{ .ptr = msg.ptr, .len = msg.len };
        return 256;
    };
    const output = out.toOwnedSlice() catch |err| {
        const msg = std.fmt.allocPrint(allocator, "Error: Unable to convert to slice - {any}", .{err}) catch
        // return .{ .ptr = @ptrFromInt(1), .len = 0 };
            return 258;
        sendString(msg.ptr, msg.len);
        // return .{ .ptr = msg.ptr, .len = msg.len };
        return 257;
    };
    sendString(output.ptr, output.len);
    // return .{ .ptr = output.ptr, .len = output.len };
    return 0;
}

pub fn main() void {}
