.PHONY: all
all: ucore.img
	qemu-system-i386 -hda $< 

.PHONY: gdb
gdb: ucore.img
	qemu-system-i386 -S -s -parallel stdio -hda $< -serial null &
	sleep 2
	gnome-terminal -e "gdb -q -tui -x gdbinit"

.PHONY: debug
debug: ucore.img
	# qemu-system-i386 -S -s -parallel stdio -hda $< -serial null
	# qemu-system-i386 -S -s -m 32M -boot c -hda $< 
	qemu-system-i386 -S -s -m 32M -hda $< 

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
	ld -m elf_i386 -nostdlib -N -e start -Ttext 0x7C00 bootasm.o bootmain.o -o bootblock.o
	objdump -S bootblock.o > bootblock.asm
	objcopy -S -O binary bootblock.o bootblock.out	

bootmain.o: bootmain.c
	gcc -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Os -nostdinc -c bootmain.c -o bootmain.o	

bootasm.o: bootasm.S
	gcc -I./ -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Os -nostdinc -c bootasm.S -o bootasm.o

kernel: kernel.o console.o stdio.o picirq.o string.o printfmt.o kdebug.o
	ld -m elf_i386 -nostdlib -T kernel.ld -o kernel kernel.o console.o stdio.o picirq.o string.o printfmt.o kdebug.o
	objdump -S kernel > kernel.asm
	objdump -t kernel > kernel.sym

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

clean:
	rm -rf *.o kernel sign bootblock bootblock.asm bootblock.out ucore.img kernel.sym kernel.asm