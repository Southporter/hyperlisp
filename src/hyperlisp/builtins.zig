const std = @import("std");
const Value = @import("values.zig").Value;
const Ast = @import("Parser.zig").Ast;

pub const NativeFnError = error{
    InvalidArgs,
    DivideByZero,
    Unknown,
};
pub const NativeFn = *const fn (allocator: std.mem.Allocator, args: Ast) NativeFnError!Value;

pub fn add(allocator: std.mem.Allocator, args: Ast) NativeFnError!Value {
    _ = allocator;
    if (args.tree.len < 2) {
        return error.InvalidArgs;
    }

    var sum = args.tree.get(0);
    for (1..args.tree.len) |arg_i| {
        const arg = args.tree.get(arg_i);
        switch (arg.tag) {
            .int => {
                switch (sum.tag) {
                    .int => sum.data.int += arg.data.int,
                    .float => sum.data.float += @floatFromInt(arg.data.int),
                    else => return error.InvalidArgs,
                }
            },
            .float => {
                switch (sum.tag) {
                    .int => sum = Value{
                        .tag = .float,
                        .data = .{
                            .float = @as(f64, @floatFromInt(sum.data.int)) + arg.data.float,
                        },
                    },
                    .float => sum.data.float += arg.data.float,
                    else => return error.InvalidArgs,
                }
            },
            else => return error.InvalidArgs,
        }
    }
    return sum;
}

pub fn sub(allocator: std.mem.Allocator, args: Ast) NativeFnError!Value {
    _ = allocator;
    if (args.tree.len < 2) {
        return error.InvalidArgs;
    }

    var sum = args.tree.get(0);
    for (1..args.tree.len) |arg_i| {
        const arg = args.tree.get(arg_i);
        switch (arg.tag) {
            .int => {
                switch (sum.tag) {
                    .int => sum.data.int -= arg.data.int,
                    .float => sum.data.float -= @floatFromInt(arg.data.int),
                    else => return error.InvalidArgs,
                }
            },
            .float => {
                switch (sum.tag) {
                    .int => sum = Value{
                        .tag = .float,
                        .data = .{
                            .float = @as(f64, @floatFromInt(sum.data.int)) - arg.data.float,
                        },
                    },
                    .float => sum.data.float -= arg.data.float,
                    else => return error.InvalidArgs,
                }
            },
            else => return error.InvalidArgs,
        }
    }
    return sum;
}

pub fn mul(allocator: std.mem.Allocator, args: Ast) NativeFnError!Value {
    _ = allocator;
    if (args.tree.len < 2) {
        return error.InvalidArgs;
    }

    var sum = args.tree.get(0);
    for (1..args.tree.len) |arg_i| {
        const arg = args.tree.get(arg_i);
        switch (arg.tag) {
            .int => {
                switch (sum.tag) {
                    .int => sum.data.int *= arg.data.int,
                    .float => sum.data.float *= @floatFromInt(arg.data.int),
                    else => return error.InvalidArgs,
                }
            },
            .float => {
                switch (sum.tag) {
                    .int => sum = Value{
                        .tag = .float,
                        .data = .{
                            .float = @as(f64, @floatFromInt(sum.data.int)) * arg.data.float,
                        },
                    },
                    .float => sum.data.float *= arg.data.float,
                    else => return error.InvalidArgs,
                }
            },
            else => return error.InvalidArgs,
        }
    }
    return sum;
}

pub fn div(allocator: std.mem.Allocator, args: Ast) NativeFnError!Value {
    _ = allocator;
    if (args.tree.len < 2) {
        return error.InvalidArgs;
    }

    var sum = args.tree.get(0);
    for (1..args.tree.len) |arg_i| {
        const arg = args.tree.get(arg_i);
        switch (arg.tag) {
            .int => {
                if (arg.data.int == 0) {
                    return error.DivideByZero;
                }
                switch (sum.tag) {
                    .int => sum.data.int = @divTrunc(sum.data.int, arg.data.int),
                    .float => sum.data.float /= @floatFromInt(arg.data.int),
                    else => return error.InvalidArgs,
                }
            },
            .float => {
                if (arg.data.float == 0.0) {
                    return error.DivideByZero;
                }
                switch (sum.tag) {
                    .int => sum = Value{
                        .tag = .float,
                        .data = .{
                            .float = @as(f64, @floatFromInt(sum.data.int)) / arg.data.float,
                        },
                    },
                    .float => sum.data.float /= arg.data.float,
                    else => return error.InvalidArgs,
                }
            },
            else => return error.InvalidArgs,
        }
    }
    return sum;
}
