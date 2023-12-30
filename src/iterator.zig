const std = @import("std");
const from = @import("from.zig");
const WhereIterator = @import("where_iterator.zig").WhereIterator;
const SelectIterator = @import("select_iterator.zig").SelectIterator;
const WindowIterator = @import("window_iterator.zig").WindowIterator;
const ConcatIterator = @import("concat_iterator.zig").ConcatIterator;
const ZipIterator = @import("zip_iterator.zig").ZipIterator;
const AppendIterator = @import("append_iterator.zig").AppendIterator;
const TakeIterator = @import("take_iterator.zig").TakeIterator;
const TakeEveryIterator = @import("take_every_iterator.zig").TakeEveryIterator;
const TakeWhileIterator = @import("take_while_iterator.zig").TakeWhileIterator;
const SkipIterator = @import("skip_iterator.zig").SkipIterator;
const SkipWhileIterator = @import("skip_while_iterator.zig").SkipWhileIterator;
const PeekableIterator = @import("peekable_iterator.zig").PeekableIterator;
const IntersperseIterator = @import("intersperse_iterator.zig").IntersperseIterator;
const ScanIterator = @import("scan_iterator.zig").ScanIterator;
const SliceIterator = @import("from/slice_iterator.zig").SliceIterator;

pub fn Iterator(comptime TItem: type, comptime TImpl: type) type {
    return struct {
        const Self = @This();

        impl: TImpl,

        pub fn next(self: *Self) ?TItem {
            return self.impl.next();
        }

        pub fn count(self: *const Self) usize {
            const self_x = @constCast(self);
            var result: usize = 0;
            while (self_x.next()) |_| {
                result += 1;
            }
            return result;
        }

        pub fn sum(self: *const Self) TItem {
            const self_x = @constCast(self);
            var result: TItem = 0;
            while (self_x.next()) |number| {
                result += number;
            }
            return result;
        }

        pub fn any(
            self: *const Self,
            comptime filter: fn (TItem) bool,
        ) bool {
            const self_x = @constCast(self);
            while (self_x.next()) |item| {
                if (filter(item)) {
                    return true;
                }
            }
            return false;
        }

        pub fn all(
            self: *const Self,
            comptime filter: fn (TItem) bool,
        ) bool {
            const self_x = @constCast(self);
            while (self_x.next()) |item| {
                if (!filter(item)) {
                    return false;
                }
            }
            return true;
        }

        pub fn firstOrDefault(self: *const Self) ?TItem {
            const self_x = @constCast(self);
            return self_x.next() orelse null;
        }

        pub fn lastOrDefault(self: *const Self) ?TItem {
            const self_x = @constCast(self);
            var last: ?TItem = null;
            while (self_x.next()) |item| {
                last = item;
            }
            return last;
        }

        pub fn elementAt(self: *const Self, index: usize) ?TItem {
            const self_x = @constCast(self);
            var current_index: usize = 0;
            while (current_index < index) {
                _ = self_x.next();
                current_index += 1;
            }
            return self_x.next();
        }

        pub inline fn where(
            self: *const Self,
            comptime filter: fn (TItem) bool,
        ) Iterator(TItem, WhereIterator(TItem, filter, TImpl)) {
            const foo = @constCast(&self.impl);
            return .{ .impl = WhereIterator(TItem, filter, TImpl){ .prev_iter = foo } };
        }

        pub inline fn select(
            self: *const Self,
            comptime TDest: type,
            comptime project: fn (TItem) TDest,
        ) Iterator(TDest, SelectIterator(TItem, TDest, project, TImpl)) {
            const foo = @constCast(&self.impl);
            return .{ .impl = SelectIterator(TItem, TDest, project, TImpl){ .prev_iter = foo } };
        }

        pub inline fn window(
            self: *const Self,
            comptime size: usize,
        ) Iterator([size]TItem, WindowIterator(TItem, size, TImpl)) {
            const foo = @constCast(&self.impl);
            return .{ .impl = WindowIterator(TItem, size, TImpl){
                .prev_iter = foo,
                .maybe_window = null,
            } };
        }

        pub inline fn scan(
            self: *const Self,
            comptime TState: type,
            comptime function: fn (TState, TItem) TState,
            initial_state: TState,
        ) Iterator(TState, ScanIterator(TItem, TState, function, TImpl)) {
            const foo = @constCast(&self.impl);
            return .{ .impl = ScanIterator(TItem, TState, function, TImpl){
                .state = initial_state,
                .prev_iter = foo,
            } };
        }

        pub inline fn aggregate(
            self: *const Self,
            comptime TDest: type,
            comptime function: fn (TDest, TItem) TDest,
            seed: TDest,
        ) TDest {
            const self_x = @constCast(&self.impl);
            var result: TDest = seed;
            while (self_x.next()) |item| {
                result = function(result, item);
            }
            return result;
        }

        pub inline fn contains(
            self: *const Self,
            needle: TItem,
        ) bool {
            const self_x = @constCast(&self.impl);
            while (self_x.next()) |item| {
                if (item == needle) {
                    return true;
                }
            }
            return false;
        }

        pub inline fn sequenceEqual(
            self: *const Self,
            other_iter: anytype,
        ) bool {
            const self_x = @constCast(&self.impl);
            const other_x = @constCast(other_iter);
            while (true) {
                var first_item = self_x.next();
                var second_item = other_x.next();

                if (first_item == null and second_item == null) {
                    return true;
                }

                if (first_item != second_item) {
                    return false;
                }
            }
        }

        pub inline fn indexOf(
            self: *const Self,
            needle: TItem,
        ) ?usize {
            const self_x = @constCast(&self.impl);
            var index: usize = 0;
            while (self_x.next()) |item| {
                if (item == needle) {
                    return index;
                }
                index += 1;
            }
            return null;
        }

        pub inline fn concat(
            self: *const Self,
            other_iter: anytype,
        ) Iterator(TItem, ConcatIterator(TItem, TImpl, @TypeOf(other_iter.*))) {
            const foo = @constCast(&self.impl);
            return .{ .impl = ConcatIterator(TItem, TImpl, @TypeOf(other_iter.*)){
                .prev_iter = foo,
                .next_iter = other_iter,
            } };
        }

        fn getIterItemType(iter: anytype) type {
            var iter_type = @TypeOf(iter.next);
            var iter_type_info = @typeInfo(iter_type);
            return iter_type_info.Fn.return_type;
        }

        pub inline fn zip(
            self: *const Self,
            comptime TOtherItem: type,
            other_iter: anytype,
        ) Iterator(struct { TItem, TOtherItem }, ZipIterator(TItem, TImpl, @TypeOf(other_iter.*), TOtherItem)) {
            const foo = @constCast(&self.impl);
            return .{ .impl = ZipIterator(TItem, TImpl, @TypeOf(other_iter.*), TOtherItem){
                .prev_iter = foo,
                .other_iter = other_iter,
            } };
        }

        pub inline fn append(
            self: *const Self,
            appended_item: TItem,
        ) Iterator(TItem, AppendIterator(TItem, TImpl)) {
            const foo = @constCast(&self.impl);
            return .{ .impl = AppendIterator(TItem, TImpl){
                .prev_iter = foo,
                .appended_item = appended_item,
            } };
        }

        pub inline fn intersperse(
            self: *const Self,
            delimiter: TItem,
        ) Iterator(TItem, IntersperseIterator(TItem, TImpl)) {
            return .{ .impl = IntersperseIterator(TItem, TImpl){
                .prev_iter = self.peekable().impl,
                .delimiter = delimiter,
                .next_is_delimiter = false,
            } };
        }

        pub inline fn peekable(self: *const Self) Iterator(TItem, PeekableIterator(TItem, TImpl)) {
            const foo = @constCast(&self.impl);
            return .{ .impl = PeekableIterator(TItem, TImpl){
                .prev_iter = foo,
                .peeked_item = null,
            } };
        }

        pub inline fn take(
            self: *const Self,
            item_count: usize,
        ) Iterator(TItem, TakeIterator(TItem, TImpl)) {
            const self_x = @constCast(&self.impl);
            return .{ .impl = TakeIterator(TItem, TImpl){
                .prev_iter = self_x,
                .index = 0,
                .count = item_count,
            } };
        }

        pub inline fn takeEvery(
            self: *const Self,
            every_nth: usize,
        ) Iterator(TItem, TakeEveryIterator(TItem, TImpl)) {
            const self_x = @constCast(&self.impl);
            return .{ .impl = TakeEveryIterator(TItem, TImpl){
                .prev_iter = self_x,
                .every_nth = every_nth,
            } };
        }

        pub inline fn takeWhile(
            self: *const Self,
            comptime filter: fn (TItem) bool,
        ) Iterator(TItem, TakeWhileIterator(TItem, filter, TImpl)) {
            const self_x = @constCast(&self.impl);
            return .{ .impl = TakeWhileIterator(TItem, filter, TImpl){
                .prev_iter = self_x,
                .completed = false,
            } };
        }

        pub inline fn toArrayList(
            self: *const Self,
            allocator: std.mem.Allocator,
        ) !std.ArrayList(TItem) {
            const self_x = @constCast(&self.impl);
            var array_list = std.ArrayList(TItem).init(allocator);
            while (self_x.next()) |item| {
                try array_list.append(item);
            }
            return array_list;
        }

        pub inline fn skip(
            self: *const Self,
            item_count: usize,
        ) Iterator(TItem, SkipIterator(TItem, TImpl)) {
            const self_x = @constCast(&self.impl);
            return .{ .impl = SkipIterator(TItem, TImpl){
                .prev_iter = self_x,
                .index = 0,
                .count = item_count,
            } };
        }

        pub inline fn skipWhile(
            self: *const Self,
            comptime filter: fn (TItem) bool,
        ) Iterator(TItem, SkipWhileIterator(TItem, filter, TImpl)) {
            const self_x = @constCast(&self.impl);
            return .{ .impl = SkipWhileIterator(TItem, filter, TImpl){
                .prev_iter = self_x,
                .skipping_is_done = false,
            } };
        }

        pub inline fn forEach(
            self: *const Self,
            action: *const fn (TItem) void,
        ) void {
            const self_x = @constCast(self);
            while (self_x.next()) |item| {
                action(item);
            }
        }

        pub inline fn inspect(
            self: *const Self,
            action: *const fn (TItem) void,
        ) Iterator(TItem, TImpl) {
            const self_x = @constCast(self);
            while (self_x.next()) |item| {
                action(item);
            }
            return self_x.*;
        }

        pub inline fn max(self: *const Self) ?TItem {
            var self_x = @constCast(self);
            var maybe_max_value: ?TItem = null;
            while (self_x.next()) |item| {
                if (maybe_max_value == null or item > maybe_max_value.?) {
                    maybe_max_value = item;
                }
            }
            return maybe_max_value;
        }

        pub inline fn min(self: *const Self) ?TItem {
            var self_x = @constCast(self);
            var maybe_min_value: ?TItem = null;
            while (self_x.next()) |item| {
                if (maybe_min_value == null or item < maybe_min_value.?) {
                    maybe_min_value = item;
                }
            }
            return maybe_min_value;
        }

        pub inline fn isSortedAscending(self: *const Self) bool {
            var self_x = @constCast(self);
            var maybe_previous: ?TItem = null;
            while (self_x.next()) |item| {
                if (maybe_previous) |previous| {
                    if (previous > item) {
                        return false;
                    }
                }
                maybe_previous = item;
            }
            return true;
        }

        pub inline fn isSortedDescending(self: *const Self) bool {
            var self_x = @constCast(self);
            var maybe_previous: ?TItem = null;
            while (self_x.next()) |item| {
                if (maybe_previous) |previous| {
                    if (previous < item) {
                        return false;
                    }
                }
                maybe_previous = item;
            }
            return true;
        }

        pub inline fn reverse(
            self: *const Self,
        ) Iterator(TItem, SliceIterator(TItem)) {
            const impl_type_info = @typeInfo(TImpl);
            comptime var is_reverse_implemented: bool = false;
            comptime for (impl_type_info.Struct.decls) |decl| {
                if (std.mem.eql(u8, decl.name, "reverse")) {
                    is_reverse_implemented = true;
                }
            };
            if (is_reverse_implemented) {
                var self_impl = self.impl;
                return .{ .impl = self_impl.reverse() };
            } else {
                @compileError("Iterator '" ++ @typeName(TImpl) ++ "' does not implement .reverse().\n");
            }
        }
    };
}

fn printItem(item: u8) void {
    std.debug.print("\n Item: {}", .{item});
}

test ".forEach()" {
    var input = &[_]u8{ 1, 2, 3, 4, 5 };
    var iter = from.slice(u8, input);
    iter.forEach(printItem);
}

test ".inspect()" {
    var input = &[_]u8{ 1, 2, 3, 4, 5 };
    var iter = from.slice(u8, input);
    _ = iter.inspect(printItem);
}

test ".count()" {
    // Arrange
    const text = "foo\nbar\nbaz\n";
    var lines_iter = std.mem.tokenizeSequence(u8, text, "\n");
    const expected: usize = 3;

    // Act
    var actual = from.tokenIterator([]const u8, &lines_iter).count();

    // Assert
    try std.testing.expectEqual(expected, actual);
}

fn even(number: u8) bool {
    return @rem(number, 2) == 0;
}

test ".where()" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var iterator = from.slice(u8, numbers);

    // Act
    var actual = iterator.where(even);

    // Assert
    const expected = &[_]u8{ 2, 4, 6, 8, 10 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
}

fn negative(number: u8) i8 {
    return @as(i8, @intCast(number)) * -1;
}

test ".select()" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3 };
    var iterator = from.slice(u8, numbers);

    // Act
    var actual = iterator.select(i8, negative);

    // Assert
    const expected = &[_]i8{ -1, -2, -3 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
}

test ".sum()" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3 };
    var iterator = from.slice(u8, numbers);

    // Act
    var actual = iterator.sum();

    // Assert
    const expected: u8 = 6;
    try std.testing.expectEqual(expected, actual);
}

test ".any()" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3 };
    var iterator = from.slice(u8, numbers);

    // Act
    const actual = iterator.any(even);

    // Assert
    try std.testing.expectEqual(true, actual);
}

test ".all(...)" {
    {
        const numbers = &[_]u8{ 2, 4, 6 };
        var iterator = from.slice(u8, numbers);
        const actual = iterator.all(even);
        try std.testing.expectEqual(true, actual);
    }
    {
        const numbers = &[_]u8{ 2, 3, 6 };
        var iterator = from.slice(u8, numbers);
        const actual = iterator.all(even);
        try std.testing.expectEqual(false, actual);
    }
    {
        const numbers = &[_]u8{};
        var iterator = from.slice(u8, numbers);
        const actual = iterator.all(even);
        try std.testing.expectEqual(true, actual);
    }
}

test ".firstOrDefault() when null" {
    // Arrange
    const numbers = &[_]u8{};
    var iterator = from.slice(u8, numbers);

    // Act
    const actual = iterator.firstOrDefault();

    // Assert
    const expected: ?u8 = null;
    try std.testing.expectEqual(expected, actual);
}

test ".firstOrDefault() when not null" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3 };
    var iterator = from.slice(u8, numbers);

    // Act
    const actual = iterator.firstOrDefault();

    // Assert
    const expected: ?u8 = 1;
    try std.testing.expectEqual(expected, actual);
}

test ".lastOrDefault() when null" {
    // Arrange
    const numbers = &[_]u8{};
    var iterator = from.slice(u8, numbers);

    // Act
    const actual = iterator.lastOrDefault();

    // Assert
    const expected: ?u8 = null;
    try std.testing.expectEqual(expected, actual);
}

test ".lastOrDefault() when not null" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3 };
    var iterator = from.slice(u8, numbers);

    // Act
    const actual = iterator.lastOrDefault();

    // Assert
    const expected: ?u8 = 3;
    try std.testing.expectEqual(expected, actual);
}

test ".elementAt() when out of range" {
    // Arrange
    const numbers = &[_]u8{};
    var iterator = from.slice(u8, numbers);

    // Act
    const actual = iterator.elementAt(5);

    // Assert
    const expected: ?u8 = null;
    try std.testing.expectEqual(expected, actual);
}

test ".elementAt() when not null" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3 };
    var iterator = from.slice(u8, numbers);

    // Act
    const actual = iterator.elementAt(2);

    // Assert
    const expected: ?u8 = 3;
    try std.testing.expectEqual(expected, actual);
}

test ".concat()" {
    // Arrange
    const first_slice = &[_]u8{ 1, 2, 3 };
    const second_slice = &[_]u8{ 4, 5, 6 };
    var first_iter = from.slice(u8, first_slice);
    var second_iter = from.slice(u8, second_slice);

    // Act
    var actual = first_iter.concat(&second_iter);

    // Assert
    const expected = &[_]u8{ 1, 2, 3, 4, 5, 6 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 6), index);
}

test ".zip()" {
    // Arrange
    const first_slice = &[_]u8{ 1, 2, 3 };
    const second_slice = &[_]u8{ 4, 5, 6 };
    var first_iter = from.slice(u8, first_slice);
    var second_iter = from.slice(u8, second_slice);

    // Act
    var actual = first_iter.zip(u8, &second_iter);

    // Assert
    const Tuple = struct { u8, u8 };
    const expected = &[_]Tuple{ .{ 1, 4 }, .{ 2, 5 }, .{ 3, 6 } };
    try expectEqualIter(Tuple, expected, actual);
}

test ".append()" {
    // Arrange
    const slice = &[_]u8{ 1, 2, 3 };
    const appended_item: u8 = 4;
    var iter = from.slice(u8, slice);

    // Act
    var actual = iter.append(appended_item);

    // Assert
    const expected = &[_]u8{ 1, 2, 3, 4 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 4), index);
}

test ".take() when iter is long enough, stops at `item_count`" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.take(3);

    // Assert
    const expected = &[_]u8{ 1, 2, 3 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), index);
}

test ".take() when iter is too short, stops at end" {
    // Arrange
    const numbers = &[_]u8{ 1, 2 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.take(3);

    // Assert
    const expected = &[_]u8{ 1, 2 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), index);
}

test ".takeEvery() when no remainder" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.takeEvery(2);

    // Assert
    const expected = &[_]u8{ 2, 4, 6, 8, 10 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 5), index);
}

test ".takeWhile() stop in the middle" {
    // Arrange
    const numbers = &[_]u8{ 2, 4, 6, 7, 8, 9, 10 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.takeWhile(even);

    // Assert
    const expected = &[_]u8{ 2, 4, 6 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), index);
}

test ".takeWhile() stop at the end" {
    // Arrange
    const numbers = &[_]u8{ 2, 4, 6, 8, 10 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.takeWhile(even);

    // Assert
    const expected = &[_]u8{ 2, 4, 6, 8, 10 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 5), index);
}

test ".takeWhile() stop immediately" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3, 4, 5 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.takeWhile(even);

    // Assert
    const expected: ?u8 = null;
    try std.testing.expectEqual(expected, actual.next());
}

test ".skip() when iter is long enough, takes after `item_count`" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.skip(3);

    // Assert
    const expected = &[_]u8{ 4, 5, 6, 7, 8, 9, 10 };
    var index: usize = 0;
    while (actual.next()) |actual_number| {
        try std.testing.expectEqual(expected[index], actual_number);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 7), index);
}

test ".skip() when iter is too short, takes empty" {
    // Arrange
    const numbers = &[_]u8{ 1, 2 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.skip(3);

    // Assert
    const expected: ?u8 = null;
    try std.testing.expectEqual(expected, actual.next());
}

test ".skipWhile() stop in the middle" {
    // Arrange
    const numbers = &[_]u8{ 2, 4, 6, 7, 8, 9, 10 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.skipWhile(even);

    // Assert
    var expected = &[_]u8{ 7, 8, 9, 10 };
    try expectEqualIter(u8, expected, actual);
}

test ".skipWhile() stop at the end" {
    // Arrange
    const numbers = &[_]u8{ 2, 4, 6, 8, 10 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.skipWhile(even);

    // Assert
    const expected = &[_]u8{};
    try expectEqualIter(u8, expected, actual);
}

test ".skipWhile() stop immediately" {
    // Arrange
    const numbers = &[_]u8{ 1, 2, 3, 4, 5 };
    var iter = from.slice(u8, numbers);

    // Act
    var actual = iter.skipWhile(even);

    // Assert
    const expected = &[_]u8{ 1, 2, 3, 4, 5 };
    try expectEqualIter(u8, expected, actual);
}

test "double optional?" {
    var items = &[_]?i32{ 1, null, 3, 4, null };
    var iter = from.slice(?i32, items);
    var index: usize = 0;
    while (iter.next()) |item| {
        try std.testing.expectEqual(items[index], item);
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 5), index);
}

test ".intersperse(...)" {
    var input = &[_]u8{ 1, 2, 3, 4, 5 };
    var iter = from.slice(u8, input);
    var actual = iter.intersperse(9);
    var expected = &[_]u8{ 1, 9, 2, 9, 3, 9, 4, 9, 5 };
    try expectEqualIter(u8, expected, actual);
}

test ".max()" {
    var input = &[_]u8{ 1, 2, 3, 4, 5 };
    var iter = from.slice(u8, input);
    var actual = iter.max();
    var expected: ?u8 = 5;
    try std.testing.expectEqual(expected, actual);
}

test ".min()" {
    var input = &[_]u8{ 3, 4, 2, 1, 5 };
    var iter = from.slice(u8, input);
    var actual = iter.min();
    var expected: ?u8 = 1;
    try std.testing.expectEqual(expected, actual);
}

fn add(a: u8, b: u8) u8 {
    return a + b;
}

test ".scan(...)" {
    var input = &[_]u8{ 1, 2, 3, 4, 5 };
    var iter = from.slice(u8, input);
    var actual = iter.scan(u8, add, 0);
    var expected = &[_]u8{ 1, 3, 6, 10, 15 };
    try expectEqualIter(u8, expected, actual);
}

test ".aggregate(...)" {
    var input = &[_]u8{ 1, 2, 3, 4, 5 };
    var iter = from.slice(u8, input);
    var actual = iter.aggregate(u8, add, 0);
    var expected: u8 = 15;
    try std.testing.expectEqual(expected, actual);
}

test ".contains(...)" {
    var input = &[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    {
        var iter = from.slice(u8, input);
        var actual = iter.contains(5);
        try std.testing.expectEqual(true, actual);
    }
    {
        var iter = from.slice(u8, input);
        var actual = iter.contains(20);
        try std.testing.expectEqual(false, actual);
    }
}

test ".indexOf(...)" {
    var input = &[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    {
        var iter = from.slice(u8, input);
        var actual = iter.indexOf(1);
        try std.testing.expectEqual(@as(?usize, 0), actual);
    }
    {
        var iter = from.slice(u8, input);
        var actual = iter.indexOf(5);
        try std.testing.expectEqual(@as(?usize, 4), actual);
    }
    {
        var iter = from.slice(u8, input);
        var actual = iter.indexOf(10);
        try std.testing.expectEqual(@as(?usize, 9), actual);
    }
    {
        var iter = from.slice(u8, input);
        var actual = iter.indexOf(20);
        try std.testing.expectEqual(@as(?usize, null), actual);
    }
}

test ".sequenceEqual(...)" {
    var input = &[_]u8{ 1, 2, 3 };
    {
        var first_iter = from.slice(u8, input);
        var second_input = &[_]u8{ 1, 2, 3 };
        var second_iter = from.slice(u8, second_input);
        var actual = first_iter.sequenceEqual(&second_iter);
        try std.testing.expectEqual(true, actual);
    }
    {
        var first_iter = from.slice(u8, input);
        var second_input = &[_]u8{ 1, 2, 3, 4 };
        var second_iter = from.slice(u8, second_input);
        var actual = first_iter.sequenceEqual(&second_iter);
        try std.testing.expectEqual(false, actual);
    }
    {
        var first_iter = from.slice(u8, input);
        var second_input = &[_]u8{ 1, 2 };
        var second_iter = from.slice(u8, second_input);
        var actual = first_iter.sequenceEqual(&second_iter);
        try std.testing.expectEqual(false, actual);
    }
    {
        var first_iter = from.slice(u8, input);
        var second_input = &[_]u8{ 1, 2, 4 };
        var second_iter = from.slice(u8, second_input);
        var actual = first_iter.sequenceEqual(&second_iter);
        try std.testing.expectEqual(false, actual);
    }
}

test ".isSortedAscending()" {
    {
        var input = &[_]u8{ 1, 2, 3 };
        var iter = from.slice(u8, input);
        var actual = iter.isSortedAscending();
        try std.testing.expectEqual(true, actual);
    }
    {
        var input = &[_]u8{ 1, 3, 2 };
        var iter = from.slice(u8, input);
        var actual = iter.isSortedAscending();
        try std.testing.expectEqual(false, actual);
    }
}

test ".isSortedDescending()" {
    {
        var input = &[_]u8{ 3, 2, 1 };
        var iter = from.slice(u8, input);
        var actual = iter.isSortedDescending();
        try std.testing.expectEqual(true, actual);
    }
    {
        var input = &[_]u8{ 3, 1, 2 };
        var iter = from.slice(u8, input);
        var actual = iter.isSortedDescending();
        try std.testing.expectEqual(false, actual);
    }
}

test ".window(...)" {
    {
        var input = &[_]u8{ 1, 2, 3, 4, 5 };
        var iter = from.slice(u8, input);
        var actual = iter.window(3);
        var expecpted = &[_][3]u8{
            .{ 1, 2, 3 },
            .{ 2, 3, 4 },
            .{ 3, 4, 5 },
        };
        try expectEqualIter([3]u8, expecpted, actual);
    }
    {
        var input = &[_]u8{ 1, 2, 3, 4, 5 };
        var iter = from.slice(u8, input);
        var actual = iter.window(1);
        var expecpted = &[_][1]u8{
            .{1},
            .{2},
            .{3},
            .{4},
            .{5},
        };
        try expectEqualIter([1]u8, expecpted, actual);
    }
    {
        var input = &[_]u8{ 1, 2, 3, 4, 5 };
        var iter = from.slice(u8, input);
        var actual = iter.window(5);
        var expecpted = &[_][5]u8{
            .{ 1, 2, 3, 4, 5 },
        };
        try expectEqualIter([5]u8, expecpted, actual);
    }
    {
        var input = &[_]u8{ 1, 2, 3, 4, 5 };
        var iter = from.slice(u8, input);
        var actual = iter.window(6);
        var expecpted = &[_][6]u8{};
        try expectEqualIter([6]u8, expecpted, actual);
    }
}

test ".reverse() on slice iter" {
    var input = &[_]u8{ 1, 2, 3, 4, 5 };
    var iter = from.slice(u8, input);
    var actual = iter.reverse();
    try expectEqualIter(u8, &[_]u8{ 5, 4, 3, 2, 1 }, actual);
}

fn expectEqualIter(comptime T: type, expected: anytype, actual: anytype) !void {
    var arrayList = try actual.toArrayList(std.testing.allocator);
    defer arrayList.deinit();
    try std.testing.expectEqualSlices(T, expected, arrayList.items);
}
