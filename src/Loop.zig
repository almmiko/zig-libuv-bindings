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
        // c.uv_loop_close can return an error, but deinit shouldn't throw any errors
        errors.convertErr(c.uv_loop_close(self.loop)) catch undefined;
        alloc.destroy(self.loop);
    }

    pub fn run(self: Loop, mode: LoopRunMode) !void {
        try errors.convertErr(c.uv_run(self.loop, @intFromEnum(mode)));
    }

    pub fn stop(self: Loop) void {
        c.uv_stop(self.loop);
    }

    pub fn alive(self: Loop) !bool {
        const isAlive = c.uv_loop_alive(self.loop);
        try errors.convertErr(isAlive);

        return isAlive > 0;
    }

    pub fn backendFd(self: Loop) !c_int {
        const fd = c.uv_backend_fd(self.loop);
        try errors.convertErr(fd);

        return fd;
    }
};

// we want to have an original value from c.uv_run_mode,
// the tag type can help with it
pub const LoopRunMode = enum(c.uv_run_mode) {
    default = c.UV_RUN_DEFAULT,
    once = c.UV_RUN_ONCE,
    nowait = c.UV_RUN_NOWAIT,
};
