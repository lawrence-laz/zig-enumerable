pub fn SliceIterator(comptime TItem: type) type {
    return struct {
        const Self = @This();

        slice: []const TItem,
        index: usize = 0,
        reversed: bool = false,
        completed: bool = false,

        pub fn next(self: *Self) ?TItem {
            if (self.reversed) {
                if (self.index >= 0 and !self.completed) {
                    const item = self.slice[self.index];
                    if (self.index > 0) {
                        self.index -= 1;
                    } else {
                        self.completed = true;
                    }
                    return item;
                }
            } else {
                if (self.index < self.slice.len) {
                    const item = self.slice[self.index];
                    self.index += 1;
                    return item;
                }
            }

            return null;
        }

        pub fn reverse(self: *Self) SliceIterator(TItem) {
            self.reversed = true;
            self.index = self.slice.len - 1;
            return self.*;
        }
    };
}
