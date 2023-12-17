target remote 127.0.0.1:1234
set disassembly-flavor intel
set disassemble-next-line on
b *0x7c00
c