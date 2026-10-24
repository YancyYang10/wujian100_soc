/*
Copyright (c) 2019 Alibaba Group Holding Limited
Licensed under the Apache License, Version 2.0.
*/
/* I2C slave transmit test: USI1 (slave) sends 4 bytes loaded in its TX FIFO,
 * USI0 (master) performs a read and checks the returned data. */
#ifndef FOR_VIP_RUN
#include "stdio.h"
#include "vtimer.h"
#include "datatype.h"
#endif

#define USI0_BADDR  0x50028000
#define USI1_BADDR  0x60028000

#define USI_CTRL    0x00
#define MODE_SEL    0x04
#define TX_FIFO     0x08
#define RX_FIFO     0x08
#define FIFO_STA    0x0c
#define CLK_DIV0    0x10
#define CLK_DIV1    0x14
#define I2C_MODE    0x20
#define I2C_ADDR    0x24
#define I2CM_CTRL   0x28
#define I2C_STA     0x3c

int test_start(void)
{
    unsigned int expect[4];
    long int reg;
    int i, cnt = 0;

    expect[0] = 0x5a; expect[1] = 0xa5;
    expect[2] = 0x3c; expect[3] = 0xc3;

    /* USI1: I2C slave with TX FIFO, preload data */
    mem_write32_(USI1_BADDR + MODE_SEL, 0x1);
    mem_write32_(USI1_BADDR + I2C_MODE, 0x0);
    mem_write32_(USI1_BADDR + I2C_ADDR, 0x3c);
    mem_write32_(USI1_BADDR + USI_CTRL, 0x7);     /* EN + TX FIFO */
    for (i = 0; i < 4; i++)
        mem_write32_(USI1_BADDR + TX_FIFO, expect[i]);

    /* USI0: I2C master, 100kHz */
    mem_write32_(USI0_BADDR + MODE_SEL, 0x1);
    mem_write32_(USI0_BADDR + CLK_DIV0, 0x63);
    mem_write32_(USI0_BADDR + CLK_DIV1, 0x63);
    mem_write32_(USI0_BADDR + I2C_MODE, 0x1);
    mem_write32_(USI0_BADDR + I2C_ADDR, 0x3c);
    mem_write32_(USI0_BADDR + I2CM_CTRL, 0x2);
    mem_write32_(USI0_BADDR + USI_CTRL, 0xf);

    /* Start a master read */
    mem_write32_(USI0_BADDR + TX_FIFO, 0x300);

    do {
        mem_read32_(USI0_BADDR + FIFO_STA, &reg);
        if ((reg & 0x4) == 0) {
            mem_read32_(USI0_BADDR + RX_FIFO, &reg);
            if ((reg & 0xff) != expect[cnt]) {
                printf("i2c slave tx FAIL cnt=%d exp=0x%x got=0x%x\n",
                       cnt, expect[cnt], (reg & 0xff));
                sim_fail();
            }
            cnt++;
            mem_write32_(USI0_BADDR + TX_FIFO, 0x100);
        }
    } while (cnt < 4);

    printf("i2c slave tx test successfully\n");
    sim_end();
    return 0;
}
