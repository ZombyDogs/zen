const std = @import("std");
const cstr = std.cstr;
const io = std.io;
const mem = std.mem;
const zen = std.os.zen;
const Message = zen.Message;
const Server = zen.Server;
const warn = std.debug.warn;

const multiboot = @import("../../kernel/multiboot.zig");
var infoPtr = @intToPtr(&usize, 0x1000);
var info: &const multiboot.MultibootInfo = undefined;

////
// Entry point.
//
pub fn main() void {
    while (!(zen.portReady(0) and zen.portReady(1))) {}

    info = @intToPtr(&const multiboot.MultibootInfo, *infoPtr);

    var stdin_file = io.getStdIn() catch unreachable;
    var stdin = &io.FileInStream.init(&stdin_file).stream;
    var buffer: [1024]u8 = undefined;

    while (true) {
        warn(">>> ");
        const len = readLine(stdin, buffer[0..]);
        execute(buffer[0..len]);
    }
}

fn zenOfZig(n: usize) void {
    var i: usize = 0;
    while (i < n) : (i += 1) {}
}

////
// Execute a command.
//
// Arguments:
//     command: Command string.
//
fn execute(command: []u8) void {
    if (command.len == 0) {
        return;
    } else if (mem.eql(u8, command, "clear")) {
        clear();
    } else if (mem.eql(u8, command, "ls")) {
        ls();
    } else if (mem.eql(u8, command, "version")) {
        version();
    } else {
        const run = findProgram(command);
        if (!run) {
            help();
        }
    }
}

////
// Read a line from a stream into a buffer.
//
// Arguments:
//     stream: The stream to read from.
//     buffer: The buffer to write into.
//
// Returns:
//     The length of the line (excluding newline character).
//
pub fn readLine(stream: var, buffer: []u8) usize {
    // TODO: change the type of stream when #764 is fixed.

    var i: usize = 0;
    var char: u8 = 0;

    while (char != '\n') {
        char = stream.readByte() catch unreachable;

        if (char == 8) {
            // Backspace deletes the last character (if there's one).
            if (i > 0) {
                warn("{c}", char);
                i -= 1;
            }
        } else {
            // Save printable characters in the buffer.
            warn("{c}", char);
            buffer[i] = char;
            i += 1;
        }
    }

    return i - 1;  // Exclude \n.
}


//////////////////////////
////  Shell commands  ////
//////////////////////////

fn clear() void {
    zen.send(Message.to(Server.Terminal, 0));
}

fn help() void {
    warn("{}\n\n",
         \\List of supported commands:
         \\    clear      Clear screen
         \\    help       Show help message
         \\    ls         Show list of external programs
         \\    version    Show Zen version
    );
}

fn ls() void {
    const bootMods = info.bootModules();
    const mods = @intToPtr(&multiboot.MultibootModule, info.mods_addr)[0..info.mods_count];

    for (mods) |mod| {
        const cmdline = cstr.toSlice(@intToPtr(&u8, mod.cmdline));
        if (multiboot.MultibootInfo.shouldBoot(bootMods, cmdline)) continue;

        var it = mem.split(cmdline, "/");
        _ = ??it.next();
        const name = ??it.next();

        warn("{}\n", name);
    }
}

fn findProgram(name: []const u8) bool {
    const bootMods = info.bootModules();
    const mods = @intToPtr(&multiboot.MultibootModule, info.mods_addr)[0..info.mods_count];

    for (mods) |mod| {
        const cmdline = cstr.toSlice(@intToPtr(&u8, mod.cmdline));
        if (multiboot.MultibootInfo.shouldBoot(bootMods, cmdline)) continue;

        var it = mem.split(cmdline, "/");
        _ = ??it.next();
        const program_name = ??it.next();

        if (mem.eql(u8, program_name, name)) {
            const tid = zen.createProcess(mod.mod_start);
            zen.wait(tid);
            return true;
        }
    }
    return false;
}

fn version() void {
    warn("Zen v0.0.1\n\n");
}
