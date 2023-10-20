const builtin = @import("builtin");

pub usingnamespace @cImport({
    @cInclude("uv.h");
});
