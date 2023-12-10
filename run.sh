rm *.o
rm kernel sign bootblock bootblock.asm bootblock.out
rm ucore.img

gcc -g -Wall -O2 -c sign.c -o sign.o
gcc -g -Wall -O2 sign.o -o sign

# gcc -I./ -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Os -nostdinc -c bootasm.S -o bootasm.o
# gcc -I./ -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Os -nostdinc -c bootmain.c -o bootmain.o
gcc -I./ -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Os -nostdinc -c bootasm.S -o bootasm.o
gcc -I./tools -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc  -fno-stack-protector -Os -nostdinc -c bootmain.c -o bootmain.o

# ld -m    elf_i386 -nostdlib -N -e start -Ttext 0x7C00 obj/boot/bootasm.o obj/boot/bootmain.o -o obj/bootblock.o
ld -m elf_i386 -nostdlib -N -e start -Ttext 0x7C00 bootasm.o bootmain.o -o bootblock.o

objdump -S bootblock.o > bootblock.asm
objcopy -S -O binary bootblock.o bootblock.out

./sign bootblock.out bootblock

gcc -I./ -fno-builtin -Wall -g -m32 -gstabs -nostdinc  -fno-stack-protector -c kernel.c -o kernel.o
# ld -m elf_i386 kernel.o -o kernel
ld -m elf_i386 -nostdlib -T kernel.ld -o kernel kernel.o

dd if=/dev/zero of=ucore.img count=10000
dd if=bootblock of=ucore.img conv=notrunc
dd if=kernel of=ucore.img seek=1 conv=notrunc

# qemu-system-i386 ucore.img -S -s
# $@--目标文件，$^--所有的依赖文件，$<--第一个依赖文件。
qemu-system-i386 -S -s -parallel stdio -hda ucore.img -serial null
