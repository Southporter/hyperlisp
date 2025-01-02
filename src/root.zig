const std = @import("std");
const Value = @import("values.zig").Value;

pub fn eval(input: []const u8) !Value {
    return Value{
        .tag = .string,
        .data = .{ .string = input },
    };
}

pub fn print(val: Value) []const u8 {
    return val.data.string;
}
