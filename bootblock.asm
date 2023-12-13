
bootblock.o:     file format elf32-i386


Disassembly of section .text:

00007c00 <start>:

# start address should be 0:7c00, in real mode, the beginning address of the running bootloader
.globl start
start:
.code16                                             # Assemble for 16-bit mode
    cli                                             # Disable interrupts
    7c00:	fa                   	cli    
    # 地址指针时增加还是减少取决于方向标志DF。在系统初始化后或者执行指令CLD指令后，DF(direct flag)=0,此 时地址指针增1或2；在执行指令STD后，DF=1，此时地址指针减1或2。
    cld                                             # String operations increment
    7c01:	fc                   	cld    

    # Set up the important data segment registers (DS, ES, SS).
    # 按位异或	^	xorb、xorw、xorl
    xorw %ax, %ax                                   # Segment number zero
    7c02:	31 c0                	xor    %eax,%eax
    movw %ax, %ds                                   # -> Data Segment
    7c04:	8e d8                	mov    %eax,%ds
    movw %ax, %es                                   # -> Extra Segment
    7c06:	8e c0                	mov    %eax,%es
    movw %ax, %ss                                   # -> Stack Segment
    7c08:	8e d0                	mov    %eax,%ss

#     movb $0xdf, %al                                 # 0xdf -> port 0x60
#     outb %al, $0x60                                 # 0xdf = 11011111, means set P2's A20 bit(the 1 bit) to 1

    # 打开地址线A20的另一种方法：通过0x92端口打开。
	in	$0x92, %al
    7c0a:	e4 92                	in     $0x92,%al
	or	$0x2, %al 
    7c0c:	0c 02                	or     $0x2,%al
	out	%al, $0x92 
    7c0e:	e6 92                	out    %al,$0x92
    # identical to physical addresses, so that the
    # effective memory map does not change during the switch.
    # 单独为我们准备了一个寄存器叫做 GDTR 用来保存我们 GDT 在内存中的位置和我们 GDT 的长度。#GDTR 寄存器一共 48 位，其中高 32 位用来存储我们的 GDT 在内存中的位置，
    # 其余的低 16 位用来存我们的 GDT 有多少个段描述符。 #16 位最大可以表示 65536 个数，这里我们把单位换成字节，而一个段描述符是 8 字节，所以 GDT 最多可以有 8192 个段描述符。
    # #CPU 不仅用了一个单独的寄存器 GDTR 来存储我们的 GDT，而且还专门提供了一个指令用来让我们把 GDT 的地址和长度传给 GDTR 寄存器：lgdt gdtdesc
    lgdt gdtdesc
    7c10:	0f 01 16             	lgdtl  (%esi)
    7c13:	5c                   	pop    %esp
    7c14:	7c 0f                	jl     7c25 <protcseg+0x1>

    # 打开保护模式标志位，相当于按下了保护模式的开关。cr0寄存器的第0位就是这个开关
    movl %cr0, %eax
    7c16:	20 c0                	and    %al,%al
    orl $CR0_PE_ON, %eax
    7c18:	66 83 c8 01          	or     $0x1,%ax
    movl %eax, %cr0
    7c1c:	0f 22 c0             	mov    %eax,%cr0
    # PROT_MODE_CSEG选择子选择了GDT中的第1个段描述符
    # 通过长跳转指令进入保护模式。80386在执行长跳转指令时，会重新加载$PROT_MODE_CSEG的值（即0x8）到CS中，同时把$protcseg的值赋给EIP，
    #     这样80386就会把CS的值作为全局描述符表的索引来找到对应的代码段描述符，设定当前的EIP为0x7c32(即protcseg标号所在的段内偏移)， 
    #     根据2.2.3节描述的分段机制中虚拟地址到线性地址转换转换的基本过程，可以知道线性地址（即物理地址）为：
    #     gdt[CS].base_addr+EIP=0x0+0x7c32=0x7c32 ljmp $PROT_MODE_CSEG, $protcseg
    ljmp $PROT_MODE_CSEG, $protcseg
    7c1f:	ea                   	.byte 0xea
    7c20:	24 7c                	and    $0x7c,%al
    7c22:	08 00                	or     %al,(%eax)

00007c24 <protcseg>:
    # Set up the protected-mode data segment registers
    # .set PROT_MODE_DSEG,        0x10
    # .set PROT_MODE_CSEG,        0x8
    # INDEX　　　　　　　　  TI     CPL
    # 0000 0001 0         00      0
    movw $PROT_MODE_DSEG, %ax                       # Our data segment selector
    7c24:	66 b8 10 00          	mov    $0x10,%ax
    movw %ax, %ds                                   # -> DS: Data Segment
    7c28:	8e d8                	mov    %eax,%ds
    movw %ax, %es                                   # -> ES: Extra Segment
    7c2a:	8e c0                	mov    %eax,%es
    movw %ax, %fs                                   # -> FS
    7c2c:	8e e0                	mov    %eax,%fs
    movw %ax, %gs                                   # -> GS
    7c2e:	8e e8                	mov    %eax,%gs
    movw %ax, %ss                                   # -> SS: Stack Segment
    7c30:	8e d0                	mov    %eax,%ss
    # Set up the stack pointer and call into C. The stack region is from 0--start(0x7c00)
    # EBP 扩展基址指针寄存器(extended base pointer) 其内存放一个指针，该指针指向系统栈最上面一个栈帧的底部。rbp寄存器,是ebp寄存器64位扩展.
    # PUSH %rbp是把%rbp寄存器的值保存到内存里面的数组模拟栈. 结合下面的mov %rsp,%rbp可以知道, %rbp此刻push的就是上面一个栈帧的栈低位置
    # ESP（Extended Stack Pointer）为扩展栈指针寄存器，是指针寄存器的一种，用于存放函数栈顶指针。与之对应的是EBP（Extended Base Pointer），
    #    扩展基址指针寄存器，也被称为帧指针寄存器，用于存放函数栈底指针。ESP为栈指针，用于指向栈的栈顶（下一个压入栈的活动记录的顶部），而EBP为帧指针，指向当前活动记录的底部
    movl $0x0, %ebp
    7c32:	bd 00 00 00 00       	mov    $0x0,%ebp
    movl $start, %esp
    7c37:	bc 00 7c 00 00       	mov    $0x7c00,%esp
    call bootmain
    7c3c:	e8 bc 00 00 00       	call   7cfd <bootmain>

00007c41 <spin>:

    # If bootmain returns (it shouldn't), loop.
spin:
    jmp spin
    7c41:	eb fe                	jmp    7c41 <spin>
    7c43:	90                   	nop

00007c44 <gdt>:
	...
    7c4c:	ff                   	(bad)  
    7c4d:	ff 00                	incl   (%eax)
    7c4f:	00 00                	add    %al,(%eax)
    7c51:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
    7c58:	00                   	.byte 0x0
    7c59:	92                   	xchg   %eax,%edx
    7c5a:	cf                   	iret   
	...

00007c5c <gdtdesc>:
    7c5c:	17                   	pop    %ss
    7c5d:	00 44 7c 00          	add    %al,0x0(%esp,%edi,2)
	...

00007c62 <readseg>:
/* *
 * readseg - read @count bytes at @offset from kernel into virtual address @va,
 * might copy more than asked.
 * */
static void
readseg(uintptr_t va, uint32_t count, uint32_t offset) {
    7c62:	55                   	push   %ebp
    7c63:	89 e5                	mov    %esp,%ebp
    7c65:	57                   	push   %edi
    uintptr_t end_va = va + count;
    7c66:	8d 3c 10             	lea    (%eax,%edx,1),%edi

    // round down to sector boundary
    va -= offset % SECTSIZE;
    7c69:	89 ca                	mov    %ecx,%edx
readseg(uintptr_t va, uint32_t count, uint32_t offset) {
    7c6b:	56                   	push   %esi
    va -= offset % SECTSIZE;
    7c6c:	81 e2 ff 01 00 00    	and    $0x1ff,%edx

    // translate from bytes to sectors; kernel starts at sector 1
    uint32_t secno = (offset / SECTSIZE) + 1;
    7c72:	c1 e9 09             	shr    $0x9,%ecx
readseg(uintptr_t va, uint32_t count, uint32_t offset) {
    7c75:	53                   	push   %ebx
    va -= offset % SECTSIZE;
    7c76:	29 d0                	sub    %edx,%eax
    uint32_t secno = (offset / SECTSIZE) + 1;
    7c78:	8d 71 01             	lea    0x1(%ecx),%esi
readseg(uintptr_t va, uint32_t count, uint32_t offset) {
    7c7b:	53                   	push   %ebx
    va -= offset % SECTSIZE;
    7c7c:	89 c3                	mov    %eax,%ebx
    uintptr_t end_va = va + count;
    7c7e:	89 7d f0             	mov    %edi,-0x10(%ebp)

    // If this is too slow, we could read lots of sectors at a time.
    // We'd write more to memory than asked, but it doesn't matter --
    // we load in increasing order.
    for (; va < end_va; va += SECTSIZE, secno ++) {
    7c81:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
    7c84:	73 71                	jae    7cf7 <readseg+0x95>
static inline void ltr(uint16_t sel) __attribute__((always_inline));

static inline uint8_t
inb(uint16_t port) {
    uint8_t data;
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port));
    7c86:	ba f7 01 00 00       	mov    $0x1f7,%edx
    7c8b:	ec                   	in     (%dx),%al
    while ((inb(0x1F7) & 0xC0) != 0x40)
    7c8c:	83 e0 c0             	and    $0xffffffc0,%eax
    7c8f:	3c 40                	cmp    $0x40,%al
    7c91:	75 f3                	jne    7c86 <readseg+0x24>
            : "memory", "cc");
}

static inline void
outb(uint16_t port, uint8_t data) {
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port));
    7c93:	ba f2 01 00 00       	mov    $0x1f2,%edx
    7c98:	b0 01                	mov    $0x1,%al
    7c9a:	ee                   	out    %al,(%dx)
    7c9b:	ba f3 01 00 00       	mov    $0x1f3,%edx
    7ca0:	89 f0                	mov    %esi,%eax
    7ca2:	ee                   	out    %al,(%dx)
    outb(0x1F4, (secno >> 8) & 0xFF);
    7ca3:	89 f0                	mov    %esi,%eax
    7ca5:	ba f4 01 00 00       	mov    $0x1f4,%edx
    7caa:	c1 e8 08             	shr    $0x8,%eax
    7cad:	ee                   	out    %al,(%dx)
    outb(0x1F5, (secno >> 16) & 0xFF);
    7cae:	89 f0                	mov    %esi,%eax
    7cb0:	ba f5 01 00 00       	mov    $0x1f5,%edx
    7cb5:	c1 e8 10             	shr    $0x10,%eax
    7cb8:	ee                   	out    %al,(%dx)
    outb(0x1F6, ((secno >> 24) & 0xF) | 0xE0);
    7cb9:	89 f0                	mov    %esi,%eax
    7cbb:	ba f6 01 00 00       	mov    $0x1f6,%edx
    7cc0:	c1 e8 18             	shr    $0x18,%eax
    7cc3:	83 e0 0f             	and    $0xf,%eax
    7cc6:	83 c8 e0             	or     $0xffffffe0,%eax
    7cc9:	ee                   	out    %al,(%dx)
    7cca:	b0 20                	mov    $0x20,%al
    7ccc:	ba f7 01 00 00       	mov    $0x1f7,%edx
    7cd1:	ee                   	out    %al,(%dx)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port));
    7cd2:	ba f7 01 00 00       	mov    $0x1f7,%edx
    7cd7:	ec                   	in     (%dx),%al
    while ((inb(0x1F7) & 0xC0) != 0x40)
    7cd8:	83 e0 c0             	and    $0xffffffc0,%eax
    7cdb:	3c 40                	cmp    $0x40,%al
    7cdd:	75 f3                	jne    7cd2 <readseg+0x70>
    asm volatile (
    7cdf:	89 df                	mov    %ebx,%edi
    7ce1:	b9 80 00 00 00       	mov    $0x80,%ecx
    7ce6:	ba f0 01 00 00       	mov    $0x1f0,%edx
    7ceb:	fc                   	cld    
    7cec:	f2 6d                	repnz insl (%dx),%es:(%edi)
    for (; va < end_va; va += SECTSIZE, secno ++) {
    7cee:	81 c3 00 02 00 00    	add    $0x200,%ebx
    7cf4:	46                   	inc    %esi
    7cf5:	eb 8a                	jmp    7c81 <readseg+0x1f>
        readsect((void *)va, secno);
    }
}
    7cf7:	58                   	pop    %eax
    7cf8:	5b                   	pop    %ebx
    7cf9:	5e                   	pop    %esi
    7cfa:	5f                   	pop    %edi
    7cfb:	5d                   	pop    %ebp
    7cfc:	c3                   	ret    

00007cfd <bootmain>:

/* bootmain - the entry of bootloader */
void
bootmain(void) {
    7cfd:	55                   	push   %ebp
    // read the 1st page off disk
    readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);
    7cfe:	31 c9                	xor    %ecx,%ecx
    7d00:	ba 00 10 00 00       	mov    $0x1000,%edx
    7d05:	b8 00 00 01 00       	mov    $0x10000,%eax
bootmain(void) {
    7d0a:	89 e5                	mov    %esp,%ebp
    7d0c:	56                   	push   %esi
    7d0d:	53                   	push   %ebx
    readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);
    7d0e:	e8 4f ff ff ff       	call   7c62 <readseg>

    // is this a valid ELF?
    if (ELFHDR->e_magic != ELF_MAGIC) {
    7d13:	81 3d 00 00 01 00 7f 	cmpl   $0x464c457f,0x10000
    7d1a:	45 4c 46 
    7d1d:	75 3f                	jne    7d5e <bootmain+0x61>
    }

    struct proghdr *ph, *eph;

    // load each program segment (ignores ph flags)
    ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);
    7d1f:	a1 1c 00 01 00       	mov    0x1001c,%eax
    eph = ph + ELFHDR->e_phnum;
    7d24:	0f b7 35 2c 00 01 00 	movzwl 0x1002c,%esi
    ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);
    7d2b:	8d 98 00 00 01 00    	lea    0x10000(%eax),%ebx
    eph = ph + ELFHDR->e_phnum;
    7d31:	c1 e6 05             	shl    $0x5,%esi
    7d34:	01 de                	add    %ebx,%esi
    for (; ph < eph; ph ++) {
    7d36:	39 f3                	cmp    %esi,%ebx
    7d38:	73 18                	jae    7d52 <bootmain+0x55>
        readseg(ph->p_va & 0xFFFFFF, ph->p_memsz, ph->p_offset);
    7d3a:	8b 43 08             	mov    0x8(%ebx),%eax
    7d3d:	8b 4b 04             	mov    0x4(%ebx),%ecx
    for (; ph < eph; ph ++) {
    7d40:	83 c3 20             	add    $0x20,%ebx
        readseg(ph->p_va & 0xFFFFFF, ph->p_memsz, ph->p_offset);
    7d43:	8b 53 f4             	mov    -0xc(%ebx),%edx
    7d46:	25 ff ff ff 00       	and    $0xffffff,%eax
    7d4b:	e8 12 ff ff ff       	call   7c62 <readseg>
    7d50:	eb e4                	jmp    7d36 <bootmain+0x39>
    }

    // call the entry point from the ELF header
    // note: does not return
    ((void (*)(void))(ELFHDR->e_entry & 0xFFFFFF))();
    7d52:	a1 18 00 01 00       	mov    0x10018,%eax
    7d57:	25 ff ff ff 00       	and    $0xffffff,%eax
    7d5c:	ff d0                	call   *%eax
}

static inline void
outw(uint16_t port, uint16_t data) {
    asm volatile ("outw %0, %1" :: "a" (data), "d" (port));
    7d5e:	ba 00 8a ff ff       	mov    $0xffff8a00,%edx
    7d63:	89 d0                	mov    %edx,%eax
    7d65:	66 ef                	out    %ax,(%dx)
    7d67:	b8 00 8e ff ff       	mov    $0xffff8e00,%eax
    7d6c:	66 ef                	out    %ax,(%dx)
    7d6e:	eb fe                	jmp    7d6e <bootmain+0x71>
