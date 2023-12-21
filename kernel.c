#include "console.h"
#include "stdio.h"
#include "kdebug.h"
#include "kmonitor.h"
#include "trap.h"

void kern_init(void);

void __attribute__((noinline))
grade_backtrace2(int arg0, int arg1, int arg2, int arg3) {
    mon_backtrace(0, NULL, NULL);
}

void __attribute__((noinline))
grade_backtrace1(int arg0, int arg1) {
    grade_backtrace2(arg0, (int)&arg0, arg1, (int)&arg1);
}

void __attribute__((noinline))
grade_backtrace0(int arg0, int arg1, int arg2) {
    grade_backtrace1(arg0, arg2);
}

void
grade_backtrace(void) {
    grade_backtrace0(0, (int)kern_init, 0xffff0000);
}

void kern_init(void) {
    
    cons_init();                // init the console

    const char *message = "myOS is loading ...";
    cprintf("%s\n\n", message);

    print_kerninfo();

    grade_backtrace();

    return;
}