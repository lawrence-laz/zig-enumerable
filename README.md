# Zig Enumerable ⚡

Functional vibes for data processing as sequences.

```zig
const std = @import("std");
const enumerable = @import("enumerable");

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
```

## 📦 Get started

```bash
zig fetch --save https://github.com/lawrence-laz/zig-enumerable/archive/master.tar.gz
```

```zig
// build.zig
const enumerable = b.dependency("enumerable", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("enumerable", enumerable.module("enumerable"));
```

