# Zig Enumerable ⚡

Functional vibes for data processing as sequences.

```zig
const std = @import("std");
const enumerable = @import("path/to/enumerable.zig");

test "example" {
    try expectEqualIter(
        "(1,2,3)",
        enumerable.from(std.mem.tokenizeAny(u8, "foo=1;bar=2;baz=3", "=;").buffer)
            .where(std.ascii.isDigit)
            .intersperse(',')
            .prepend('(')
            .append(')'),
    );
}

