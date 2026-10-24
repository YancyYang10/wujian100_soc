/* PWM all-channel test: configures all 12 channels to output a 50% waveform,
 * toggling every PAD_PWM_* and the PWM module interface ports. */
#ifndef FOR_VIP_RUN
#include "stdio.h"
#include "vtimer.h"
#include "datatype.h"
#endif

#define PWM_BASE 0x5001c000

int test_start(void)
{
    volatile int i;
    unsigned int off;

    /* count-up mode for all pairs */
    mem_write32_(PWM_BASE + 0x34, 0x00000000);
    /* LOAD: low/high halves = 0x20 for ch0..ch11 */
    mem_write32_(PWM_BASE + 0x38, 0x00200020);
    mem_write32_(PWM_BASE + 0x3C, 0x00200020);
    mem_write32_(PWM_BASE + 0x40, 0x00200020);
    /* CMP: 0x10 -> 50% duty */
    for (off = 0x50; off <= 0x64; off += 4)
        mem_write32_(PWM_BASE + off, 0x00100010);
    /* all 12 outputs enable + clock div enable */
    mem_write32_(PWM_BASE + 0x00, 0x09000FFF);

    for (i = 0; i < 2000; i++)
        ;

    printf("pwm all channel test successfully\n");
    sim_end();
    return 0;
}
