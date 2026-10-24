# Wujian100 Open 芯片设计文档

> **文档版本**: v1.0  
> **生成日期**: 2026-04-04  
> **架构师**: Claude Code  
> **版权所有**: Alibaba Group Holding Limited

---

## 目录

1. [概述](#1-概述)
2. [模块层次结构](#2-模块层次结构)
3. [总线架构](#3-总线架构)
4. [CPU子系统](#4-cpu子系统)
5. [外设子系统](#5-外设子系统)
6. [地址映射](#6-地址映射)
7. [时钟复位架构](#7-时钟复位架构)
8. [验证环境](#8-验证环境)

---

## 1. 概述

### 1.1 芯片简介

Wujian100 Open 是阿里巴巴平头哥推出的开源 RISC-V MCU 芯片，采用 E902 CPU 核心，面向低功耗嵌入式应用场景。该芯片具有以下特点：

- **CPU 核心**: 平头哥 E902 RISC-V 处理器
- **总线架构**: AHB + APB 两级总线结构
- **丰富外设**: 定时器、PWM、USI、GPIO、RTC、WDT 等
- **低功耗设计**: 支持多种低功耗模式

### 1.2 RTL 文件结构

```
wujian100_open/soc/
├── wujian100_open_top.v    # 芯片顶层
├── core_top.v              # CPU 核心顶层
├── aou_top.v               # 时钟/复位/电源管理顶层
├── pdu_top.v               # 外设数据单元顶层
├── smu_top.v               # 存储管理单元顶层
├── ahb_matrix_top.v        # AHB 总线矩阵
├── apb0_sub_top.v          # APB0 子系统
├── apb1_sub_top.v          # APB1 子系统
├── ls_sub_top.v            # 低速总线子系统
├── E902_20191018.v         # E902 CPU 核心
├── dmac.v                  # DMA 控制器
├── gpio0.v                 # GPIO 控制器
├── pwm.v                   # PWM 控制器
├── rtc.v                   # 实时时钟
├── tim.v, tim1-7.v         # 通用定时器
├── usi0.v, usi1.v          # 通用串行接口
├── wdt.v                   # 看门狗定时器
├── clkgen.v                # 时钟生成模块
├── common.v                # 公共模块 (时钟门控、多路选择器)
├── matrix.v                # 总线矩阵
├── sms.v                   # 静态存储控制器
└── params/                 # 参数定义文件
    ├── apb0_params.v
    ├── apb1_params.v
    ├── timers_params.v
    └── wdt_params.v
```

### 1.3 设计规格概要

| 特性 | 规格 |
|------|------|
| CPU | E902 RISC-V (RV32EC) |
| 主频 | 最高 200MHz (EHS 时钟) |
| GPIO | 32 位双向 IO |
| 定时器 | 8 个通用定时器 (TIM0-7) |
| PWM | 12 通道 PWM 输出 |
| USI | 3 组通用串行接口 (SPI/I2C/UART) |
| DMA | 1 个 DMA 控制器 |
| RTC | 1 个实时时钟 |
| WDT | 1 个看门狗定时器 |
| 总线 | AHB (3主端口) + APB0/APB1 |

---

## 2. 模块层次结构

### 2.1 顶层模块层次图

```
wujian100_open_top
│
├── aou_top (Always-On Unit Top)
│   ├── clkgen           # 时钟生成模块
│   ├── pmu_dummy_top    # 电源管理单元
│   ├── gpio0            # GPIO 控制器
│   └── rtc0_sec_top     # 实时时钟
│
├── pdu_top (Peripheral Data Unit Top)
│   ├── core_top         # CPU 核心顶层
│   │   └── E902_20191018  # E902 CPU 核心
│   │
│   ├── ahb_matrix_top   # AHB 总线矩阵
│   │   ├── matrix       # 总线交叉开关
│   │   ├── dmac         # DMA 控制器
│   │   └── dummy modules
│   │
│   ├── smu_top          # 存储管理单元顶层
│   │   └── sms_top      # 静态存储控制器
│   │
│   ├── ls_sub_top       # 低速总线子系统
│   │   └── apb0/apb1 桥接
│   │
│   ├── apb0_sub_top     # APB0 子系统
│   │   ├── apb0         # APB0 总线
│   │   ├── tim0, tim2, tim4, tim6  # 定时器 (偶数)
│   │   ├── usi0, usi2   # USI 接口
│   │   ├── pwm          # PWM 控制器
│   │   └── wdt          # 看门狗定时器
│   │
│   └── apb1_sub_top     # APB1 子系统
│       ├── apb1         # APB1 总线
│       ├── tim1, tim3, tim5, tim7  # 定时器 (奇数)
│       └── usi1         # USI1 接口
│
└── PAD 接口
    ├── PAD_GPIO_0~31    # 32 位 GPIO
    ├── PAD_USI0/1/2     # USI 接口
    ├── PAD_PWM_CH0~11   # PWM 输出
    └── PAD_JTAG_TCLK/TMS # JTAG 调试接口
```

### 2.2 模块功能说明

#### 2.2.1 wujian100_open_top (芯片顶层)

芯片顶层模块，负责：
- 实例化各子系统模块
- PAD 信号连接
- 系统级信号路由

**主要端口**:
| 端口 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| PAD_GPIO_0~31 | inout | 1 | 32位通用IO |
| PAD_USI0/1/2_* | inout | - | 通用串行接口 |
| PAD_PWM_CH0~11 | inout | 1 | PWM输出通道 |
| PAD_JTAG_TCLK | inout | 1 | JTAG时钟 |
| PAD_JTAG_TMS | inout | 1 | JTAG模式选择 |
| PAD_MCURST | inout | 1 | 系统复位 |
| PIN_EHS | input | 1 | 高速时钟输入 |
| PIN_ELS | input | 1 | 低速时钟输入 |

#### 2.2.2 aou_top (Always-On Unit)

Always-On 单元，包含：
- 时钟生成与分发
- 电源管理
- GPIO 控制
- RTC 实时时钟

该模块在低功耗模式下保持运行，负责唤醒系统。

#### 2.2.3 pdu_top (Peripheral Data Unit)

外设数据单元，包含：
- CPU 核心
- AHB 总线矩阵
- 存储管理单元
- APB 子系统

#### 2.2.4 core_top (CPU 核心顶层)

CPU 核心顶层模块，封装 E902 CPU：
- AHB 总线接口 (m0/m1/m2)
- 中断管理
- 调试接口

---

## 3. 总线架构

### 3.1 总线拓扑结构

```
                    ┌─────────────────────────────────────┐
                    │           AHB Matrix                │
                    │         (ahb_matrix_top)            │
                    │                                     │
    ┌───────────────┤  m0    m1    m2    s0    s2-s4    ├───────────────┐
    │               │ IAHBL DAHBL  BIU  ISMC   SMC      │               │
    │               └─────────────────────────────────────┘               │
    │                       │     │     │     │     │                     │
    │                       │     │     │     │     └────┐                │
    │                       │     │     │     │          │                │
    │              ┌────────┘     │     │     │          │                │
    │              │              │     │     │          │                │
    ▼              ▼              │     │     │          ▼                │
┌───────┐      ┌───────┐         │     │     │      ┌───────┐            │
│ E902  │      │ DMAC  │         │     │     │      │ SMU   │            │
│ CPU   │      │       │         │     │     │      │(SMS)  │            │
└───────┘      └───────┘         │     │     │      └───────┘            │
    │                            │     │     │                           │
    │                            │     │     │                           │
    │                    ┌───────┘     │     └────────┐                  │
    │                    │             │              │                  │
    │                    ▼             ▼              ▼                  │
    │              ┌─────────────────────────────────────┐               │
    │              │         ls_sub_top                  │               │
    │              │     (Low-Speed Bus Subsystem)       │               │
    │              │                                     │               │
    │              │    s2(APB0)    s3(APB1)    s10      │               │
    │              └─────────────────────────────────────┘               │
    │                       │             │                              │
    │                       ▼             ▼                              │
    │              ┌─────────────┐ ┌─────────────┐                        │
    │              │  apb0_sub   │ │  apb1_sub   │                        │
    │              │    _top     │ │    _top     │                        │
    │              └─────────────┘ └─────────────┘                        │
    │                    │                │                              │
    └────────────────────┴────────────────┴──────────────────────────────┘
```

### 3.2 AHB 总线矩阵

AHB 总线矩阵实现多主多从交叉开关功能：

**主端口 (Masters)**:
| 端口 | 连接模块 | 功能 |
|------|----------|------|
| m0 (IAHBL) | CPU 取指总线 | 指令取指 |
| m1 (DAHBL) | CPU 数据总线 | 数据访问 |
| m2 (BIU) | CPU 系统总线 | 外部访问 |

**从端口 (Slaves)**:
| 端口 | 地址范围 | 连接模块 |
|------|----------|----------|
| s0 | - | ISMC (内部SRAM控制器) |
| s2 | - | APB0 子系统 |
| s3 | - | APB1 子系统 |
| s4 | - | SMC (外部存储控制器) |
| s10 | - | LSBUS (低速总线) |

### 3.3 APB 总线

#### APB0 子系统

APB0 总线连接高速外设，支持 16 个从设备：

| 从设备 | 地址范围 | 外设 |
|--------|----------|------|
| SLV0 | 0x50000000-0x500003FF | - |
| SLV1 | 0x50000400-0x500007FF | - |
| SLV2 | 0x50000800-0x50000BFF | - |
| SLV3 | 0x50000C00-0x50000FFF | - |
| SLV4 | 0x50028000-0x50028FFF | - |
| SLV5 | 0x50029000-0x50029FFF | - |
| SLV6 | 0x50004000-0x50007FFF | TIM0 |
| SLV7 | 0x50008000-0x5000BFFF | TIM2 |
| SLV8 | 0x5000C000-0x5000FFFF | TIM4 |
| SLV9 | 0x50010000-0x50013FFF | TIM6 |
| SLV10 | 0x50014000-0x50017FFF | - |
| SLV11 | 0x50018000-0x5001BFFF | USI0 |
| SLV12 | 0x5001C000-0x5001FFFF | USI2 |
| SLV13 | 0x50020000-0x50023FFF | PWM |
| SLV14 | 0x50024000-0x50027FFF | - |
| SLV15 | 0x50030000-0x50033FFF | WDT |

#### APB1 子系统

APB1 总线连接系统控制外设，支持 16 个从设备：

| 从设备 | 地址范围 | 外设 |
|--------|----------|------|
| SLV0 | 0x60000000-0x600003FF | - |
| SLV1 | 0x60000400-0x600007FF | - |
| SLV2 | 0x60000800-0x60000BFF | - |
| SLV3 | 0x60000C00-0x60000FFF | - |
| SLV4 | 0x60028000-0x6002BFFF | - |
| SLV5 | 0x60018000-0x6001BFFF | GPIO |
| SLV6 | 0x60020000-0x60023FFF | RTC |
| SLV6 | 0x60004000-0x60007FFF | TIM1 |
| SLV7 | 0x60008000-0x6000BFFF | TIM3 |
| SLV8 | 0x6000C000-0x6000FFFF | TIM5 |
| SLV9 | 0x60010000-0x60013FFF | TIM7 |
| SLV10 | 0x60014000-0x60017FFF | - |
| SLV11 | 0x6001C000-0x6001FFFF | USI1 |
| SLV12 | 0x60020000-0x60023FFF | - |
| SLV13 | 0x60024000-0x60027FFF | - |
| SLV14 | 0x6002C000-0x6002FFFF | - |
| SLV15 | 0x60030000-0x60033FFF | PMU |

---

## 4. CPU子系统

### 4.1 E902 CPU 核心

E902 是平头哥开发的低功耗 RISC-V 处理器核心，主要特性：

| 特性 | 规格 |
|------|------|
| 架构 | RISC-V RV32EC |
| 流水线 | 2级流水线 |
| 取指宽度 | 32位 |
| 数据宽度 | 32位 |
| 乘法器 | 支持 |
| 除法器 | 支持 |
| 中断 | 支持 CLIC/VIC |
| 调试 | 支持 JTAG 调试 |

### 4.2 CPU 总线接口

E902 提供 3 组 AHB 总线接口：

```verilog
// 取指总线 (m0 - IAHBL)
output [31:0] cpu_hmain0_m0_haddr    // 地址
output [2:0]  cpu_hmain0_m0_hburst   // 突发类型
output [3:0]  cpu_hmain0_m0_hprot    // 保护控制
output [2:0]  cpu_hmain0_m0_hsize    // 传输大小
output [1:0]  cpu_hmain0_m0_htrans   // 传输类型
output [31:0] cpu_hmain0_m0_hwdata   // 写数据
output        cpu_hmain0_m0_hwrite   // 读写指示
input  [31:0] hmain0_cpu_m0_hrdata   // 读数据
input         hmain0_cpu_m0_hready   // 传输就绪
input  [1:0]  hmain0_cpu_m0_hresp    // 传输响应

// 数据总线 (m1 - DAHBL)
// 信号定义类似 m0

// 系统总线 (m2 - BIU)
// 信号定义类似 m0
```

### 4.3 中断系统

CPU 支持 64 个外部中断输入：

| 中断号 | 来源 | 中断号 | 来源 |
|--------|------|--------|------|
| 7 | CTIM | 16 | GPIO |
| 18-19 | TIM0 | 20-21 | TIM1 |
| 22-23 | TIM2 | 24-25 | TIM3 |
| 25 | PWM | 26 | RTC |
| 27 | WDT | 28 | USI0 |
| 29 | USI1 | 30 | USI2 |
| 31 | PMU | 32 | DMAC0 |
| 34-35 | TIM4 | 36-37 | TIM5 |
| 38-39 | TIM6 | 40-41 | TIM7 |

---

## 5. 外设子系统

### 5.1 定时器 (TIM)

8 个通用定时器 (TIM0-7)，分布于 APB0 和 APB1 总线：

| 定时器 | 总线 | 地址范围 |
|--------|------|----------|
| TIM0 | APB0 | 0x50004000-0x50007FFF |
| TIM1 | APB1 | 0x60004000-0x60007FFF |
| TIM2 | APB0 | 0x50008000-0x5000BFFF |
| TIM3 | APB1 | 0x60008000-0x6000BFFF |
| TIM4 | APB0 | 0x5000C000-0x5000FFFF |
| TIM5 | APB1 | 0x6000C000-0x6000FFFF |
| TIM6 | APB0 | 0x50010000-0x50013FFF |
| TIM7 | APB1 | 0x60010000-0x60013FFF |

**功能特性**:
- 32位计数器
- 多种工作模式
- 中断支持
- ETB 触发输出

### 5.2 PWM 控制器

PWM 控制器位于 APB0 总线 (0x50020000-0x50023FFF)：

**功能特性**:
- 12 通道 PWM 输出
- 6 对互补输出
- 死区时间控制
- 故障检测输入
- 捕获功能

**寄存器定义**:
```verilog
`define pwmcfg_OFFSET          7'b0000000  // PWM 配置
`define pwmctl_OFFSET          7'b0001101  // PWM 控制
`define pwm01load_OFFSET       7'b0001110  // 计数器装载值
`define pwm01count_OFFSET      7'b0010001  // 当前计数值
`define pwm0cmp_OFFSET         7'b0010100  // 比较值
```

### 5.3 USI (通用串行接口)

3 组 USI 接口，支持 SPI/I2C/UART 三种模式：

| USI | 总线 | 地址范围 | 支持模式 |
|-----|------|----------|----------|
| USI0 | APB0 | 0x50018000-0x5001BFFF | SPI/I2C/UART |
| USI1 | APB1 | 0x6001C000-0x6001FFFF | SPI/I2C/UART |
| USI2 | APB0 | 0x5001C000-0x5001FFFF | SPI/I2C/UART |

**寄存器定义**:
```verilog
`define ADDR_USI_EN         12'h000   // USI 使能
`define ADDR_MODE_SEL       12'h004   // 模式选择
`define ADDR_TX_FIFO        12'h008   // 发送 FIFO
`define ADDR_RX_FIFO        12'h008   // 接收 FIFO
`define ADDR_UART_CTRL      12'h018   // UART 控制
`define ADDR_I2C_MODE       12'h020   // I2C 模式
`define ADDR_SPI_MODE       12'h040   // SPI 模式
`define ADDR_INTR_CTRL      12'h04C   // 中断控制
`define ADDR_DMA_CTRL       12'h064   // DMA 控制
```

### 5.4 GPIO 控制器

32 位 GPIO 控制器，位于 APB1 总线：

**功能特性**:
- 32 个双向 GPIO
- 可配置输入/输出方向
- 中断检测 (电平/边沿)
- 上拉/下拉控制

### 5.5 看门狗定时器 (WDT)

看门狗定时器位于 APB0 总线 (0x50030000-0x50033FFF)：

**功能特性**:
- 32位计数器
- 可配置超时周期
- 系统复位输出
- 窗口看门狗模式

### 5.6 实时时钟 (RTC)

RTC 位于 APB1 总线 (0x60020000-0x60023FFF)：

**功能特性**:
- 秒级计数器
- 闹钟功能
- 外部时钟输入
- 低功耗运行

### 5.7 DMA 控制器 (DMAC)

DMA 控制器连接到 AHB 总线：

**功能特性**:
- 多通道 DMA
- 内存到内存传输
- 外设到内存传输
- 链式传输

---

## 6. 地址映射

### 6.1 系统地址映射

```
地址范围                大小      目标模块
─────────────────────────────────────────────
0x00000000-0x1FFFFFFF   512MB    内部 SRAM (ISMC)
0x20000000-0x3FFFFFFF   512MB    外部存储 (SMC)
0x40000000-0x4FFFFFFF   256MB    保留
0x50000000-0x50033FFF    208KB   APB0 外设
0x60000000-0x60033FFF    208KB   APB1 外设
0x70000000-0xFFFFFFFF   1.75GB   保留
```

### 6.2 APB0 地址映射详表

```
基地址          末地址          大小    外设
─────────────────────────────────────────────
0x50000000     0x500003FF     1KB     SLV0 (保留)
0x50000400     0x500007FF     1KB     SLV1 (保留)
0x50000800     0x50000BFF     1KB     SLV2 (保留)
0x50000C00     0x50000FFF     1KB     SLV3 (保留)
0x50004000     0x50007FFF     16KB    TIM0
0x50008000     0x5000BFFF     16KB    TIM2
0x5000C000     0x5000FFFF     16KB    TIM4
0x50010000     0x50013FFF     16KB    TIM6
0x50018000     0x5001BFFF     16KB    USI0
0x5001C000     0x5001FFFF     16KB    USI2
0x50020000     0x50023FFF     16KB    PWM
0x50028000     0x50028FFF     4KB     SLV4 (保留)
0x50029000     0x50029FFF     4KB     SLV5 (保留)
0x50030000     0x50033FFF     16KB    WDT
```

### 6.3 APB1 地址映射详表

```
基地址          末地址          大小    外设
─────────────────────────────────────────────
0x60000000     0x600003FF     1KB     SLV0 (保留)
0x60000400     0x600007FF     1KB     SLV1 (保留)
0x60000800     0x60000BFF     1KB     SLV2 (保留)
0x60000C00     0x60000FFF     1KB     SLV3 (保留)
0x60004000     0x60007FFF     16KB    TIM1
0x60008000     0x6000BFFF     16KB    TIM3
0x6000C000     0x6000FFFF     16KB    TIM5
0x60010000     0x60013FFF     16KB    TIM7
0x60018000     0x6001BFFF     16KB    GPIO
0x6001C000     0x6001FFFF     16KB    USI1
0x60020000     0x60023FFF     16KB    RTC
0x60028000     0x6002BFFF     16KB    SLV4 (保留)
0x60030000     0x60033FFF     16KB    PMU
```

---

## 7. 时钟复位架构

### 7.1 时钟系统

#### 时钟源

| 时钟源 | 频率 | 用途 |
|--------|------|------|
| EHS (PIN_EHS) | 最高 200MHz | 高速系统时钟 |
| ELS (PIN_ELS) | 32.768kHz | 低速时钟/RTC |
| JTAG_TCLK | - | JTAG 调试时钟 |

#### 时钟分发

```
                    ┌──────────────┐
    PIN_EHS ───────►│              │
                    │   clkgen     │───► pll_cpu_clk (CPU)
                    │              │
    PIN_ELS ───────►│              │───► pmu_apb0_s3clk (APB0)
                    │              │
                    │              │───► pmu_apb1_s3clk (APB1)
                    │              │
                    │              │───► pmu_smc_hclk (SMC)
                    │              │
                    │              │───► pmu_dmac0_hclk (DMAC)
                    └──────────────┘
```

#### 时钟门控

系统支持细粒度时钟门控：

```verilog
// 时钟门控单元 (common.v)
module gated_clk_cell(
    input  clk_in,          // 输入时钟
    input  global_en,       // 全局使能
    input  module_en,       // 模块使能
    input  local_en,        // 本地使能
    input  external_en,     // 外部使能
    input  pad_yy_test_mode,// 测试模式
    input  pad_yy_gate_clk_en_b,
    output clk_out          // 门控后时钟
);
```

### 7.2 复位系统

#### 复位源

| 复位源 | 信号 | 作用范围 |
|--------|------|----------|
| 外部复位 | PAD_MCURST | 全局复位 |
| 看门狗复位 | wdt_pmu_rst_b | 系统复位 |
| JTAG 复位 | pad_had_rst_b | 调试复位 |

#### 复位分发

```
                    ┌──────────────┐
    PAD_MCURST ────►│              │
                    │  aou_top     │───► pad_core_rst_b (CPU)
    wdt_pmu_rst_b ─►│  (PMU)       │
                    │              │───► pmu_apb0_s3rst_b (APB0)
                    │              │
                    │              │───► pmu_apb1_s3rst_b (APB1)
                    │              │
                    │              │───► pmu_hmain0_hrst_b (AHB)
                    └──────────────┘
```

---

## 8. 验证环境

### 8.1 验证目录结构

```
dv/simulation/verif_env/soc/
├── soc_top/              # SOC 顶层验证
│   ├── env/              # UVM 环境
│   │   └── soc_top_env_pkg.sv
│   ├── sequences/        # 测试序列
│   │   └── intr_sequence/
│   └── tb_top/           # 顶层测试平台
│       ├── tb_top.sv     # 顶层 TB
│       └── soc_top_include/
│
├── apb0/                 # APB0 子系统验证
├── apb1/                 # APB1 子系统验证
├── ahb_hs/               # AHB 高速总线验证
├── ahb_ls/               # AHB 低速总线验证
├── gate_sim/             # 门级仿真
├── top_sim/              # 顶层仿真
│
├── common/               # 公共组件
│   └── uvc/              # UVM VIP
│       ├── ahb/          # AHB VIP
│       ├── clock_if.sv   # 时钟接口
│       ├── reset_if.sv   # 复位接口
│       └── intr_if.sv    # 中断接口
│
└── Makefile              # 编译脚本
```

### 8.2 UVM 测试平台

#### 顶层 TB 结构

```systemverilog
module tb_top();
    // 时钟复位生成
    reg i_ext_pad_clkmux_ehs_clk;  // EHS 时钟
    reg i_ext_pad_clkmux_els_clk;  // ELS 时钟
    reg i_ext_pad_rstgen_i_mcurst; // 复位
    reg jtag_clk;                   // JTAG 时钟
    
    // DUT 实例化
    wujian100_open_top dut (...);
    
    // UVM 测试启动
    initial begin
        run_test();
    end
endmodule
```

#### 验证组件

| 组件 | 文件 | 功能 |
|------|------|------|
| AHB Agent | ahb_pkg.sv | AHB 总线功能验证 |
| Clock Interface | clock_if.sv | 时钟生成控制 |
| Reset Interface | reset_if.sv | 复位序列控制 |
| Interrupt Interface | intr_if.sv | 中断监控 |

### 8.3 仿真运行

#### 编译命令

```bash
# 设置工具链
source /eda_tools/synopsys/.bashrc.synopsys

# 编译仿真
cd dv/simulation/verif_env/soc
make clean
make comp
make run
```

#### 波形查看

```bash
# 生成 FSDB 波形
make FSDB=1

# 查看 Verdi
verdi -ssf tb.fsdb
```

### 8.4 验证配置

测试平台支持多种验证配置：

```systemverilog
// 子系统验证宏定义
`define USE_APB0      // APB0 子系统验证
`define USE_APB1      // APB1 子系统验证
`define USE_AHB_HS    // AHB 高速总线验证
`define USE_AHB_LS    // AHB 低速总线验证
`define USE_GATE_SIM  // 门级仿真
`define USE_TOP_SIM   // 顶层仿真
```

---

## 附录 A: 参考文档

1. Wujian100 Open Userguide v1.0 (doc/wujian100_open Userguide v1.0.docx)
2. E902 CPU 用户手册 (平头哥官方文档)
3. AMBA AHB/APB 协议规范 (ARM)

---

## 附录 B: 缩略语

| 缩写 | 全称 | 中文 |
|------|------|------|
| AHB | Advanced High-performance Bus | 高级高性能总线 |
| APB | Advanced Peripheral Bus | 高级外设总线 |
| CPU | Central Processing Unit | 中央处理器 |
| DMA | Direct Memory Access | 直接存储器访问 |
| GPIO | General Purpose Input/Output | 通用输入输出 |
| PWM | Pulse Width Modulation | 脉冲宽度调制 |
| RTC | Real-Time Clock | 实时时钟 |
| USI | Universal Serial Interface | 通用串行接口 |
| WDT | Watchdog Timer | 看门狗定时器 |
| SMU | Storage Management Unit | 存储管理单元 |
| PMU | Power Management Unit | 电源管理单元 |
| ISMC | Internal SRAM Controller | 内部SRAM控制器 |
| SMC | Storage Memory Controller | 存储控制器 |

---

*本文档由 Claude Code 自动生成*