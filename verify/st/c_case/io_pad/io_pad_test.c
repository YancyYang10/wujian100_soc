/* Interface pad toggle test: the io_pad stimulus (+HW_STIM=io) toggles the
 * otherwise unused top-level pads; this C program just keeps the sim alive. */
#ifndef FOR_VIP_RUN
#include "stdio.h"
#include "vtimer.h"
#include "datatype.h"
#endif

int test_start(void)
{
    volatile int i;
    printf("io pad test start\n");
    for (i = 0; i < 3000; i++)
        ;
    printf("io pad test successfully\n");
    sim_end();
    return 0;
}
