#include "console.h"
#include "stdio.h"
#include "kdebug.h"

void kern_init(void) {
    
    cons_init();                // init the console

    const char *message = "myOS is loading ...";
    cprintf("%s\n\n", message);

    print_kerninfo();

    return;
}