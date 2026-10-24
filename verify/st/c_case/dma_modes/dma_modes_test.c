/*
Copyright (c) 2019 Alibaba Group Holding Limited

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/
/* Directed DMA descriptor-mode coverage: widths, increment modes, group mode,
 * endianness and multiple channels. Targets the per-channel fsmc FSM. */
#ifndef FOR_VIP_RUN
#include "stdio.h"
#include "vtimer.h"
#include "datatype.h"
#endif

#define DMAC_BASE      0x40000000
#define DMACCFG        0x4000033c
#define CH_REG(ch, o)  (DMAC_BASE + ((ch) * 0x30) + (o))

/* CHCTRLA fields (see wj_dmac_v2.c) */
#define CTL_LEN(n)     (((n) - 1) << 12)      /* total bytes */
#define CTL_SINC(m)    ((m) << 6)             /* 0 inc, 1 dec, 2 nochange */
#define CTL_DINC(m)    ((m) << 4)
#define CTL_SW(w)      (((w) == 1 ? 0 : ((w) == 2 ? 1 : 2)) << 2)
#define CTL_DW(w)      ((w) == 1 ? 0 : ((w) == 2 ? 1 : 2))
#define CTL_GRP(n)     (((n) - 1) << 8)       /* group length - 1 */

static int dma_run(int ch, unsigned int sar, unsigned int dar,
                   unsigned int ctl, unsigned int ctrlb, unsigned int expect)
{
    unsigned int status = 0;
    long int guard = 0;
    volatile unsigned int d;

    mem_write32_(CH_REG(ch, 0x00), sar);
    mem_write32_(CH_REG(ch, 0x04), dar);
    mem_write32_(CH_REG(ch, 0x08), ctl);
    mem_write32_(CH_REG(ch, 0x0c), ctrlb);
    mem_write32_(CH_REG(ch, 0x10), 0x1f);   /* mask all ints */
    mem_write32_(CH_REG(ch, 0x20), 0x1);    /* channel enable */
    mem_write32_(DMACCFG, 0x1);             /* global enable */
    mem_write32_(CH_REG(ch, 0x1c), 0x1);    /* software request */

    /* Give the channel a few cycles before hammering its status register. */
    for (d = 0; d < 1000; d++)
        ;

    do {
        mem_read32_(CH_REG(ch, 0x14), &status);
        guard++;
    } while (((status & expect) != expect) && (guard < 10000));

    mem_write32_(CH_REG(ch, 0x20), 0x0);    /* channel disable */
    if ((status & expect) != expect) {
        printf("DMA ch%d timeout, status=0x%x\n", ch, status);
        return -1;
    }
    return 0;
}

static void check32(unsigned int addr, unsigned int expect, const char *tag)
{
    unsigned int v = 0;
    mem_read32_(addr, &v);
    if (v != expect) {
        printf("FAIL %s: addr=0x%x exp=0x%x got=0x%x\n", tag, addr, expect, v);
        sim_fail();
    }
}

static void fill_words(unsigned int addr, unsigned int start, int n)
{
    int i;
    for (i = 0; i < n; i++)
        mem_write32_(addr + (unsigned int)i * 4, start + (unsigned int)i * 0x11111111u);
}

static void clear_words(unsigned int addr, int n)
{
    int i;
    for (i = 0; i < n; i++)
        mem_write32_(addr + i * 4, 0);
}

int test_start(void)
{
    int i;

    printf("dma modes start\n");

    /* 0. sanity: exact configuration used by the known-good dma_test.c */
    fill_words(0x20024000, 0x0a0a0a0a, 9);
    clear_words(0x20025000, 9);
    if (dma_run(0, 0x20024000, 0x20025000, 0x2300A, 0x5, 0xe))
        sim_fail();
    check32(0x20025000, 0x0a0a0a0a, "sanity-0");
    check32(0x20025020, 0x92929292, "sanity-8");
    printf("dma sanity transfer done\n");

    /* 1. 8-bit, inc/inc, 8 bytes, ch0 */
    mem_write32_(0x20024040, 0x44332211);
    mem_write32_(0x20024044, 0x88776655);
    clear_words(0x20026000, 2);
    if (dma_run(0, 0x20024040, 0x20026000,
                CTL_LEN(8) | CTL_SINC(0) | CTL_DINC(0) | CTL_SW(1) | CTL_DW(1), 0x5, 0xe))
        sim_fail();
    check32(0x20026000, 0x44332211, "8bit-0");
    check32(0x20026004, 0x88776655, "8bit-1");

    /* 2. 16-bit, inc/inc, 8 bytes, ch1 */
    mem_write32_(0x20024050, 0x11223344);
    mem_write32_(0x20024054, 0x55667788);
    clear_words(0x20026010, 2);
    if (dma_run(1, 0x20024050, 0x20026010,
                CTL_LEN(8) | CTL_SINC(0) | CTL_DINC(0) | CTL_SW(2) | CTL_DW(2), 0x5, 0xe))
        sim_fail();
    check32(0x20026010, 0x11223344, "16bit-0");
    check32(0x20026014, 0x55667788, "16bit-1");

    /* 3. 32-bit, inc/inc, 32 bytes, ch2 */
    fill_words(0x20024060, 0x10203040, 8);
    clear_words(0x20026020, 8);
    if (dma_run(2, 0x20024060, 0x20026020,
                CTL_LEN(32) | CTL_SINC(0) | CTL_DINC(0) | CTL_SW(4) | CTL_DW(4), 0x5, 0xe))
        sim_fail();
    for (i = 0; i < 8; i++)
        check32(0x20026020 + i * 4, 0x10203040 + (unsigned int)i * 0x11111111u, "32bit");

    /* 4. src fixed, dst inc, 4 beats, ch3 */
    mem_write32_(0x20024080, 0xa5a5a5a5);
    clear_words(0x20026040, 4);
    if (dma_run(3, 0x20024080, 0x20026040,
                CTL_LEN(16) | CTL_SINC(2) | CTL_DINC(0) | CTL_SW(4) | CTL_DW(4), 0x5, 0xe))
        sim_fail();
    for (i = 0; i < 4; i++)
        check32(0x20026040 + i * 4, 0xa5a5a5a5, "src-fixed");

    /* 5. src inc, dst fixed, last beat wins, ch4 */
    fill_words(0x20024090, 0x11111111, 4);
    mem_write32_(0x20026060, 0);
    if (dma_run(4, 0x20024090, 0x20026060,
                CTL_LEN(16) | CTL_SINC(0) | CTL_DINC(2) | CTL_SW(4) | CTL_DW(4), 0x5, 0xe))
        sim_fail();
    check32(0x20026060, 0x44444444, "dst-fixed");

    /* 6. src decrement, dst increment: reversed block, ch5 */
    for (i = 0; i < 8; i++)
        mem_write32_(0x200240a0 + i * 4, 0x10101010 + (unsigned int)i * 0x10101010u);  /* 10..80 */
    clear_words(0x20026070, 8);
    if (dma_run(5, 0x200240bc, 0x20026070,
                CTL_LEN(32) | CTL_SINC(1) | CTL_DINC(0) | CTL_SW(4) | CTL_DW(4), 0x5, 0xe))
        sim_fail();
    check32(0x20026070, 0x80808080, "dec-0");
    check32(0x2002608c, 0x10101010, "dec-7");

    /* 7. group mode: one group of one beat, ch6 */
    mem_write32_(0x200240c0, 0x20202020);
    mem_write32_(0x20026090, 0);
    if (dma_run(6, 0x200240c0, 0x20026090,
                CTL_LEN(4) | CTL_SINC(0) | CTL_DINC(0) | CTL_SW(4) | CTL_DW(4) | CTL_GRP(1),
                0x3, 0x8))                        /* group trigger */
        sim_fail();
    check32(0x20026090, 0x20202020, "group");

    /* 8. source big-endian -> destination little-endian (byte swap), ch7 */
    mem_write32_(0x200240e0, 0x11223344);
    mem_write32_(0x200240e4, 0x55667788);
    clear_words(0x200260b0, 2);
    if (dma_run(7, 0x200240e0, 0x200260b0,
                CTL_LEN(8) | CTL_SINC(0) | CTL_DINC(0) | CTL_SW(4) | CTL_DW(4),
                0x5 | (1 << 13), 0xe))
        sim_fail();
    check32(0x200260b0, 0x44332211, "endian-0");
    check32(0x200260b4, 0x88776655, "endian-1");


    /* 9. exercise the remaining DMAC channels (8..15) */
    for (i = 8; i < 16; i++) {
        unsigned int s = 0x20024000 + i * 0x40;
        unsigned int d = 0x20025000 + i * 0x40;
        mem_write32_(s, 0x80000000 + i);
        mem_write32_(d, 0);
        if (dma_run(i, s, d,
                    CTL_LEN(4) | CTL_SINC(0) | CTL_DINC(0) | CTL_SW(4) | CTL_DW(4),
                    0x5, 0xe))
            sim_fail();
        check32(d, 0x80000000 + i, "ch8-15");
    }

    printf("dma modes test successfully\n");
    sim_end();
    return 0;
}
