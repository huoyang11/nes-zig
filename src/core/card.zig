const std = @import("std");

const prg_rom_page_size: u16 = 0x4000; //16k
const chr_rom_page_size: u16 = 0x2000; //8k
const trainer_size: u16 = 512;

const signature: [4]u8 = .{ 0x4e, 0x45, 0x53, 0x1a }; //NES 0x1a

const point_range = struct {
    start: u32 = 0,
    end: u32 = 0,

    pub fn init(self: *point_range, start: u32, size: u32) void {
        self.start = start;
        self.end = start + size;
    }
};

const card_header = extern struct {
    signature: [4]u8 = .{0} ** 4,
    prg_rom_size: u8 = 0,
    chr_rom_size: u8 = 0,
    flag6: u8 = 0,
    flag7: u8 = 0,
    prg_ram_size: u8 = 0,
    tv_system: u8 = 0,
    reserve: [6]u8 = .{0} ** 6,
};

pub const card = struct {
    header: card_header = .{},

    mirror_type: bool = false, //false 水平 true 垂直
    has_wram: bool = false, //true 表示有电池供电的 WRAM（保存进度）
    has_trainer: bool = false, //true 表示存在 Trainer（在 PRG-ROM 之前的 512字节）
    four_screens_mirror: bool = false, //true 表示四屏镜像（忽略 bit0）
    isnes2: bool = false,
    has_playchoice_10: bool = false,
    has_vs_unisystem: bool = false,
    mapperid: u16 = 0,
    trainer_range: point_range = .{},
    prg_rom_range: point_range = .{},
    chr_rom_range: point_range = .{},

    content: []u8,
    card_path: []const u8,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !card {
        const owned_path = try allocator.dupe(u8, path);
        errdefer allocator.free(owned_path);

        const content = try std.Io.Dir.cwd().readFileAlloc(
            io,
            path,
            allocator,
            .limited(16 * 1024 * 1024), // 最大允许读取 16 MiB
        );
        errdefer allocator.free(content);

        var ret: card = .{
            .card_path = owned_path,
            .content = content,
            .allocator = allocator,
        };

        if (ret.content.len < @sizeOf(card_header))
            return error.InvalidHeader;

        @memcpy(std.mem.asBytes(&ret.header), ret.content[0..@sizeOf(card_header)]);
        //校验模数
        if (!std.mem.eql(u8, &ret.header.signature, &signature))
            return error.InvalidHeader;

        const flag6 = ret.header.flag6;
        ret.mirror_type = (flag6 & (1)) == 1; //bit0
        ret.has_wram = (flag6 & (1 << 1)) == 1; //bit1
        ret.has_trainer = (flag6 & (1 << 2)) == 1;
        ret.four_screens_mirror = (flag6 & (1 << 3)) == 1;

        const flag7 = ret.header.flag7;
        ret.isnes2 = (flag7 & (3)) != 0;
        ret.has_playchoice_10 = (flag7 & (1 << 2)) == 1;
        ret.has_vs_unisystem = (flag7 & (1 << 3)) == 1;

        ret.mapperid = ((flag7 & (0x0f)) << 4) | (flag6 & (0x0f));

        var prg_rom_offset: u16 = @sizeOf(card_header);
        if (ret.has_trainer) {
            prg_rom_offset += trainer_size;
            ret.trainer_range.init(@sizeOf(card_header), trainer_size);
        }

        const prg_rom_size = ret.header.prg_rom_size * prg_rom_page_size;
        const chr_rom_size = ret.header.chr_rom_size * chr_rom_page_size;

        ret.prg_rom_range.init(prg_rom_offset, prg_rom_size);
        ret.chr_rom_range.init(prg_rom_offset + prg_rom_size, chr_rom_size);

        return ret;
    }

    pub fn destroy(self: *card) void {
        self.allocator.free(self.content);
        self.allocator.free(self.card_path);
    }
};
