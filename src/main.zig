const std = @import("std");
const enumerable = @import("enumerable.zig");

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("iterator.zig");
}
