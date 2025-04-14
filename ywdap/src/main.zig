const std = @import("std");
const printer = @import("printer.zig");

const sigreturn = 139;

export fn __test_func_please_ignore(arg1: usize) void {
    _ = asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (sigreturn),
          [arg1] "{rdi}" (arg1),
        : "rcx", "r11"
    );
}

pub fn print_final(array: *printer.SURFACE_TYPE) void {
    // stdout
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    stdout.print(" > x y z v\n", .{}) catch unreachable;
    for (0..array.len) |x| {
        for (0..array[x].len) |y| {
            for (0..array[x][y].len) |z| {
                const v = array[x][y][z];
                if (v != 0) {
                    stdout.print("{} {} {} {}\n", .{
                        x, y, z, v,
                    }) catch unreachable;
                }
            }
        }
    }
    bw.flush() catch unreachable;
}

pub fn main() !void {
    // stdout
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // stdin
    const stdin_file = std.io.getStdIn().reader();
    var br = std.io.bufferedReader(stdin_file);
    const stdin = br.reader();

    printer.final_printout = print_final;
    var zig3dprinter = try printer.Printer.init();
    defer zig3dprinter.deinit();

    try stdout.print(" > Enter G-code:\n", .{});
    try bw.flush();

    var buf: [1024]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        zig3dprinter.run_line(line) catch |err| switch (err) {
            error.Done => break,
            else => {
                return err;
            },
        };
    }
}
