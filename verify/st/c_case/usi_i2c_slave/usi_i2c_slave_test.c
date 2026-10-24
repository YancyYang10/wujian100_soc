/*
Copyright (c) 2019 Alibaba Group Holding Limited
Licensed under the Apache License, Version 2.0.
*/
/* I2C slave directed test: two transactions with different slave addresses
 * and payloads, checking the received data. Exercises i2cs address compare,
 * start/stop and FIFO paths (USI0 master -> USI1 slave loopback). */
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

static void i2c_round(unsigned int addr, unsigned int d0, unsigned int d1,
                      unsigned int d2, unsigned int d3)
{
    unsigned int expect[4];
    long int reg, tx_empty, i2c_busy, rx_empty;
    int cnt = 0;

    expect[0] = d0; expect[1] = d1; expect[2] = d2; expect[3] = d3;
    printf("round start addr=0x%x\n", addr);

    /* USI0: I2C master, 100kHz */
    mem_write32_(USI0_BADDR + MODE_SEL, 0x1);
    mem_write32_(USI0_BADDR + CLK_DIV0, 0x63);
    mem_write32_(USI0_BADDR + CLK_DIV1, 0x63);
    mem_write32_(USI0_BADDR + I2C_MODE, 0x1);
    mem_write32_(USI0_BADDR + I2C_ADDR, addr);
    mem_write32_(USI0_BADDR + I2CM_CTRL, 0x2);
    mem_write32_(USI0_BADDR + USI_CTRL, 0x7);

    /* USI1: I2C slave at the same address */
    mem_write32_(USI1_BADDR + MODE_SEL, 0x1);
    mem_write32_(USI1_BADDR + I2C_MODE, 0x0);
    mem_write32_(USI1_BADDR + I2C_ADDR, addr);
    mem_write32_(USI1_BADDR + USI_CTRL, 0xb);

    mem_write32_(USI0_BADDR + TX_FIFO, d0);
    mem_write32_(USI0_BADDR + TX_FIFO, d1);
    mem_write32_(USI0_BADDR + TX_FIFO, d2);
    mem_write32_(USI0_BADDR + TX_FIFO, d3);

    do {
        mem_read32_(USI0_BADDR + FIFO_STA, &reg); tx_empty = reg & 0x1;
        mem_read32_(USI0_BADDR + I2C_STA, &reg);  i2c_busy = reg & 0x1;
    } while (tx_empty == 0 || i2c_busy == 1);

    do {
        mem_read32_(USI1_BADDR + FIFO_STA, &reg); rx_empty = reg & 0x4;
        if (rx_empty == 0) {
            mem_read32_(USI1_BADDR + RX_FIFO, &reg);
            if ((reg & 0xff) != expect[cnt]) {
                printf("i2c slave FAIL addr=0x%x cnt=%d exp=0x%x got=0x%x\n",
                       addr, cnt, expect[cnt], (reg & 0xff));
                sim_fail();
            }
            cnt++;
        }
    } while (cnt < 4);
}

int test_start(void)
{
    printf("i2c slave test start\n");
    i2c_round(0x3c, 0xa5, 0xa6, 0xa7, 0xa8);
    printf("i2c slave round1 done\n");
    i2c_round(0x55, 0x5a, 0x5b, 0x5c, 0x5d);
    printf("i2c slave round2 done\n");
    printf("i2c slave test successfully\n");
    sim_end();
    return 0;
}
