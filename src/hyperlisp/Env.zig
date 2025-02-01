const std = @import("std");
const log = std.log.scoped(.env);
const Value = @import("values.zig").Value;
const Hashing = @import("hashing.zig");
const builtins = @import("builtins.zig");

const Env = @This();
allocator: std.mem.Allocator,
entries: std.MultiArrayList(Entry) = .empty,
floats: std.ArrayListUnmanaged(f64) = .empty,
ints: std.ArrayListUnmanaged(i64) = .empty,

pub const Entry = struct {
    key: u64,
    tag: Entry.Tag,
    data: Entry.Data,

    pub const Tag = enum {
        nil,
        true,
        int,
        float,
        extern_fn,
        lambda,
    };

    pub const Data = union {
        nil: void,
        true: void,
        // Index into ints array
        int: usize,
        // Index into floats array
        float: usize,

        extern_fn: usize,
        lambda: builtins.NativeFn,
    };
};

pub fn init(allocator: std.mem.Allocator) Env {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(env: *Env) void {
    env.entries.deinit(env.allocator);
    env.floats.deinit(env.allocator);
    env.ints.deinit(env.allocator);
}

pub fn get(env: Env, id: u64) ?Entry {
    var index: usize = std.math.maxInt(usize);
    log.debug("Entry keys: {d}", .{env.entries.items(.key)});
    for (env.entries.items(.key), 0..) |key, i| {
        if (key == id) {
            index = i;
            break;
        }
    }

    if (index == std.math.maxInt(usize)) {
        return null;
    }
    return env.entries.get(index);
}

pub fn add(
    env: *Env,
    comptime T: type,
    name: []const u8,
    value: T,
) !void {
    switch (@typeInfo(T)) {
        .Int => try addInt(env, Hashing.hash(name), value),
        .Float => try addFloat(env, Hashing.hash(name), value),
        else => return error.UnableToAddSymbol,
    }
}

fn addInt(env: *Env, id: u64, value: i64) !void {
    const index = env.ints.len;
    try env.ints.append(value);
    try env.entries.append(env.allocator, Entry{
        .key = id,
        .tag = .int,
        .data = .{ .int = index },
    });
}

fn addFloat(env: *Env, id: u64, value: f64) !void {
    const index = env.floats.len;
    try env.floats.append(value);
    try env.entries.append(env.allocator, Entry{
        .key = id,
        .tag = .float,
        .data = .{ .float = index },
    });
}

pub fn addLambda(env: *Env, id: u64, value: builtins.NativeFn) !void {
    try env.entries.append(env.allocator, Entry{
        .key = id,
        .tag = .lambda,
        .data = .{ .lambda = value },
    });
}

pub fn addBuiltins(env: *Env) !void {
    try env.addLambda(Hashing.hash("+"), &builtins.add);
    try env.addLambda(Hashing.hash("-"), &builtins.sub);
    try env.addLambda(Hashing.hash("*"), &builtins.mul);
    try env.addLambda(Hashing.hash("/"), &builtins.div);
}
