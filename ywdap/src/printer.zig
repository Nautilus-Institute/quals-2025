const std = @import("std");

pub const X_MAX = 250;
pub const Y_MAX = 250;
pub const Z_MAX = 250;
const SIZEUP_CONST = 1;
pub const SURFACE_TYPE = [X_MAX][Y_MAX][Z_MAX]u8;
const SPEED = 100;

const SummaryFunc = *const fn (*SURFACE_TYPE) void;
pub var final_printout: SummaryFunc = undefined;

var global_array = std.mem.zeroes(SURFACE_TYPE);

const Commands = enum {
    M1,
    G0,
    G1,
    G28,
    G90,
    G91,
    G92,
    M33,
    M104,
    M105,
    M109,
    M140,
    M190,
    M82,
    M83,
    M84,
    M106,
    M107,
};

const PositionMode = enum {
    absolute,
    relative,
};

const Fields = struct {
    x: ?i64,
    y: ?i64,
    z: ?i64,
    s: ?i64,
    e: ?i64,
    f: ?i64,

    fn parse_fields(it: *std.mem.SplitIterator(u8, .scalar)) !Fields {
        var ret: Fields = .{
            .x = null,
            .y = null,
            .z = null,
            .s = null,
            .e = null,
            .f = null,
        };
        while (it.*.next()) |arg| {
            if (arg.len == 0) {
                return ret;
            }
            switch (arg[0]) {
                'X' => {
                    ret.x = try parse_to_int(arg[1..]);
                },
                'Y' => {
                    ret.y = try parse_to_int(arg[1..]);
                },
                'Z' => {
                    ret.z = try parse_to_int(arg[1..]);
                },
                'S' => {
                    ret.s = try parse_to_int_absolute(arg[1..]);
                },
                'E' => {
                    ret.e = try parse_to_int_absolute(arg[1..]);
                },
                'F' => {
                    ret.f = try parse_to_int_absolute(arg[1..]);
                },
                else => {
                    return error.NotAnArgument;
                },
            }
        }
        return ret;
    }
};

pub const Printer = struct {
    x: i64,
    y: i64,
    z: i64,
    e: i64, // extruder amount
    f: usize, // move rate per minute (mm/min)
    bed_temp: usize,
    extruder_temp: usize,
    extruder_mode: PositionMode,
    positioning: PositionMode,
    array: *SURFACE_TYPE,

    const Self = @This();

    pub fn init() !Self {
        return .{
            .x = 0,
            .y = 0,
            .z = 0,
            .e = 0,
            .f = 1,
            .bed_temp = 0,
            .extruder_temp = 0,
            .extruder_mode = .absolute,
            .positioning = .absolute,
            .array = &global_array,
        };
    }

    fn extrude(self: *Self, fields: Fields) !void {
        // Extrude on the line from x,y,z to x2,y2,z2
        const new_x = switch (self.positioning) {
            .absolute => if (fields.x) |x| x else self.x,
            .relative => if (fields.x) |x| self.x + x else self.x,
        };
        const new_y = switch (self.positioning) {
            .absolute => if (fields.y) |y| y else self.y,
            .relative => if (fields.y) |y| self.y + y else self.y,
        };
        const new_z = switch (self.positioning) {
            .absolute => if (fields.z) |z| z else self.z,
            .relative => if (fields.z) |z| self.z + z else self.z,
        };
        const new_e = switch (self.extruder_mode) {
            .absolute => if (fields.e) |e| e else self.e,
            .relative => if (fields.e) |e| self.e + e else self.e,
        };

        const x_diff = (new_x - self.x);
        const y_diff = (new_y - self.y);
        const z_diff = (new_z - self.z);
        const e_diff = (new_e - self.e);

        const ds = @abs(std.math.pow(i64, x_diff, 2) +
            std.math.pow(i64, y_diff, 2) +
            std.math.pow(i64, z_diff, 2));

        const dist = std.math.sqrt(ds);

        if (e_diff == 0) {
            // just move
            self.x = new_x;
            self.y = new_y;
            self.z = new_z;
            return;
        }

        if (dist == 0) {
            const e_val = new_e - self.e;
            if (e_val > 0) {
                try self.write_xyz(@truncate(@as(u64, @bitCast(e_val))));
            }
            return;
        }

        const e_val = @abs(new_e - self.e) / dist;

        try print_status("Extruding {} to ({}, {}, {})\n", .{
            e_val,
            self.x,
            self.y,
            self.z,
        });
        var counter: usize = 0;

        const step: usize = (dist / self.f);
        while (counter < dist) {
            counter += self.f;
            self.x += (@as(i64, @intCast(step / dist)) * x_diff);
            self.y += (@as(i64, @intCast(step / dist)) * y_diff);
            self.z += (@as(i64, @intCast(step / dist)) * z_diff);
            try self.write_xyz(@truncate(e_val));
        }
        self.x = new_x;
        self.y = new_y;
        self.z = new_z;
        try self.write_xyz(@truncate(e_val));
    }

    fn write_xyz(self: *Self, v: u8) !void {
        @setRuntimeSafety(false);
        self.array[@bitCast(self.x)][@bitCast(self.y)][@bitCast(self.z)] =
            @truncate(try self.read_xyz() + @as(u64, @intCast(v)));
        return;
    }

    fn read_xyz(self: *Self) !u8 {
        @setRuntimeSafety(false);
        return self.array[@bitCast(self.x)][@bitCast(self.y)][@bitCast(self.z)];
    }

    pub fn deinit(self: Self) void {
        var array_x = self.array.*;
        final_printout(&array_x);
    }

    pub fn run_line(self: *Self, in_line: []u8) !void {
        var line: []u8 = undefined;
        if (std.mem.indexOf(u8, in_line, ";")) |idx| {
            line = in_line[0..idx];
        } else {
            line = in_line;
        }

        var it = std.mem.splitScalar(u8, line, ' ');

        if (it.next()) |command_str| {
            if (command_str.len == 0) {
                return;
            }
            if (std.meta.stringToEnum(Commands, command_str)) |command| {
                switch (command) {
                    .G0 => {
                        // Rapid move
                        const fields = try Fields.parse_fields(&it);
                        if (self.positioning == .absolute) {
                            if (fields.e) |e| {
                                self.e = e;
                            }
                            if (fields.x) |x| {
                                self.x = @intCast(x);
                            }
                            if (fields.y) |y| {
                                self.y = @intCast(y);
                            }
                            if (fields.z) |z| {
                                self.z = @intCast(z);
                            }
                        } else {
                            if (fields.e) |e| {
                                self.e += e;
                            }
                            if (fields.x) |x| {
                                self.x += @intCast(x);
                            }
                            if (fields.y) |y| {
                                self.y += @intCast(y);
                            }
                            if (fields.z) |z| {
                                self.z += @intCast(z);
                            }
                        }
                        if (fields.f) |f| {
                            self.f = @intCast(f);
                            try print_status("Feed rate set to {}\n", .{self.f});
                        }
                        try print_status("Rapidly setting position to ({}, {}, {}) {}\n", .{
                            self.x,
                            self.y,
                            self.z,
                            self.e,
                        });
                    },
                    .G1 => {
                        // Move
                        const fields = try Fields.parse_fields(&it);

                        if (fields.f) |f| {
                            self.f = @intCast(f);
                            try print_status("Feed rate set to {}\n", .{self.f});
                        }
                        try self.extrude(fields);

                        try print_status("Linearly setting position to ({}, {}, {}) {}\n", .{
                            self.x,
                            self.y,
                            self.z,
                            self.e,
                        });
                    },
                    .G92 => {
                        // G92: Set Position
                        const fields = try Fields.parse_fields(&it);
                        if (fields.e) |e| {
                            self.e = e;
                        }
                        if (fields.x) |x| {
                            self.x = @intCast(x);
                        }
                        if (fields.y) |y| {
                            self.y = @intCast(y);
                        }
                        if (fields.z) |z| {
                            self.z = @intCast(z);
                        }
                        try print_status("Setting position to ({}, {}, {}) {}\n", .{
                            self.x,
                            self.y,
                            self.z,
                            self.e,
                        });
                    },
                    .M1 => {
                        // M1: Sleep or Conditional stop
                        const fields = try Fields.parse_fields(&it);
                        if (fields.s) |s| {
                            try print_status("Sleeping for {} seconds\n", .{s});
                            std.time.sleep(@as(u64, @bitCast(s)) * std.time.ns_per_s);
                        } else {
                            try print_status("Sleeping forever\n", .{});
                            std.time.sleep(std.math.maxInt(u64));
                        }
                    },
                    .M140 => {
                        // M140: Set Bed Temperature (Fast)
                        const fields = try Fields.parse_fields(&it);
                        try print_status("Setting bed temperature to {}\n", .{fields.s.?});
                    },
                    .M105 => {
                        // M140: Get extruder temp
                        const v = try self.read_xyz();
                        try print_status("ok T:{} B:{} V:{}\n", .{
                            self.extruder_temp,
                            self.bed_temp,
                            v,
                        });
                    },
                    .M190 => {
                        // M190: Wait for bed temperature to reach target temp
                        const fields = try Fields.parse_fields(&it);
                        try print_status("Setting bed temperature to {} (waiting)\n", .{fields.s.?});
                    },
                    .M104 => {
                        // M104: Set Extruder Temperature
                        const fields = try Fields.parse_fields(&it);
                        try print_status("Setting extruder temperature to {}\n", .{fields.s.?});
                        self.extruder_temp = @intCast(fields.s.?);
                    },
                    .M109 => {
                        // M109: Set Extruder Temperature and Wait
                        const fields = try Fields.parse_fields(&it);
                        try print_status("Setting extruder temperature to {} (waiting)\n", .{fields.s.?});
                        self.extruder_temp = @intCast(fields.s.?);
                    },
                    .M82 => {
                        // M82: Set extruder to absolute mode
                        try print_status("Setting extruder mode to absolute\n", .{});
                        self.extruder_mode = .absolute;
                    },
                    .M83 => {
                        // M83: Set extruder to relative mode
                        try print_status("Setting extruder mode to relative\n", .{});
                        self.extruder_mode = .relative;
                    },
                    .G28 => {
                        // G28: Move to Origin (Home)
                        self.e = 0;
                        self.x = 0;
                        self.y = 0;
                        self.z = 0;
                        try print_status("Setting position to ({}, {}, {}) {}\n", .{
                            self.x,
                            self.y,
                            self.z,
                            self.e,
                        });
                    },
                    .M106 => {
                        // M106: Fan On
                        try print_status("Fan on\n", .{});
                    },
                    .M107 => {
                        // M107: Fan Off
                        try print_status("Fan off\n", .{});
                    },
                    .G90 => {
                        // G90: Set to Absolute Positioning
                        try print_status("Absolute positioning\n", .{});
                        self.positioning = .absolute;
                    },
                    .G91 => {
                        // G91: Set to relative Positioning
                        try print_status("Relative positioning\n", .{});
                        self.positioning = .relative;
                    },
                    .M84 => {
                        // M84: Stop idle hold
                        try print_status("Stop idle hold\n", .{});
                        return error.Done;
                    },
                    .M33 => {
                        try print_status("/flag\n", .{});
                    },
                }
            } else {
                return error.NotImplemented;
            }
        } else {
            return error.NoCommand;
        }
    }
};

fn print_status(comptime fmt: []const u8, args: anytype) !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    _ = try stdout.write(" > ");
    try stdout.print(fmt, args);
    try bw.flush();
}

fn parse_to_int_absolute(arg: []const u8) !i64 {
    if (std.mem.indexOf(u8, arg, ".")) |_| {
        // float
        const float = try std.fmt.parseFloat(f64, arg);
        return @intFromFloat(float);
    } else {
        // int
        return try std.fmt.parseInt(i64, arg, 10) * SIZEUP_CONST;
    }
}

fn parse_to_int(arg: []const u8) !i64 {
    if (std.mem.indexOf(u8, arg, ".")) |_| {
        // float
        const float = try std.fmt.parseFloat(f64, arg);
        const normalized = float * SIZEUP_CONST;
        return @intFromFloat(normalized);
    } else {
        // int
        return try std.fmt.parseInt(i64, arg, 10) * SIZEUP_CONST;
    }
}
