.PHONY: all
all: ucore.img
	qemu-system-i386 -m 4G -hda $< 

.PHONY: log
log: ucore.img
	gnome-terminal -e "qemu-system-i386  -S -s -d in_asm -D ./q.log -monitor stdio -hda $< -serial null"
	sleep 2
	gnome-terminal  -e "gdb -q -x loginit"

.PHONY: gdb
gdb: ucore.img
	qemu-system-i386 -S -s -m 4G -parallel stdio -hda $< -serial null &
	sleep 2
	# gnome-terminal -e "gdb -q -tui -x gdbinit"
	gdb -x gdbinit

.PHONY: debug
debug: ucore.img
	# qemu-system-i386 -S -s -parallel stdio -hda $< -serial null
	# qemu-system-i386 -S -s -m 32M -boot c -hda $< 
	qemu-system-i386 -S -s -m 4G -hda $< 

# ucore.img:	bootblock kernel kernel_nopage
ucore.img:	bootblock kernel
	dd if=/dev/zero of=ucore.img count=10000
	dd if=bootblock of=ucore.img conv=notrunc
	dd if=kernel of=ucore.img seek=1 conv=notrunc

bootblock: sign bootblock.out
	./sign bootblock.out bootblock

sign : sign.o
	gcc -g -Wall -O2 sign.o -o sign

sign.o : sign.c
	gcc -g -Wall -O2 -c sign.c -o sign.o

bootblock.out: bootasm.o bootmain.o
	# ld cmd for lab1. lab needs to reduce some memory to meet the 512B limitation.
	# ld -m elf_i386 -nostdlib -N -e start -Ttext 0x7C00 bootasm.o bootmain.o -o bootblock.o
	ld -m elf_i386 -nostdlib -N -T boot.ld bootasm.o bootmain.o -o bootblock.o
	objdump -S bootblock.o > bootblock.asm
	objcopy -S -O binary bootblock.o bootblock.out	

bootmain.o: bootmain.c
	gcc -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Os -nostdinc -c bootmain.c -o bootmain.o	

bootasm.o: bootasm.S
	gcc -I./ -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Os -nostdinc -c bootasm.S -o bootasm.o

kernel: entry.o kernel.o console.o stdio.o picirq.o string.o printfmt.o kdebug.o kmonitor.o trap.o readline.o vectors.o clock.o panic.o intr.o trapentry.o pmm.o
	ld -m elf_i386 -nostdlib -T kernel.ld -o kernel entry.o kernel.o console.o stdio.o picirq.o string.o printfmt.o kdebug.o kmonitor.o trap.o readline.o vectors.o clock.o panic.o intr.o trapentry.o pmm.o
	objdump -S kernel > kernel.asm
	objdump -t kernel > kernel.sym
	objdump -G kernel > kernel.stab

# kernel_nopage: entry.o kernel.o console.o stdio.o picirq.o string.o printfmt.o kdebug.o kmonitor.o trap.o readline.o vectors.o clock.o panic.o intr.o trapentry.o pmm.o
# 	ld -m elf_i386 -nostdlib -T kernel_nopage.ld -o kernel_nopage entry.o kernel.o console.o stdio.o picirq.o string.o printfmt.o kdebug.o kmonitor.o trap.o readline.o vectors.o clock.o panic.o intr.o trapentry.o pmm.o
# 	objdump -S kernel_nopage > kernel_nopage.asm
# 	objdump -t kernel_nopage > kernel_nopage.sym
# 	objdump -G kernel_nopage > kernel_nopage.stab

kernel.o: kernel.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c kernel.c -o kernel.o

console.o: console.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c console.c -o console.o

stdio.o: stdio.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c stdio.c -o stdio.o


picirq.o: picirq.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c picirq.c -o picirq.o

string.o: string.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c string.c -o string.o

printfmt.o: printfmt.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c printfmt.c -o printfmt.o

kdebug.o: kdebug.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c kdebug.c -o kdebug.o

kmonitor.o: kmonitor.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c kmonitor.c -o kmonitor.o

trap.o: trap.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c trap.c -o trap.o

readline.o: readline.c
	gcc -I./ -I./tools -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c readline.c -o readline.o

vectors.o: vectors.S
	gcc -I./ -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -c vectors.S -o vectors.o

clock.o: clock.c
	gcc -I./ -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -c clock.c -o clock.o

panic.o: panic.c
	gcc -I./ -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -c panic.c -o panic.o

intr.o: intr.c
	gcc -I./ -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -c intr.c -o intr.o

trapentry.o: trapentry.S
	gcc -I./ -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -c trapentry.S -o trapentry.o

pmm.o: pmm.c
	gcc -I./ -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -c pmm.c -o pmm.o

entry.o: entry.S
	gcc -I./ -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -c entry.S -o entry.o

clean:
	rm -rf *.o kernel sign bootblock bootblock.asm bootblock.out ucore.img kernel.sym kernel.asm kernel.stab q.log