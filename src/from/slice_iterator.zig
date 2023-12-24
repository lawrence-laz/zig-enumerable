pub fn SliceIterator(comptime TItem: type) type {
    return struct {
        const Self = @This();

        slice: []const TItem,
        index: usize = 0,

        pub fn next(self: *Self) ?TItem {
            if (self.index < self.slice.len) {
                const item = self.slice[self.index];
                self.index += 1;
                return item;
            }

            return null;
        }
    };
}
