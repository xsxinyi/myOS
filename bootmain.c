#include "defs.h"
#include "x86.h"
#include "elf.h"

/* *********************************************************************
 * This a dirt simple boot loader, whose sole job is to boot
 * an ELF kernel image from the first IDE hard disk.
 *
 * DISK LAYOUT
 *  * This program(bootasm.S and bootmain.c) is the bootloader.
 *    It should be stored in the first sector of the disk.
 *
 *  * The 2nd sector onward holds the kernel image.
 *
 *  * The kernel image must be in ELF format.
 *
 * BOOT UP STEPS
 *  * when the CPU boots it loads the BIOS into memory and executes it
 *
 *  * the BIOS intializes devices, sets of the interrupt routines, and
 *    reads the first sector of the boot device(e.g., hard-drive)
 *    into memory and jumps to it.
 *
 *  * Assuming this boot loader is stored in the first sector of the
 *    hard-drive, this code takes over...
 *
 *  * control starts in bootasm.S -- which sets up protected mode,
 *    and a stack so C code then run, then calls bootmain()
 *
 *  * bootmain() in this file takes over, reads in the kernel and jumps to it.
 * */

#define SECTSIZE        512
#define ELFHDR          ((struct elfhdr *)0x10000)      // scratch space

/* waitdisk - wait for disk ready */
// 第7位为1表示硬盘忙，第6位为1表示硬盘控制器已准备好，正在等待指令。
static void
waitdisk(void) {
    while ((inb(0x1F7) & 0xC0) != 0x40)
        /* do nothing */;
}

/* readsect - read a single sector at @secno into @dst */
static void
readsect(void *dst, uint32_t secno) {
    // 第1步：检查硬盘控制器状态, 读0x1f7端口
    // 第7位为1表示硬盘忙，第6位为1表示硬盘控制器已准备好，正在等待指令。
    // wait for disk to be ready
    waitdisk();
    
    // 第2步：设置要读取的扇区数
    outb(0x1F2, 1);                         // count = 1

    // 第3步：将LBA地址存入0x1f3~0x1f6

    // 下面四条指令联合制定了扇区号
    // 在这4个字节线联合构成的32位参数中
    //   29-31位强制设为1, 表示LBA模式，
    //   28位(=0)表示访问"Disk 0"
    //   0-27位是28位的偏移量, See LBAHelper.txt
    outb(0x1F3, secno & 0xFF);
    outb(0x1F4, (secno >> 8) & 0xFF);
    outb(0x1F5, (secno >> 16) & 0xFF);
    outb(0x1F6, ((secno >> 24) & 0xF) | 0xE0);
    
    // 第4步：向0x1f7端口写入读命令0x20
    outb(0x1F7, 0x20);                      // cmd 0x20 - read sectors

    // wait for disk to be ready
    waitdisk();

    // read a sector
    // l代表双字，占4个字节，所以Bytes要除以4表示读的次数。
    insl(0x1F0, dst, SECTSIZE / 4);
}

/* *
 * readseg - read @count bytes at @offset from kernel into virtual address @va,
 * might copy more than asked.
 * */
static void
readseg(uintptr_t va, uint32_t count, uint32_t offset) {
    uintptr_t end_va = va + count;

    // round down to sector boundary
    va -= offset % SECTSIZE;

    // translate from bytes to sectors; kernel starts at sector 1
    uint32_t secno = (offset / SECTSIZE) + 1;

    // If this is too slow, we could read lots of sectors at a time.
    // We'd write more to memory than asked, but it doesn't matter --
    // we load in increasing order.
    for (; va < end_va; va += SECTSIZE, secno ++) {
        readsect((void *)va, secno);
    }
}

/* bootmain - the entry of bootloader */
// 首先，Boot把第一个即0号扇区即bootloader读入0x7c00
// 然后，bootmain把1号扇区，即ELF的Header读入0x10000，从Header中知道，ELFHDR->e_entry = 0x100000, 即程序入口地址为 0x100000
// 根据ELF的Header，ELF有3个Program Header table，9个Section Header table. 根据Program header table的偏置e_phoff，找到这三个Program Header.
// 对于第一个Program Header，内存虚拟地址为0x100000，段在文件中的偏移为0x1000，因为文件起始为1号扇区，所以段从9号扇区开始。
// 	从中读取ph->p_memsz = 190个字节到 0x100000 内存中。
// 对于第一个Program Header，内存虚拟地址为0x101000，段在文件中的偏移为0x2000，因为文件起始为1号扇区，所以段从16号扇区开始。
// 	从中读取ph->p_memsz = 12个字节到 0x101000 内存中。
// 第三个段为空段。跳过。
// 最后，跳到 ELFHDR->e_entry = 0x100000 去执行kernel。
void
bootmain(void) {
    // read the 1st page off disk
    // SECTSIZE * 8 = 4KB = 0x1000
    // ELFHDR = 0x10000
    readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);

    // is this a valid ELF?
    if (ELFHDR->e_magic != ELF_MAGIC) {
        goto bad;
    }

    struct proghdr *ph, *eph;

    // load each program segment (ignores ph flags)
    // ELFHDR->e_phoff的偏移是0x1c，LEA即去0x1c处取值，值是0x34
    // ELFHDR->e_phnum的偏移是0x2c，LEA即去0x2c处取值，值是3
    // ELFHDR->e_phoff = 0x34 = 52
    // LEA : 加载有效地址（load effective address）指令就是lea,他的指令形式就是从内存读取数据到寄存器，但是实际上他没有引用内存，
    // 而是将有效地址写入到目的的操作数，就像是C语言地址操作符&一样的功能，可以获取数据的地址。在实际使用中他有两种使用方式。
    ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);

    // sizeof(struct proghdr) = 4*8 = 32
    // ph + ELFHDR->e_phnum = ph + ELFHDR->e_phnum * 32 
    //     = ph + ELFHDR->e_phnum << 5 = 0x10034 + 3 << 5 = 0x10034 + 0x60 = 0x10094
    eph = ph + ELFHDR->e_phnum;
    
    for (; ph < eph; ph ++) {
        // 1st, ph = 0x10034
        // [p_va] = [ph + 8] = 0x100000.
        // [ph->p_offset] = [ph + 4] = 0x1000
        // 0x20-0xc = 0x14, [ph->p_memsz] = [ph + 20 (0x14)] = 190

        // 2nd, ph = 0x10054
        // [p_va] = 0x101000
        // [ph->p_offset] = 0x2000
        // [ph->p_memsz] = 0xc = 12

        // 3rd, ph = 0x10074
        // [p_va] = 0
        // [ph->p_offset] = 0
        // [ph->p_memsz] = 0
        readseg(ph->p_va & 0xFFFFFF, ph->p_memsz, ph->p_offset);
    }

    // call the entry point from the ELF header
    // note: does not return
    // ELFHDR->e_entry = [0x10018] = 0x100000
    ((void (*)(void))(ELFHDR->e_entry & 0xFFFFFF))();

bad:
    outw(0x8A00, 0x8A00);
    outw(0x8A00, 0x8E00);

    /* do nothing */
    while (1);
}

