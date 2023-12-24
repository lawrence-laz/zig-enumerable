pub fn TokenIterator(comptime TTokenIterator: type) type {
    return struct {
        const Self = @This();

        token_iterator: TTokenIterator,

        pub fn next(self: *Self) ?[]const u8 {
            return self.token_iterator.next();
        }
    };
}
