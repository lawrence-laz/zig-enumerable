const std = @import("std");
const from = @import("from.zig");
const WhereIterator = @import("where_iterator.zig").WhereIterator;
const SelectIterator = @import("select_iterator.zig").SelectIterator;
const SelectManyIterator = @import("select_many_iterator.zig").SelectManyIterator;
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

/// A common interface type for all iterators.
/// Holds all user facing functions.
pub fn Iterator(
    /// The type of items being iterated.
    comptime TItem: type,
    /// The concrete implementation of the current iterator.
    comptime TImpl: type,
) type {
    return struct {
        const Self = @This();

        impl: TImpl,

        /// Advances the iterator and returns the next item.
        ///
        /// Returns `null` when iteration is finished.
        /// Some iterators might never return `null`, thus making them infinite.
        pub fn next(self: *Self) ?TItem {
            return self.impl.next();
        }

        /// Returns the number of items in the iterator.
        pub fn count(self: *const Self) usize {
            var self_copy = self.*;
            var result: usize = 0;
            while (self_copy.next()) |_| {
                result += 1;
            }
            return result;
        }

        /// Returns the sum of all items in the iterators.
        ///
        /// Items are expected to support `+=` operator.
        pub fn sum(self: *const Self) TItem {
            var self_copy = self.*;
            var result: TItem = 0;
            while (self_copy.next()) |number| {
                result += number;
            }
            return result;
        }

        /// Returns whether the iterator contains at least one item satisfying the condition function.
        ///
        /// An empty iterator always returns `false`.
        pub fn any(
            self: *const Self,
            comptime function: fn (TItem) bool,
        ) bool {
            var self_copy = self.*;
            while (self_copy.next()) |item| {
                if (function(item)) {
                    return true;
                }
            }
            return false;
        }

        /// Returns whether all items in the iterator satisfy the condition function.
        ///
        /// An empty iterator always returns `true`.
        pub fn all(
            self: *const Self,
            comptime function: fn (TItem) bool,
        ) bool {
            var self_copy = self.*;
            while (self_copy.next()) |item| {
                if (!function(item)) {
                    return false;
                }
            }
            return true;
        }

        /// Returns the first item of the iterator or `null` if iterator is finished.
        pub fn first(self: *const Self) ?TItem {
            var self_copy = self.*;
            return self_copy.next() orelse null;
        }

        /// Returns the last item of the iterator or `null` if iterator is finished.
        pub fn last(self: *const Self) ?TItem {
            var self_copy = self.*;
            var last_item: ?TItem = null;
            while (self_copy.next()) |item| {
                last_item = item;
            }
            return last_item;
        }

        pub fn elementAt(
            self: *const Self,
            index: usize,
        ) ?TItem {
            var self_copy = self.*;
            var current_index: usize = 0;
            while (current_index < index and self_copy.next() != null) {
                current_index += 1;
            }
            return self_copy.next();
        }

        pub inline fn where(
            self: *const Self,
            comptime function: fn (TItem) bool,
        ) Iterator(TItem, WhereIterator(TItem, function, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
            } };
        }

        pub inline fn select(
            self: *const Self,
            comptime TDest: type,
            comptime function: fn (TItem) TDest,
        ) Iterator(TDest, SelectIterator(TItem, TDest, function, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
            } };
        }

        pub inline fn selectMany(
            self: *const Self,
            comptime TDest: type,
            comptime function: fn (TItem) []const TDest,
        ) Iterator(TDest, SelectManyIterator(TItem, TDest, function, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .slice_iter = null,
            } };
        }

        pub inline fn window(
            self: *const Self,
            comptime size: usize,
        ) Iterator([size]TItem, WindowIterator(TItem, size, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .maybe_window = null,
            } };
        }

        pub inline fn scan(
            self: *const Self,
            comptime TState: type,
            comptime function: fn (TState, TItem) TState,
            initial_state: TState,
        ) Iterator(TState, ScanIterator(TItem, TState, function, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .state = initial_state,
                .prev_iter = self_copy.impl,
            } };
        }

        pub inline fn aggregate(
            self: *const Self,
            comptime TDest: type,
            comptime function: fn (TDest, TItem) TDest,
            seed: TDest,
        ) TDest {
            var self_copy = self.*;
            var result: TDest = seed;
            while (self_copy.next()) |item| {
                result = function(result, item);
            }
            return result;
        }

        pub inline fn contains(
            self: *const Self,
            needle: TItem,
        ) bool {
            var self_copy = self.*;
            while (self_copy.next()) |item| {
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
            var self_copy = self.*;
            // var other_copy = other_iter.*;
            while (true) {
                var first_item = self_copy.next();
                var second_item = other_iter.next();

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
            var self_copy = self.*;
            var index: usize = 0;
            while (self_copy.next()) |item| {
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
        ) Iterator(TItem, ConcatIterator(TItem, TImpl, @TypeOf(other_iter))) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
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
        ) Iterator(struct { TItem, TOtherItem }, ZipIterator(TItem, TImpl, @TypeOf(other_iter), TOtherItem)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .other_iter = other_iter,
            } };
        }

        pub inline fn append(
            self: *const Self,
            item: TItem,
        ) Iterator(TItem, AppendIterator(TItem, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .appended_item = item,
            } };
        }

        pub inline fn intersperse(
            self: *const Self,
            delimiter: TItem,
        ) Iterator(TItem, IntersperseIterator(TItem, TImpl)) {
            return .{ .impl = .{
                .prev_iter = self.peekable().impl,
                .delimiter = delimiter,
                .next_is_delimiter = false,
            } };
        }

        pub inline fn peekable(self: *const Self) Iterator(TItem, PeekableIterator(TItem, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .peeked_item = null,
            } };
        }

        pub inline fn take(
            self: *const Self,
            item_count: usize,
        ) Iterator(TItem, TakeIterator(TItem, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .index = 0,
                .count = item_count,
            } };
        }

        pub inline fn takeEvery(
            self: *const Self,
            every_nth: usize,
        ) Iterator(TItem, TakeEveryIterator(TItem, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .every_nth = every_nth,
            } };
        }

        pub inline fn takeWhile(
            self: *const Self,
            comptime function: fn (TItem) bool,
        ) Iterator(TItem, TakeWhileIterator(TItem, function, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .completed = false,
            } };
        }

        pub inline fn toArrayList(
            self: *const Self,
            allocator: std.mem.Allocator,
        ) !std.ArrayList(TItem) {
            var self_copy = self.*;
            var array_list = std.ArrayList(TItem).init(allocator);
            while (self_copy.next()) |item| {
                try array_list.append(item);
            }
            return array_list;
        }

        pub inline fn skip(
            self: *const Self,
            item_count: usize,
        ) Iterator(TItem, SkipIterator(TItem, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .index = 0,
                .count = item_count,
            } };
        }

        pub inline fn skipWhile(
            self: *const Self,
            comptime function: fn (TItem) bool,
        ) Iterator(TItem, SkipWhileIterator(TItem, function, TImpl)) {
            var self_copy = self.*;
            return .{ .impl = .{
                .prev_iter = self_copy.impl,
                .skipping_is_done = false,
            } };
        }

        pub inline fn forEach(
            self: *const Self,
            function: *const fn (TItem) void,
        ) void {
            var self_copy = self.*;
            while (self_copy.next()) |item| {
                function(item);
            }
        }

        pub inline fn inspect(
            self: *const Self,
            function: *const fn (TItem) void,
        ) Iterator(TItem, TImpl) {
            var self_copy = self.*;
            while (self_copy.next()) |item| {
                function(item);
            }
            return self.*;
        }

        pub inline fn max(self: *const Self) ?TItem {
            var self_copy = self.*;
            var maybe_max_value: ?TItem = null;
            while (self_copy.next()) |item| {
                if (maybe_max_value == null or item > maybe_max_value.?) {
                    maybe_max_value = item;
                }
            }
            return maybe_max_value;
        }

        pub inline fn maxBy(
            self: *const Self,
            comptime TBy: type,
            comptime function: fn (TItem) TBy,
        ) ?TItem {
            var self_copy = self.*;
            var maybe_max_item: ?TItem = null;
            var maybe_max_value: ?TBy = null;
            while (self_copy.next()) |item| {
                var current_value = function(item);
                if (maybe_max_value == null or current_value > maybe_max_value.?) {
                    maybe_max_item = item;
                    maybe_max_value = current_value;
                }
            }
            return maybe_max_item;
        }

        pub inline fn minBy(
            self: *const Self,
            comptime TBy: type,
            comptime function: fn (TItem) TBy,
        ) ?TItem {
            var self_copy = self.*;
            var maybe_min_item: ?TItem = null;
            var maybe_min_value: ?TBy = null;
            while (self_copy.next()) |item| {
                var current_value = function(item);
                if (maybe_min_value == null or current_value < maybe_min_value.?) {
                    maybe_min_item = item;
                    maybe_min_value = current_value;
                }
            }
            return maybe_min_item;
        }

        pub inline fn min(self: *const Self) ?TItem {
            var self_copy = self.*;
            var maybe_min_value: ?TItem = null;
            while (self_copy.next()) |item| {
                if (maybe_min_value == null or item < maybe_min_value.?) {
                    maybe_min_value = item;
                }
            }
            return maybe_min_value;
        }

        pub inline fn isSortedAscending(self: *const Self) bool {
            var self_copy = self.*;
            var maybe_previous: ?TItem = null;
            while (self_copy.next()) |item| {
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
            var self_copy = self.*;
            var maybe_previous: ?TItem = null;
            while (self_copy.next()) |item| {
                if (maybe_previous) |previous| {
                    if (previous < item) {
                        return false;
                    }
                }
                maybe_previous = item;
            }
            return true;
        }

        pub inline fn isSortedAscendingBy(
            self: *const Self,
            comptime TBy: type,
            comptime function: fn (TItem) TBy,
        ) bool {
            var self_copy = self.*;
            var maybe_previous_value: ?TBy = null;
            while (self_copy.next()) |current_item| {
                var current_value = function(current_item);
                if (maybe_previous_value) |previous_value| {
                    if (previous_value > current_value) {
                        return false;
                    }
                }
                maybe_previous_value = current_value;
            }
            return true;
        }

        pub inline fn isSortedDescendingBy(
            self: *const Self,
            comptime TBy: type,
            comptime function: fn (TItem) TBy,
        ) bool {
            var self_copy = self.*;
            var maybe_previous_value: ?TBy = null;
            while (self_copy.next()) |current_item| {
                var current_value = function(current_item);
                if (maybe_previous_value) |previous_value| {
                    if (previous_value < current_value) {
                        return false;
                    }
                }
                maybe_previous_value = current_value;
            }
            return true;
        }

        pub inline fn reverse(self: *const Self) Iterator(TItem, SliceIterator(TItem)) {
            if (@hasDecl(TImpl, "reverse")) {
                var self_impl = self.impl;
                return .{ .impl = self_impl.reverse() };
            } else {
                @compileError("Iterator '" ++ @typeName(TImpl) ++ "' does not implement .reverse().\n");
            }
        }

        pub inline fn average(self: *const Self) TItem {
            var self_copy = self.*;
            var total_sum: TItem = 0;
            var total_count: usize = 0;
            while (self_copy.next()) |item| {
                total_sum += item;
                total_count += 1;
            }
            const item_type_info = @typeInfo(TItem);
            if (item_type_info == .Float) {
                return total_sum / @as(TItem, @floatFromInt(total_count));
            } else if (item_type_info == .Int) {
                if (item_type_info.Int.signedness == .unsigned) {
                    return total_sum / @as(TItem, @intCast(total_count));
                } else {
                    @compileError("Signed integer type '" ++ @typeName(TItem) ++ "' should be used either with .averageTrunc() or .averageFloor()");
                }
            } else {
                @compileError("Iterators with item type '" ++ @typeName(TItem) ++ "' do not support .average().");
            }
        }

        pub inline fn averageTrunc(self: *const Self) TItem {
            var self_copy = self.*;
            var total_sum: TItem = 0;
            var total_count: usize = 0;
            while (self_copy.next()) |item| {
                total_sum += item;
                total_count += 1;
            }
            const item_type_info = @typeInfo(TItem);
            if (item_type_info == .Int) {
                return @divTrunc(total_sum, @as(TItem, @intCast(total_count)));
            } else {
                @compileError("Iterators with item type '" ++ @typeName(TItem) ++ "' do not support .averageTrunc().");
            }
        }

        pub inline fn averageFloor(self: *const Self) TItem {
            var self_copy = self.*;
            var total_sum: TItem = 0;
            var total_count: usize = 0;
            while (self_copy.next()) |item| {
                total_sum += item;
                total_count += 1;
            }
            const item_type_info = @typeInfo(TItem);
            if (item_type_info == .Int) {
                return @divFloor(total_sum, @as(TItem, @intCast(total_count)));
            } else {
                @compileError("Iterators with item type '" ++ @typeName(TItem) ++ "' do not support .averageFloor().");
            }
        }

        pub inline fn averageBy(
            self: *const Self,
            comptime TBy: type,
            comptime function: fn (TItem) TBy,
        ) TBy {
            var self_copy = self.*;
            var total_sum: TBy = 0;
            var total_count: usize = 0;
            while (self_copy.next()) |item| {
                const item_value = function(item);
                total_sum += item_value;
                total_count += 1;
            }
            const item_type_info = @typeInfo(TBy);
            if (item_type_info == .Float) {
                return total_sum / @as(TBy, @floatFromInt(total_count));
            } else if (item_type_info == .Int) {
                if (item_type_info.Int.signedness == .unsigned) {
                    return total_sum / @as(TBy, @intCast(total_count));
                } else {
                    @compileError("Signed integer type '" ++ @typeName(TBy) ++ "' should be used either with .averageTrunc() or .averageFloor()");
                }
            } else {
                @compileError("Iterators with item type '" ++ @typeName(TBy) ++ "' do not support .average().");
            }
        }

        pub inline fn averageTruncBy(
            self: *const Self,
            comptime TBy: type,
            comptime function: fn (TItem) TBy,
        ) TBy {
            var self_copy = self.*;
            var total_sum: TBy = 0;
            var total_count: usize = 0;
            while (self_copy.next()) |item| {
                const item_value = function(item);
                total_sum += item_value;
                total_count += 1;
            }
            const item_type_info = @typeInfo(TBy);
            if (item_type_info == .Int) {
                return @divTrunc(total_sum, @as(TBy, @intCast(total_count)));
            } else {
                @compileError("Iterators with item type '" ++ @typeName(TBy) ++ "' do not support .averageTrunc().");
            }
        }

        pub inline fn averageFloorBy(
            self: *const Self,
            comptime TBy: type,
            comptime function: fn (TItem) TBy,
        ) TBy {
            var self_copy = self.*;
            var total_sum: TBy = 0;
            var total_count: usize = 0;
            while (self_copy.next()) |item| {
                const item_value = function(item);
                total_sum += item_value;
                total_count += 1;
            }
            const item_type_info = @typeInfo(TBy);
            if (item_type_info == .Int) {
                return @divFloor(total_sum, @as(TBy, @intCast(total_count)));
            } else {
                @compileError("Iterators with item type '" ++ @typeName(TBy) ++ "' do not support .averageFloor().");
            }
        }
    };
}

fn printItem(item: u8) void {
    std.debug.print("\n Item: {}", .{item});
}

test "forEach" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5 });
    iter.forEach(printItem);
}

test "inspect" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5 });
    _ = iter.inspect(printItem);
}

test "count" {
    var lines_iter = std.mem.tokenizeSequence(u8, "foo\nbar\nbaz\n", "\n");
    var iter = from.tokenIterator([]const u8, &lines_iter);
    var actual = iter.count();
    try std.testing.expectEqual(@as(usize, 3), actual);
}

fn even(number: u8) bool {
    return @rem(number, 2) == 0;
}

test "chained example" {
    const input = "Number 1 and 2, then goes 3 and last one 4 is excluded.";
    const result = from.slice(input).where(std.ascii.isDigit).take(3).intersperse('+');
    try expectEqualIter(u8, "1+2+3", result);
}

test "where" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
    var actual = iter.where(even);
    try expectEqualIter(u8, &.{ 2, 4, 6, 8, 10 }, actual);
}

fn negative(number: u8) i8 {
    return @as(i8, @intCast(number)) * -1;
}

test "select" {
    var iter = from.slice(&[_]u8{ 1, 2, 3 });
    var actual = iter.select(i8, negative);
    try expectEqualIter(i8, &.{ -1, -2, -3 }, actual);
}

const Foo = struct { numbers: []const u8 };
fn getNumbers(foo: Foo) []const u8 {
    return foo.numbers;
}
test "selectMany" {
    var iterator = from.slice(&[_]Foo{
        .{ .numbers = &.{} },
        .{ .numbers = &.{ 1, 2 } },
        .{ .numbers = &.{} },
        .{ .numbers = &.{3} },
        .{ .numbers = &.{} },
        .{ .numbers = &.{ 4, 5 } },
        .{ .numbers = &.{ 6, 7 } },
        .{ .numbers = &.{} },
    });
    var actual = iterator.selectMany(u8, getNumbers);
    try expectEqualIter(u8, &.{ 1, 2, 3, 4, 5, 6, 7 }, actual);
}

test "sum" {
    var iterator = from.slice(&[_]u8{ 1, 2, 3 });
    var actual = iterator.sum();
    try std.testing.expectEqual(@as(u8, 6), actual);
}

test "any" {
    var iterator = from.slice(&[_]u8{ 1, 2, 3 });
    const actual = iterator.any(even);
    try std.testing.expectEqual(true, actual);
}

test "all" {
    {
        var iterator = from.slice(&[_]u8{ 2, 4, 6 });
        const actual = iterator.all(even);
        try std.testing.expectEqual(true, actual);
    }
    {
        var iterator = from.slice(&[_]u8{ 2, 3, 6 });
        const actual = iterator.all(even);
        try std.testing.expectEqual(false, actual);
    }
    {
        var iterator = from.slice(&[_]u8{});
        const actual = iterator.all(even);
        try std.testing.expectEqual(true, actual);
    }
}

test "first" {
    {
        var iterator = from.slice(&[_]u8{});
        const actual = iterator.first();
        try std.testing.expectEqual(@as(?u8, null), actual);
    }
    {
        var iterator = from.slice(&[_]u8{ 1, 2, 3 });
        const actual = iterator.first();
        try std.testing.expectEqual(@as(?u8, 1), actual);
    }
}

test "last" {
    {
        var iterator = from.slice(&[_]u8{});
        const actual = iterator.last();
        try std.testing.expectEqual(@as(?u8, null), actual);
    }
    {
        var iterator = from.slice(&[_]u8{ 1, 2, 3 });
        const actual = iterator.last();
        try std.testing.expectEqual(@as(?u8, 3), actual);
    }
}

test "elementAt" {
    {
        var iterator = from.slice(&[_]u8{});
        const actual = iterator.elementAt(5);
        try std.testing.expectEqual(@as(?u8, null), actual);
    }
    {
        var iterator = from.slice(&[_]u8{ 1, 2, 3 });
        const actual = iterator.elementAt(2);
        try std.testing.expectEqual(@as(?u8, 3), actual);
    }
}

test "concat" {
    var first_iter = from.slice(&[_]u8{ 1, 2, 3 });
    var second_iter = from.slice(&[_]u8{ 4, 5, 6 });
    var actual = first_iter.concat(&second_iter);
    try expectEqualIter(u8, &.{ 1, 2, 3, 4, 5, 6 }, actual);
}

test "zip" {
    var first_iter = from.slice(&[_]u8{ 1, 2, 3 });
    var second_iter = from.slice(&[_]u8{ 4, 5, 6 });
    var actual = first_iter.zip(u8, &second_iter);
    try expectEqualIter(struct { u8, u8 }, &.{ .{ 1, 4 }, .{ 2, 5 }, .{ 3, 6 } }, actual);
}

test "append" {
    var iter = from.slice(&[_]u8{ 1, 2, 3 });
    var actual = iter.append(4);
    // Assert
    try expectEqualIter(u8, &.{ 1, 2, 3, 4 }, actual);
}

test "take" {
    {
        var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
        var actual = iter.take(3);
        try expectEqualIter(u8, &.{ 1, 2, 3 }, actual);
    }
    {
        var iter = from.slice(&[_]u8{ 1, 2 });
        var actual = iter.take(3);
        try expectEqualIter(u8, &.{ 1, 2 }, actual);
        try expectEqualIter(u8, &.{ 1, 2 }, actual);
    }
}

test "takeEvery" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
    var actual = iter.takeEvery(2);
    try expectEqualIter(u8, &.{ 2, 4, 6, 8, 10 }, actual);
}

test "takeWhile" {
    {
        var iter = from.slice(&[_]u8{ 2, 4, 6, 7, 8, 9, 10 });
        var actual = iter.takeWhile(even);
        try expectEqualIter(u8, &.{ 2, 4, 6 }, actual);
    }
    {
        var iter = from.slice(&[_]u8{ 2, 4, 6, 8, 10 });
        var actual = iter.takeWhile(even);
        try expectEqualIter(u8, &.{ 2, 4, 6, 8, 10 }, actual);
    }
    {
        var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5 });
        var actual = iter.takeWhile(even);
        try expectEqualIter(u8, &[_]u8{}, actual);
    }
}

test "skip" {
    {
        var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
        var actual = iter.skip(3);
        try expectEqualIter(u8, &.{ 4, 5, 6, 7, 8, 9, 10 }, actual);
    }
    {
        var iter = from.slice(&[_]u8{ 1, 2 });
        var actual = iter.skip(3);
        try std.testing.expectEqual(@as(?u8, null), actual.next());
    }
}

test "skipWhile" {
    {
        var iter = from.slice(&[_]u8{ 2, 4, 6, 7, 8, 9, 10 });
        var actual = iter.skipWhile(even);
        try expectEqualIter(u8, &.{ 7, 8, 9, 10 }, actual);
    }
    {
        var iter = from.slice(&[_]u8{ 2, 4, 6, 8, 10 });
        var actual = iter.skipWhile(even);
        try expectEqualIter(u8, &[_]u8{}, actual);
    }
    {
        var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5 });
        var actual = iter.skipWhile(even);
        try expectEqualIter(u8, &.{ 1, 2, 3, 4, 5 }, actual);
    }
}

test "optionals" {
    var iter = from.slice(&[_]?i32{ 1, null, 3, 4, null });
    try expectEqualIter(?i32, &[_]?i32{ 1, null, 3, 4, null }, iter);
}

test "intersperse" {
    var iter = from.slice("abcd");
    var actual = iter.intersperse('_');
    try expectEqualIter(u8, "a_b_c_d", actual);
}

test "max" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5 });
    var actual = iter.max();
    try std.testing.expectEqual(@as(?u8, 5), actual);
}

const Person = struct {
    name: []const u8,
    age: u8,
};

fn age(person: Person) u8 {
    return person.age;
}

test "maxBy" {
    var iter = from.slice(&[_]Person{
        .{ .name = "Marry", .age = 1 },     .{ .name = "Dave", .age = 2 },
        .{ .name = "Gerthrude", .age = 3 }, .{ .name = "Casper", .age = 4 },
        .{ .name = "John", .age = 5 },
    });
    var actual = iter.maxBy(u8, age);
    try std.testing.expectEqual(Person{ .name = "John", .age = 5 }, actual.?);
}

test "minBy" {
    var iter = from.slice(&[_]Person{
        .{ .name = "Gerthrude", .age = 3 }, .{ .name = "Casper", .age = 4 },
        .{ .name = "Marry", .age = 1 },     .{ .name = "Dave", .age = 2 },
        .{ .name = "John", .age = 5 },
    });
    var actual = iter.minBy(u8, age);
    try std.testing.expectEqual(Person{ .name = "Marry", .age = 1 }, actual.?);
}

test "min" {
    var iter = from.slice(&[_]u8{ 3, 4, 2, 1, 5 });
    var actual = iter.min();
    try std.testing.expectEqual(@as(u8, 1), actual.?);
}

fn add(a: u8, b: u8) u8 {
    return a + b;
}

test "scan" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5 });
    var actual = iter.scan(u8, add, 0);
    try expectEqualIter(u8, &[_]u8{ 1, 3, 6, 10, 15 }, actual);
}

test "aggregate" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5 });
    var actual = iter.aggregate(u8, add, 0);
    try std.testing.expectEqual(@as(u8, 15), actual);
}

test "contains" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
    {
        var actual = iter.contains(5);
        try std.testing.expectEqual(true, actual);
    }
    {
        var actual = iter.contains(20);
        try std.testing.expectEqual(false, actual);
    }
}

test "indexOf" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
    {
        var actual = iter.indexOf(1);
        try std.testing.expectEqual(@as(?usize, 0), actual);
    }
    {
        var actual = iter.indexOf(5);
        try std.testing.expectEqual(@as(?usize, 4), actual);
    }
    {
        var actual = iter.indexOf(10);
        try std.testing.expectEqual(@as(?usize, 9), actual);
    }
    {
        var actual = iter.indexOf(20);
        try std.testing.expectEqual(@as(?usize, null), actual);
    }
}

test "sequenceEqual" {
    {
        var first_iter = from.slice(&[_]u8{ 1, 2, 3 });
        var second_iter = from.slice(&[_]u8{ 1, 2, 3 });
        var actual = first_iter.sequenceEqual(&second_iter);
        try std.testing.expectEqual(true, actual);
    }
    {
        var first_iter = from.slice(&[_]u8{ 1, 2, 3 });
        var second_iter = from.slice(&[_]u8{ 1, 2, 3, 4 });
        var actual = first_iter.sequenceEqual(&second_iter);
        try std.testing.expectEqual(false, actual);
    }
    {
        var first_iter = from.slice(&[_]u8{ 1, 2, 3 });
        var second_iter = from.slice(&[_]u8{ 1, 2 });
        var actual = first_iter.sequenceEqual(&second_iter);
        try std.testing.expectEqual(false, actual);
    }
    {
        var first_iter = from.slice(&[_]u8{ 1, 2, 3 });
        var second_iter = from.slice(&[_]u8{ 1, 2, 4 });
        var actual = first_iter.sequenceEqual(&second_iter);
        try std.testing.expectEqual(false, actual);
    }
}

test "isSortedAscending" {
    {
        var iter = from.slice(&[_]u8{ 1, 2, 3 });
        var actual = iter.isSortedAscending();
        try std.testing.expectEqual(true, actual);
    }
    {
        var input = &[_]u8{ 1, 3, 2 };
        var iter = from.slice(input);
        var actual = iter.isSortedAscending();
        try std.testing.expectEqual(false, actual);
    }
}

test "isSortedDescending" {
    {
        var iter = from.slice(&[_]u8{ 3, 2, 1 });
        var actual = iter.isSortedDescending();
        try std.testing.expectEqual(true, actual);
    }
    {
        var iter = from.slice(&[_]u8{ 3, 1, 2 });
        var actual = iter.isSortedDescending();
        try std.testing.expectEqual(false, actual);
    }
}

test "isSortedAscendingBy" {
    {
        var iter = from.slice(&[_]Person{
            .{ .name = "Marry", .age = 1 },
            .{ .name = "Dave", .age = 2 },
            .{ .name = "Gerthrude", .age = 3 },
            .{ .name = "Casper", .age = 4 },
            .{ .name = "John", .age = 5 },
        });
        var actual = iter.isSortedAscendingBy(u8, age);
        try std.testing.expectEqual(true, actual);
    }
    {
        var iter = from.slice(&[_]Person{
            .{ .name = "Marry", .age = 1 },
            .{ .name = "Dave", .age = 2 },
            .{ .name = "Casper", .age = 4 },
            .{ .name = "John", .age = 5 },
            .{ .name = "Gerthrude", .age = 3 },
        });
        var actual = iter.isSortedAscendingBy(u8, age);
        try std.testing.expectEqual(false, actual);
    }
}

test "isSortedDescendingBy" {
    {
        var iter = from.slice(&[_]Person{
            .{ .name = "John", .age = 5 },
            .{ .name = "Casper", .age = 4 },
            .{ .name = "Gerthrude", .age = 3 },
            .{ .name = "Dave", .age = 2 },
            .{ .name = "Marry", .age = 1 },
        });
        var actual = iter.isSortedDescendingBy(u8, age);
        try std.testing.expectEqual(true, actual);
    }
    {
        var iter = from.slice(&[_]Person{
            .{ .name = "John", .age = 5 },
            .{ .name = "Casper", .age = 4 },
            .{ .name = "Dave", .age = 2 },
            .{ .name = "Marry", .age = 1 },
            .{ .name = "Gerthrude", .age = 3 },
        });
        var actual = iter.isSortedDescendingBy(u8, age);
        try std.testing.expectEqual(false, actual);
    }
}

test "window" {
    {
        var actual = from.slice(&[_]u8{ 1, 2, 3, 4, 5 }).window(3);
        var expecpted = &[_][3]u8{
            .{ 1, 2, 3 },
            .{ 2, 3, 4 },
            .{ 3, 4, 5 },
        };
        try expectEqualIter([3]u8, expecpted, actual);
    }
    {
        var actual = from.slice(&[_]u8{ 1, 2, 3, 4, 5 }).window(1);
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
        var actual = from.slice(&[_]u8{ 1, 2, 3, 4, 5 }).window(5);
        var expecpted = &[_][5]u8{
            .{ 1, 2, 3, 4, 5 },
        };
        try expectEqualIter([5]u8, expecpted, actual);
    }
    {
        var actual = from.slice(&[_]u8{ 1, 2, 3, 4, 5 }).window(6);
        var expected = &[_][6]u8{};
        try expectEqualIter([6]u8, expected, actual);
    }
}

test "reverse" {
    var iter = from.slice(&[_]u8{ 1, 2, 3, 4, 5 });
    const actual = iter.reverse();
    try expectEqualIter(u8, &.{ 5, 4, 3, 2, 1 }, actual);
}

test "average" {
    {
        var iter = from.range(f32, 1, 5);
        const actual = iter.average();
        try std.testing.expectEqual(@as(f32, 2.5), actual);
    }
    {
        var iter = from.range(u32, 1, 5);
        const actual = iter.average();
        try std.testing.expectEqual(@as(u32, 2), actual);
    }
}

test "averageFloor" {
    var iter = from.slice(&[_]i32{ -1, -2, -2 });
    const actual = iter.averageFloor();
    try std.testing.expectEqual(@as(i32, -2), actual);
}

test "averageTrunc" {
    var iter = from.slice(&[_]i32{ -1, -2, -2 });
    const actual = iter.averageTrunc();
    try std.testing.expectEqual(@as(i32, -1), actual);
}

const TempReading = struct {
    location: []const u8,
    degrees_celsius: f32,
    day: u32,
    elevation: i32,
};

fn temp(reading: TempReading) f32 {
    return reading.degrees_celsius;
}

fn day(reading: TempReading) u32 {
    return reading.day;
}

fn elevation(reading: TempReading) i32 {
    return reading.elevation;
}

test "averageBy" {
    var iter = from.slice(&[_]TempReading{
        .{ .location = "London", .degrees_celsius = 10, .day = 352, .elevation = 11 },
        .{ .location = "New York", .degrees_celsius = 4, .day = 350, .elevation = 10 },
        .{ .location = "Tokyo", .degrees_celsius = 9, .day = 357, .elevation = 40 },
        .{ .location = "Vilnius", .degrees_celsius = 1, .day = 361, .elevation = 112 },
    });
    {
        const actual = iter.averageBy(f32, temp);
        try std.testing.expectEqual(@as(f32, 6.0), actual);
    }
    {
        const actual = iter.averageBy(u32, day);
        try std.testing.expectEqual(@as(u32, 355), actual);
    }
}

test "averageFloorBy" {
    var iter = from.slice(&[_]TempReading{
        .{ .location = "Carribean Sea", .degrees_celsius = 28.5, .day = 352, .elevation = -1 },
        .{ .location = "Mediterranean Sea", .degrees_celsius = 14.1, .day = 357, .elevation = -2 },
        .{ .location = "Baltic Sea", .degrees_celsius = 3.2, .day = 361, .elevation = -2 },
    });
    const actual = iter.averageFloorBy(i32, elevation);
    try std.testing.expectEqual(@as(i32, -2), actual);
}

test "averageTruncBy" {
    var iter = from.slice(&[_]TempReading{
        .{ .location = "Carribean Sea", .degrees_celsius = 28.5, .day = 352, .elevation = -1 },
        .{ .location = "Mediterranean Sea", .degrees_celsius = 14.1, .day = 357, .elevation = -2 },
        .{ .location = "Baltic Sea", .degrees_celsius = 3.2, .day = 361, .elevation = -2 },
    });
    const actual = iter.averageTruncBy(i32, elevation);
    try std.testing.expectEqual(@as(i32, -1), actual);
}

fn expectEqualIter(comptime T: type, expected: anytype, actual: anytype) !void {
    var arrayList = try actual.toArrayList(std.testing.allocator);
    defer arrayList.deinit();
    try std.testing.expectEqualSlices(T, expected, arrayList.items);
}
