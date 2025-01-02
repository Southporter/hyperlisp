pub const Value = struct {
    tag: Tag,
    data: Data,

    const Tag = enum {
        nil,
        true,
        int,
        float,
        string,
        list,
        symbol,
    };

    const Data = union {
        int: i64,
        float: f64,
        string: []const u8,
        symbol: usize,
    };
};
