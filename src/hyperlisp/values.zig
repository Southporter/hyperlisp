pub const Value = struct {
    tag: Tag,
    data: Data,

    pub const Nil = Value{
        .tag = .nil,
        .data = .{ .nil = {} },
    };
    pub const True = Value{
        .tag = .true,
        .data = .{ .true = {} },
    };

    pub const Tag = enum {
        nil,
        true,
        int,
        float,
        char,
        string,
        list,
        symbol,
    };

    pub const SymbolData = struct {
        offset: usize,
        len: usize,
        id: u64,
    };
    const ListData = struct {
        len: usize = 0,
        next: usize = 0,
    };

    pub const Data = union(enum) {
        nil: void,
        true: void,
        int: i64,
        float: f64,
        char: u32,
        string: []const u8,
        symbol: SymbolData,
        list: ListData,
    };
};
