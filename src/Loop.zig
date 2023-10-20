const std = @import("std");
const c = @import("c.zig");
const errors = @import("errors.zig");
const Allocator = std.mem.Allocator;

pub const Loop = struct {
    loop: *c.uv_loop_t,

    pub fn init(alloc: Allocator) !Loop {
        const loop = try alloc.create(c.uv_loop_t);
        try errors.convertErr(c.uv_loop_init(loop));

        return Loop{ .loop = loop };
    }

    pub fn deinit(self: Loop, alloc: Allocator) void {
        // todo: better error handling
        errors.convertErr(c.uv_loop_close(self.loop)) catch unreachable;
        alloc.destroy(self.loop);
    }

    pub fn run(self: Loop) !void {
        try errors.convertErr(c.uv_run(self.loop, c.UV_RUN_DEFAULT));
    }
};
