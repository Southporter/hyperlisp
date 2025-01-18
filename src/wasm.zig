const std = @import("std");
const lib = @import("hyperlisp");

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

export fn eval(ptr: [*:0]u8, len: usize) Str {
    logUint(.debug, @intFromPtr(ptr));
    logUint(.info, len);
    const input: [:0]const u8 = ptr[0..len :0];
    const res = lib.eval(allocator, input) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "Error: Unable to eval - {any}", .{err}) catch return .{ .ptr = @ptrFromInt(1), .len = 0 };
        sendString(msg.ptr, msg.len);
        return .{ .ptr = msg.ptr, .len = msg.len };
    };
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    lib.print(out.writer(), res) catch |err| {
        const msg = std.fmt.allocPrint(allocator, "Error: Unable to print - {any}", .{err}) catch return .{ .ptr = @ptrFromInt(1), .len = 0 };
        sendString(msg.ptr, msg.len);
        return .{ .ptr = msg.ptr, .len = msg.len };
    };
    const output = out.toOwnedSlice();
    sendString(output.ptr, output.len);
    return .{ .ptr = output.ptr, .len = output.len };
}

pub fn main() void {}
