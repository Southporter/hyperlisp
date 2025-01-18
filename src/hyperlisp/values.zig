pub const Value = struct {
    tag: Tag,
    data: Data,

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

    const SymbolData = struct {
        offset: usize,
        len: usize,
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
