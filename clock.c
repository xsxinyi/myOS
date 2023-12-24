#include "x86.h"
#include "trap.h"
#include "stdio.h"
#include "picirq.h"

/* *
 * Support for time-related hardware gadgets - the 8253 timer,
 * which generates interruptes on IRQ-0.
 * */

#define IO_TIMER1           0x040               // 8253 Timer #1

/* *
 * Frequency of all three count-down timers; (TIMER_FREQ/freq)
 * is the appropriate count to generate a frequency of freq Hz.
 * */

#define TIMER_FREQ      1193182
#define TIMER_DIV(x)    ((TIMER_FREQ + (x) / 2) / (x))

#define TIMER_MODE      (IO_TIMER1 + 3)         // timer mode port
#define TIMER_SEL0      0x00                    // select counter 0
#define TIMER_RATEGEN   0x04                    // mode 2, rate generator
#define TIMER_16BIT     0x30                    // r/w counter 16 bits, LSB first.

// MSB LSB：起始地址为最高位， 最后地址为最低位。

// LSB MSB：起始地址为最低位，最后地址为最高位。

volatile size_t ticks;

/* *
 * clock_init - initialize 8253 clock to interrupt 100 times per second,
 * and then enable IRQ_TIMER.
//  * */
// https://www.guyuehome.com/37630
// 操作系统对可编程定时/计数器进行有关初始化，然后定时/计数器就对输入脉冲进行计数(分频)，产生的三个输出脉冲Out0、Out1、Out2各有用途，
// 很多接口书都介绍了这个问题，我们只看Out0上的输出脉冲，这个脉冲信号接到中断控制器8259A_1的0号管脚，触发一个周期性的中断，我们就把这个中断叫做时钟中断，
// 时钟中断的周期，也就是脉冲信号的周期，我们叫做“滴答”或“时标”(tick)。从本质上说，时钟中断只是一个周期性的信号，完全是硬件行为，
// 该信号触发CPU去执行一个中断服务程序，但是为了方便，我们就把这个服务程序叫做时钟中断。
// ————————————————
// 版权声明：本文为CSDN博主「攻城狮百里」的原创文章，遵循CC 4.0 BY-SA版权协议，转载请附上原文出处链接及本声明。
// 原文链接：https://blog.csdn.net/weixin_52622200/article/details/122992817
// 名称	端口地址	工作方式	产生的输出脉冲的用途
// 计数器0	0x40	方式3	时钟中断，也叫系统时钟
// 计数器1	0x41	方式2	动态存储器刷新
// 计数器2	0x42	方式3	扬声器发声
// 控制寄存器	0x43	/	用于8253的初始化，接收控制字

void
clock_init(void) {
    // set 8253 timer-chip
    outb(TIMER_MODE, TIMER_SEL0 | TIMER_RATEGEN | TIMER_16BIT);
    outb(IO_TIMER1, TIMER_DIV(100) % 256);
    outb(IO_TIMER1, TIMER_DIV(100) / 256);

    // initialize time counter 'ticks' to zero
    ticks = 0;

    cprintf("++ setup timer interrupts\n");
    pic_enable(IRQ_TIMER);
}

