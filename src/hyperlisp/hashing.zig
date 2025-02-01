const std = @import("std");
const hasher = std.hash.Fnv1a_64;

pub fn hash(input: []const u8) u64 {
    return hasher.hash(input);
}
