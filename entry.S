#include "memlayout.h"

; #define KERNBASE            0xC0000000
#define KERNBASE            0x00000000
#define REALLOC(x)          (x - KERNBASE)

.text
.globl kern_entry
kern_entry:
    # now kernel stack is ready , call the first C function
    call kern_init

