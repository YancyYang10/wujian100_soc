/* Bus interface sweep: toggles SoC top-level block bus ports using only
 * mapped regions:
 *  - DSRAM1/DSRAM2 address + data sweep (m2 data path, retu/sms ports)
 *  - register-block read sweep of the known APB peripherals
 * Read-only for peripherals to avoid side effects. */
#ifndef FOR_VIP_RUN
#include "stdio.h"
#include "vtimer.h"
#include "datatype.h"
#endif

static void sweep_block(unsigned int base)
{
    unsigned int off, v;
    for (off = 0; off < 0x100; off += 4)
        mem_read32_(base + off, &v);
}

int test_start(void)
{
    unsigned int addr, v;
    volatile int i;

    /* DSRAM1/DSRAM2 address + data sweep */
    for (addr = 0x20010000; addr < 0x20030000; addr += 0x40) {
        mem_write32_(addr, addr ^ 0xA5A5A5A5);
        mem_read32_(addr, &v);
        if (v != (addr ^ 0xA5A5A5A5)) {
            printf("bus sweep FAIL mem 0x%x got 0x%x\n", addr, v);
            sim_fail();
        }
    }

    /* mapped APB register blocks */
    sweep_block(0x50000000);   /* TIM0 */
    sweep_block(0x50000400);   /* TIM2 */
    sweep_block(0x50008000);   /* WDT */
    sweep_block(0x5001C000);   /* PWM */
    sweep_block(0x50028000);   /* USI0 */
    sweep_block(0x60004000);   /* RTC */
    sweep_block(0x60018000);   /* GPIO */
    sweep_block(0x60028000);   /* USI1 */

    for (i = 0; i < 100; i++)
        ;
    printf("bus sweep test successfully\n");
    sim_end();
    return 0;
}
