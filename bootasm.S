#include <asm.h>

# Start the CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.set PROT_MODE_CSEG,        0x8                     # kernel code segment selector
.set PROT_MODE_DSEG,        0x10                    # kernel data segment selector
.set CR0_PE_ON,             0x1                     # protected mode enable flag
.set SMAP,                  0x534d4150              # ASCII : "SMAP"

# start address should be 0:7c00, in real mode, the beginning address of the running bootloader
.globl start
start:
.code16                                             # Assemble for 16-bit mode
    cli                                             # Disable interrupts
    # 地址指针时增加还是减少取决于方向标志DF。在系统初始化后或者执行指令CLD指令后，DF(direct flag)=0,此 时地址指针增1或2；在执行指令STD后，DF=1，此时地址指针减1或2。
    cld                                             # String operations increment

    # Set up the important data segment registers (DS, ES, SS).
    # 按位异或	^	xorb、xorw、xorl
    xorw %ax, %ax                                   # Segment number zero
    movw %ax, %ds                                   # -> Data Segment
    movw %ax, %es                                   # -> Extra Segment
    movw %ax, %ss                                   # -> Stack Segment

    # Enable A20:
    #  For backwards compatibility with the earliest PCs, physical
    #  address line 20 is tied low, so that addresses higher than
    #  1MB wrap around to zero by default. This code undoes this.

seta20.1:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    # test: 测试（两操作数作与运算,仅修改标志位，不回送结果）
    testb $0x2, %al                                 # 如果 %al 第低2位为1，则ZF = 0
    jnz seta20.1                                    # 如果 %al 第低2位为0，则ZF = 1, 则不跳转

    # 把0xd1这条数据写入到0x64端口中。当向0x64端口写入数据时，则代表向键盘控制器804x发送指令。这个指令将会被送给0x60端口。
    # 0xd1指令代表下一次写入0x60端口的数据将被写入给804x控制器的输出端口。可以理解为下一个写入0x60端口的数据是一个控制指令。
    movb $0xd1, %al                                 # 0xd1 -> port 0x64
    outb %al, $0x64                                 # 0xd1 means: write data to 8042's P2 port

seta20.2:
    # 等待上面的 0xd1 指令被读取到
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al
    jnz seta20.2

    movb $0xdf, %al                                 # 0xdf -> port 0x60
    outb %al, $0x60                                 # 0xdf = 11011111, means set P2's A20 bit(the 1 bit) to 1

probe_memory:
    movl $0, 0x8000
    xorl %ebx, %ebx
    movw $0x8004, %di
start_probe:
    movl $0xE820, %eax
    movl $20, %ecx
    movl $SMAP, %edx
    int $0x15
    # JC   ;进位则跳转
    # JNC  ;不进位则跳转
    jnc cont
    movw $12345, 0x8000
    jmp finish_probe
cont:
    addw $20, %di
    # AT&T语法和Intel语法的区别,incl/decl xxx等价于“inc/dec 32位的寄存器或内存单元”.
    # e.g. [0x8000] = 0 at the start. After incl cmd, [0x8000] = 1.
    incl 0x8000
    cmpl $0, %ebx
    jnz start_probe
finish_probe:

    # GDT Global Descriptor Table
    # Switch from real to protected mode, using a bootstrap GDT
    # and segment translation that makes virtual addresses
    # identical to physical addresses, so that the
    # effective memory map does not change during the switch.
    # 单独为我们准备了一个寄存器叫做 GDTR 用来保存我们 GDT 在内存中的位置和我们 GDT 的长度。#GDTR 寄存器一共 48 位，其中高 32 位用来存储我们的 GDT 在内存中的位置，
    # 其余的低 16 位用来存我们的 GDT 有多少个段描述符。 #16 位最大可以表示 65536 个数，这里我们把单位换成字节，而一个段描述符是 8 字节，所以 GDT 最多可以有 8192 个段描述符。
    # #CPU 不仅用了一个单独的寄存器 GDTR 来存储我们的 GDT，而且还专门提供了一个指令用来让我们把 GDT 的地址和长度传给 GDTR 寄存器：lgdt gdtdesc
    lgdt gdtdesc

    # 打开保护模式标志位，相当于按下了保护模式的开关。cr0寄存器的第0位就是这个开关
    movl %cr0, %eax
    orl $CR0_PE_ON, %eax
    movl %eax, %cr0

    # Jump to next instruction, but in 32-bit code segment.
    # Switches processor into 32-bit mode.

    # 把指令码中的目标地址addr16装入程序计数器PC
    # PROT_MODE_CSEG选择子选择了GDT中的第1个段描述符
    # 通过长跳转指令进入保护模式。80386在执行长跳转指令时，会重新加载$PROT_MODE_CSEG的值（即0x8）到CS中，同时把$protcseg的值赋给EIP，
    #     这样80386就会把CS的值作为全局描述符表的索引来找到对应的代码段描述符，设定当前的EIP为0x7c32(即protcseg标号所在的段内偏移)， 
    #     根据2.2.3节描述的分段机制中虚拟地址到线性地址转换转换的基本过程，可以知道线性地址（即物理地址）为：
    #     gdt[CS].base_addr+EIP=0x0+0x7c32=0x7c32 ljmp $PROT_MODE_CSEG, $protcseg
    ljmp $PROT_MODE_CSEG, $protcseg

.code32                                             # Assemble for 32-bit mode
protcseg:
    # Set up the protected-mode data segment registers
    movw $PROT_MODE_DSEG, %ax                       # Our data segment selector
    movw %ax, %ds                                   # -> DS: Data Segment
    movw %ax, %es                                   # -> ES: Extra Segment
    movw %ax, %fs                                   # -> FS
    movw %ax, %gs                                   # -> GS
    movw %ax, %ss                                   # -> SS: Stack Segment

    # Set up the stack pointer and call into C. The stack region is from 0--start(0x7c00)
    movl $0x0, %ebp
    movl $start, %esp
    call bootmain

    # If bootmain returns (it shouldn't), loop.
spin:
    jmp spin

# Bootstrap GDT
.p2align 2                                          # force 4 byte alignment
gdt:
    SEG_NULLASM                                     # null seg
    SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)           # code seg for bootloader and kernel
    SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel

gdtdesc:
    .word 0x17                                      # sizeof(gdt) - 1
    .long gdt                                       # address gdt
