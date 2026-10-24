/*
Copyright (c) 2019 Alibaba Group Holding Limited
Licensed under the Apache License, Version 2.0.
*/
/* CPU directed test: synchronous exceptions + CSR access.
 * Installs a minimal trap handler, triggers ecall/ebreak/illegal instruction/
 * load & store access faults, and checks mcause/mepc bookkeeping. */
#ifndef FOR_VIP_RUN
#include "stdio.h"
#include "vtimer.h"
#include "datatype.h"
#endif

volatile unsigned int cpu_exc_cause;
volatile unsigned int cpu_exc_mepc;
volatile unsigned int cpu_exc_count;
volatile unsigned int cpu_int_count;

/* Minimal trap entry: saves t0-t6/a0-a5, records mcause/mepc, skips the
 * faulting instruction (2 or 4 bytes) and returns with mret. Interrupts are
 * counted and masked to avoid retriggering. */
__asm__(
".text\n"
".align 4\n"
".global cpu_trap_entry\n"
"cpu_trap_entry:\n"
"  addi sp, sp, -48\n"
"  sw t0, 0(sp)\n"
"  sw t1, 4(sp)\n"
"  sw t2, 8(sp)\n"
"  sw a0, 12(sp)\n"
"  sw a1, 16(sp)\n"
"  sw a2, 20(sp)\n"
"  sw a3, 24(sp)\n"
"  sw a4, 28(sp)\n"
"  sw a5, 32(sp)\n"
"  csrr t0, mcause\n"
"  csrr t1, mepc\n"
"  la t2, cpu_exc_cause\n"
"  sw t0, 0(t2)\n"
"  la t2, cpu_exc_mepc\n"
"  sw t1, 0(t2)\n"
"  la t2, cpu_exc_count\n"
"  lw a0, 0(t2)\n"
"  addi a0, a0, 1\n"
"  sw a0, 0(t2)\n"
"  bltz t0, 1f\n"
"  lhu a0, 0(t1)\n"
"  andi a0, a0, 3\n"
"  addi a1, zero, 3\n"
"  beq a0, a1, 3f\n"
"  addi t1, t1, 2\n"
"  j 4f\n"
"3:\n"
"  addi t1, t1, 4\n"
"4:\n"
"  csrw mepc, t1\n"
"  j 2f\n"
"1:\n"
"  la t2, cpu_int_count\n"
"  lw a0, 0(t2)\n"
"  addi a0, a0, 1\n"
"  sw a0, 0(t2)\n"
"  csrw mie, zero\n"
"2:\n"
"  lw t0, 0(sp)\n"
"  lw t1, 4(sp)\n"
"  lw t2, 8(sp)\n"
"  lw a0, 12(sp)\n"
"  lw a1, 16(sp)\n"
"  lw a2, 20(sp)\n"
"  lw a3, 24(sp)\n"
"  lw a4, 28(sp)\n"
"  lw a5, 32(sp)\n"
"  addi sp, sp, 48\n"
"  mret\n"
);

extern void cpu_trap_entry(void);

static void check_cause(unsigned int expect, const char *tag)
{
    if (cpu_exc_cause != expect) {
        printf("CPU EXC FAIL %s: cause=0x%x expect=0x%x\n",
               tag, cpu_exc_cause, expect);
        sim_fail();
    }
}

int test_start(void)
{
    unsigned int v;

    __asm__ volatile("csrw mtvec, %0" :: "r"((unsigned int)cpu_trap_entry));

    /* CSR read/write path */
    __asm__ volatile("csrw mscratch, %0" :: "r"(0x12345678));
    __asm__ volatile("csrr %0, mscratch" : "=r"(v));
    if (v != 0x12345678) {
        printf("CPU CSR FAIL: mscratch=0x%x\n", v);
        sim_fail();
    }

    /* ecall from M-mode -> cause 11 */
    __asm__ volatile("ecall");
    check_cause(11, "ecall");

    /* ebreak -> cause 3 */
    __asm__ volatile("ebreak");
    check_cause(3, "ebreak");

    /* illegal instruction -> cause 2 */
    __asm__ volatile(".word 0xffffffff");
    check_cause(2, "illegal");

    /* misaligned load -> cause 4 */
    __asm__ volatile(
        ".option push\n"
        ".option norvc\n"
        "lw t0, 1(%0)\n"
        ".option pop\n"
        :: "r"(0x20000000u) : "t0");
    check_cause(4, "load-misaligned");

    /* misaligned store -> cause 6 */
    __asm__ volatile(
        ".option push\n"
        ".option norvc\n"
        "sw t0, 1(%0)\n"
        ".option pop\n"
        :: "r"(0x20000000u) : "t0");
    check_cause(6, "store-misaligned");

    printf("cpu exception test successfully (count=%d)\n", cpu_exc_count);
    sim_end();
    return 0;
}
