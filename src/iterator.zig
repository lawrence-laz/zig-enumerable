const std = @import("std");
const from = @import("from.zig");
const WhereIterator = @import("where_iterator.zig").WhereIterator;
const SelectIterator = @import("select_iterator.zig").SelectIterator;
const ConcatIterator = @import("concat_iterator.zig").ConcatIterator;

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

        pub fn firstOrDefault(self: *const Self) ?TItem {
            const self_x = @constCast(self);
            return self_x.next() orelse null;
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
    };
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
