# Wujian100 Open 验证环境文档

> **文档版本**: v2.6  
> **更新日期**: 2026-10-24  
> **适用环境**: `verify/` 重构环境  
> **仿真工作目录**: `verify/st/sim`  
> **版权所有**: Alibaba Group Holding Limited

> **当前状态**：20 条回归 20/20 PASS（随机种子多轮），编译 mode 3 个（`soc_test`/`nocpu`/`struct`）。激励由 tc 在运行时驱动（含新增 `stim=io` pad 翻转）。覆盖率口径：**SoC 顶层 IO（100%）+ 顶层块接口（waive 后端口 71.43% / bit 68.17%）**；功能 91.67%、断言 100%。详见 8.5 与 `doc/wujian_verification_report.md`。
>
> **变更历史与调试过程**：见 [`doc/debug.log`](debug.log)。包含环境迁移、WDT 自复位根因、并行 FSDB 冲突、mode 合并、运行时激励迁移的完整证据链。

---

## 目录

1. [概述](#1-概述)
2. [环境与目录结构](#2-环境与目录结构)
3. [UVM 验证框架](#3-uvm-验证框架)
4. [验证组件详解](#4-验证组件详解)
5. [测试用例开发](#5-测试用例开发)
6. [C 用例编译与启动流程](#6-c-用例编译与启动流程)
7. [仿真执行流程](#7-仿真执行流程)
8. [覆盖率策略](#8-覆盖率策略)
9. [回归测试](#9-回归测试)
10. [附录 A: DPI-C 接口](#附录-a-dpi-c-接口)
11. [附录 B: 当前限制与已知问题](#附录-b-当前限制与已知问题)
12. [附录 C: 参考文档](#附录-c-参考文档)

---

## 1. 概述

### 1.1 验证环境简介

Wujian100 Open 验证环境基于 UVM 1.2 框架构建，采用层次化验证架构，支持 SOC 顶层验证和子系统集成验证。主要特点：

- **验证框架**: UVM 1.2
- **仿真工具**: Synopsys VCS + Verdi
- **总线协议**: AHB VIP（开源 UVM AHB agent）
- **测试方式**: C 语言测试用例（CPU 驱动）+ UVM 测试序列（AHB VIP 驱动）
- **DPI 集成**: 支持 C 语言直接调用仿真任务
- **编译方式**: 单一 Makefile，变量控制软件用例、UVM 用例、模式、种子、波形和覆盖率

### 1.2 快速开始

```bash
# 1. 加载 EDA 工具环境
source /eda_tools/synopsys/.bashrc.synopsys

# 2. 设置工程环境变量（PROJ_HOME / TOOL_PATH）
cd /home/IC_verify/project/claude_prj/prj2_wujian/wujian100_uvm/verify/st/sim
source ../../dv.cshrc

# 3. 默认冒烟：CPU 运行 timer C 用例
make all

# 4. AHB VIP 冒烟：VIP 替代 CPU，驱动 Timer
make all mode=nocpu tc=soc_top_smoke_test
```

判定标准：

- 日志中出现 `Hello Friend!` 和 `timer test successfully`
- 日志中出现 `**********UVM TEST PASSED*********`
- UVM Report Summary 中 `UVM_ERROR : 0`、`UVM_FATAL : 0`

### 1.3 验证层次架构

```
                        ┌─────────────────────────────────────┐
                        │          SOC_TOP 验证环境           │
                        │    (soc_top_env, soc_top_test)      │
                        └─────────────────────────────────────┘
                                          │
            ┌─────────────────────────────┼─────────────────────────────┐
            │                             │                             │
            ▼                             ▼                             ▼
    ┌───────────────┐           ┌───────────────┐           ┌───────────────┐
    │   APB0 验证   │           │   APB1 验证   │           │   AHB 验证    │
    │ (apb0_subsys) │           │ (apb1_subsys) │           │ (ahb_subsys)  │
    └───────────────┘           └───────────────┘           └───────────────┘
```

当前环境已迁移 **SOC_TOP 层**（CPU 驱动 + AHB VIP 驱动）以及 APB0/APB1/TOP_SIM/AHB/GATE 子系统 TB 结构；AHB/GATE 为占位结构，仓库无网表/SDF（详见附录 B）。

---

## 2. 环境与目录结构

### 2.1 环境变量

`verify/dv.cshrc`：

```bash
export TOOL_PATH=/eda_tools/riscv-toolchain
export PROJ_HOME=$(pwd | sed -e 's/^\(.*\)\/verify\>.*/\1/')
echo $TOOL_PATH
echo $PROJ_HOME
```

| 变量 | 取值 | 用途 |
|------|------|------|
| `TOOL_PATH` | `/eda_tools/riscv-toolchain` | RISC-V 交叉编译器根目录 |
| `PROJ_HOME` | 仓库根目录 `.../wujian100_uvm` | 所有 filelist、脚本、firmware 路径的基准 |
| `VCS_HOME` / `VERDI_HOME` / `UVM_HOME` | 由 `/eda_tools/synopsys/.bashrc.synopsys` 设置 | VCS、Verdi、UVM 1.2 |

注意：`PROJ_HOME` 依赖当前路径中包含 `/verify`。请在 `verify` 目录或其任意子目录下执行 `source dv.cshrc`。

### 2.2 目录结构

```
wujian100_uvm/
├── wujian100_open/                 # RTL 子仓库
│   └── soc/                        # wujian100_open_top 及外设 RTL
│
├── verify/                         # 重构后的验证环境根目录
│   ├── dv.cshrc                    # 环境变量
│   ├── firmware_ksim/              # 固件编译环境
│   │   ├── lib/
│   │   │   ├── clib/               # C 运行库
│   │   │   ├── newlib_wrap/        # newlib 封装
│   │   │   ├── Makefile            # 固件编译 Makefile
│   │   │   ├── crt0.s              # 启动代码
│   │   │   └── linker.lcf          # 链接脚本
│   │   └── tools/Srec2vmem.py      # SREC -> test.pat 转换
│   │
│   └── st/                         # 验证 testbench（SystemVerilog）
│       ├── tb/                     # 子系统 TB 桥接与 C 用例激励
│       │   ├── apb0/               # PWM / USI / WDT
│       │   ├── apb1/               # GPIO / RTC / PMU
│       │   ├── top_sim/            # ADDR_MAP / HAD
│       │   ├── ahb_hs/             # AHB_HS / DMA（结构占位）
│       │   ├── ahb_ls/             # AHB_LS（结构占位）
│       │   └── gate_sim/           # GATE / SDF（结构占位，无网表/SDF）
│       ├── cfg/
│       │   ├── rtl.f               # RTL filelist（活动）
│       │   ├── tb.f                # TB filelist（活动）
│       │   └── bench.f             # 旧 filelist，未使用
│       ├── env/
│       │   ├── ahb/                # AHB VIP
│       │   │   └── vutils_pkg/     # VIP 公共库
│       │   ├── clock_if.sv
│       │   ├── reset_if.sv
│       │   ├── intr_if.sv
│       │   ├── top_cfg.sv
│       │   ├── soc_top_env_pkg.sv
│       │   ├── soc_top_env_config.svh
│       │   ├── soc_top_env.svh
│       │   ├── soc_top_v_sequencer.svh
│       │   └── soc_top_coverage.svh
│       ├── th/                     # testbench top
│       │   ├── tb_top.sv
│       │   ├── soc_top_env_define.sv
│       │   └── soc_top_include/    # 接口实例化、绑定、程序加载等
│       ├── tc/                     # 测试用例与序列
│       │   ├── tc_list.sv
│       │   ├── soc_top_test_base.svh
│       │   ├── soc_top_test_lib.svh
│       │   ├── soc_top_reg_test.svh
│       │   └── seq/
│       │       ├── seq_list.sv
│       │       ├── soc_top_v_sequence_base.svh
│       │       ├── soc_top_v_sequence.svh
│       │       └── intr_sequence/
│       ├── c_case/                 # C 测试用例
│       │   ├── timer/  pwm/  gpio/  rtc/  wdt/  dma/
│       │   ├── usi_uart/  usi_spi/  usi_i2c/
│       │   ├── addr_map/  had_soc/
│       ├── script/
│       │   ├── make_hex            # C 用例编译脚本
│       │   └── make_hex_for_vip    # VIP DPI 共享库编译脚本
│       │
│       ├── sim/                    # 仿真工作目录
│       │   ├── Makefile            # 统一仿真入口
│       │   ├── run.tcl             # UCLI 运行脚本（波形、run 10ms）
│       │   ├── cm.cfg              # 代码/功能覆盖率层次配置
│       │   ├── cm_assert.cfg       # 断言覆盖率层次配置
│       │   ├── regress.cfg         # 回归配置（jobs=4，并行）
│       │   ├── case.lst            # 18 条回归列表（15 C + VIP + 2 结构冒烟）
│       │   └── out/<mode>/         # 编译产物与报告
│       │
│       └── soc_top/                # 旧结构副本，未参与编译（保留参考）
│
└── doc/
    └── wujian_verify.md            # 本文档
```

**活动文件与遗留文件的区别**：

| 路径 | 状态 | 说明 |
|------|------|------|
| `verify/st/cfg/tb.f` | 活动 | Makefile 使用 `-f ../cfg/tb.f` |
| `verify/st/cfg/rtl.f` | 活动 | Makefile 使用 `-f ../cfg/rtl.f` |
| `verify/st/tb/` | 活动 | 子系统 TB 桥接与激励，由 `tb_top.sv` 的宏 include |
| `verify/st/cfg/bench.f` | 未使用 | 内容指向旧 `dv/` 路径 |
| `verify/st/soc_top/` | 未使用 | 旧目录副本，调试时不要修改 |
| `dv/simulation/verif_env/soc` | 旧环境 | 仅作参考，不再作为调试入口 |

### 2.3 编译文件列表

`verify/st/cfg/rtl.f`：RTL 全部来自 `wujian100_open/soc`。

```text
+incdir+${PROJ_HOME}/wujian100_open/soc/params
${PROJ_HOME}/wujian100_open/soc/ahb_matrix_top.v
${PROJ_HOME}/wujian100_open/soc/wujian100_open_top.v
...
${PROJ_HOME}/wujian100_open/soc/sim_lib/fpga_spram.v
```

`verify/st/cfg/tb.f`：

```text
$PROJ_HOME/verify/st/th/soc_top_env_define.sv

+incdir+$PROJ_HOME/verify/st/env
+incdir+$PROJ_HOME/verify/st/env/ahb
+incdir+$PROJ_HOME/verify/st/env/ahb/vutils_pkg
+incdir+$PROJ_HOME/verify/st/tc
+incdir+$PROJ_HOME/verify/st/tc/seq
+incdir+$PROJ_HOME/verify/st/tc/seq/intr_sequence
+incdir+$PROJ_HOME/verify/st/th
+incdir+$PROJ_HOME/verify/st/th/soc_top_include

+incdir+$PROJ_HOME/verify/st/tb/apb0
+incdir+$PROJ_HOME/verify/st/tb/apb1
+incdir+$PROJ_HOME/verify/st/tb/top_sim

$PROJ_HOME/verify/st/env/ahb/vutils_pkg/vutils_pkg.sv
$PROJ_HOME/verify/st/env/ahb/ahb_if.sv
$PROJ_HOME/verify/st/env/ahb/ahb_pkg.sv
$PROJ_HOME/verify/st/env/clock_if.sv
$PROJ_HOME/verify/st/env/intr_if.sv
$PROJ_HOME/verify/st/env/reset_if.sv
$PROJ_HOME/verify/st/env/soc_top_env_pkg.sv
$PROJ_HOME/verify/st/th/tb_top.sv
```

编译顺序要求：`vutils_pkg` → `ahb_if` → `ahb_pkg` → 其它接口 → `soc_top_env_pkg` → `tb_top`。

---

## 3. UVM 验证框架

### 3.1 环境包 (soc_top_env_pkg.sv)

```systemverilog
package soc_top_env_pkg;
  import uvm_pkg::*;
  import ahb_pkg::*;

  `include "soc_top_env_config.svh"
  `include "soc_top_v_sequencer.svh"
  `include "soc_top_coverage.svh"
  `include "soc_top_env.svh"
endpackage
```

文件位置：`verify/st/env/`。

### 3.2 环境配置类 (soc_top_env_config.svh)

```systemverilog
class soc_top_env_config extends uvm_object;
  `uvm_object_utils(soc_top_env_config)

  // 虚拟接口（与 th/soc_top_include/soc_top_itf_inst.sv 中的实例对应）
  virtual clock_if#(300,0) ehs_clk;      // 高速时钟 300MHz
  virtual clock_if#(200,0) els_clk;      // 低速时钟 200MHz
  virtual clock_if#(100,0) jtag_clk;     // JTAG 时钟 100MHz
  virtual reset_if#(20000) pad_rst;      // 复位，20000ns 后释放

  // 配置开关
  bit has_functional_coverage = 1;
  bit has_soc_top_vsqr = 1;
  bit has_ahb_agent = 1;

  // AHB 配置
  ahb_cfg ahb_master_cfg;
  ahb_cfg ahb_slave_cfg;

  extern virtual function config_env(string name="SOC_TOP");
endclass
```

`config_env()` 从 `uvm_resource_db` 的 `interface_pool` 中按名字 `SOC_TOP_pad_rst` 获取复位接口；时钟接口在 test base 的 `build_phase` 中获取。

### 3.3 环境类 (soc_top_env.svh)

```systemverilog
class soc_top_env extends uvm_env;
  `uvm_component_utils(soc_top_env)

  soc_top_env_config  env_cfg;
  ahb_environment     ahb_env;          // AHB VIP 环境
  soc_top_v_sequencer soc_top_vsqr;     // 虚拟序列器
  soc_top_coverage    cov;              // 功能覆盖率

  extern function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
endclass
```

`connect_phase` 中完成虚拟序列器握手：

```systemverilog
soc_top_vsqr.ahb_mst_sqr = ahb_env.mst_agent.sqr;
soc_top_vsqr.ahb_slv_sqr = ahb_env.slv_agent.sqr;
```

### 3.4 虚拟序列器 (soc_top_v_sequencer.svh)

```systemverilog
class soc_top_v_sequencer extends uvm_sequencer;
  `uvm_component_utils(soc_top_v_sequencer)

  ahb_sequencer ahb_mst_sqr;
  ahb_sequencer ahb_slv_sqr;
endclass
```

---

## 4. 验证组件详解

### 4.1 AHB VIP

位置：`verify/st/env/ahb/`，公共库 `verify/st/env/ahb/vutils_pkg/`。

```text
env/ahb/
├── ahb_if.sv             # AHB 接口 + modport
├── ahb_pkg.sv            # package，含 DPI 导出与各组件 include
├── ahb_types.svh
├── ahb_cfg.svh
├── ahb_seq_item.svh
├── ahb_driver.svh
├── ahb_monitor.svh
├── ahb_sequencer.svh
├── ahb_agent.svh
├── ahb_base_seq.svh
├── ahb_mst_rand_seq.svh
├── ahb_slv_resp_seq.svh
└── ahb_env.svh
```

`ahb_pkg.sv` 中的 DPI 接口：

```systemverilog
package ahb_pkg;
  import uvm_pkg::*;
  import vutils_pkg::*;

  import "DPI-C" context task test_start();

  export "DPI-C" mem_write32_ = task mem_write32_;
  export "DPI-C" mem_read32_  = task mem_read32_ ;
  export "DPI-C" cpu_delay    = task delay_time  ;
  export "DPI-C" sim_fail     = function sim_fail;
  export "DPI-C" sim_end      = function sim_end ;
endpackage
```

注意：`mem_write32_` / `mem_read32_` 内部转发到全局句柄 `core`（`ahb_master_run_with_c_sequence`），VIP smoke 序列直接调用这两个 task 产生 AHB 读写。

> SOC 顶层约定：`ahb_env.slv_agent` 通过 `slv_agent_active=0` 配置为 `UVM_PASSIVE`，仅作 monitor，避免与 DUT 同时驱动 `hrdata/hready/hresp`；master driver 在数据相位 `wait_ready()` 之后才采样 `hrdata`（v2.1 修复）。CPU 模式下 master agent 也设为 passive，AHB 接口接 CPU m2 总线，供 monitor、功能覆盖率和断言使用；VIP 模式下 master 为 active。

### 4.2 时钟接口 (clock_if.sv)

```systemverilog
interface clock_if #(parameter CLK_FREQ=100, parameter START_PHASE=0)();
  bit CLOCK;
  bit gate_en = 1'b1;
  real half_cycle;

  initial begin
    CLOCK = 0;
    half_cycle = 1000.000/CLK_FREQ/2.000;
    fork
      begin
        #(start_phase*1.0ns);
        CLOCK = ~CLOCK;
        forever #(half_cycle*1.0ns) CLOCK = ~CLOCK;
      end
      // 频率/门控打印线程（略）
    join
  end
endinterface
```

`tb_top` 中使用 `soc_top_ehs_clk`（300MHz）、`soc_top_els_clk`（200MHz）、`soc_top_jtag_clk`（100MHz）。

### 4.3 复位接口 (reset_if.sv)

```systemverilog
interface reset_if #(parameter RESET_DELAY=100)(input clk, input rst_n);
  bit RESET;

  initial begin
    RESET = 0;
    repeat(2) @(posedge clk);
    RESET = 1;
    repeat(2) @(posedge clk);
    RESET = 0;
    #(RESET_DELAY*1.0ns) RESET = 1;
  end

  task wait_for_reset_leave();
    @(posedge clk);
    if(!rst_n) @(posedge rst_n);
  endtask
endinterface
```

复位实例为 `soc_top_pad_rst`，`RESET_DELAY=20000`，直接驱动 `PI_SOC_RST_B` / `PAD_MCURST`。

### 4.4 中断接口 (intr_if.sv)

```systemverilog
interface intr_if(input clk, input rst_n);
  logic[63:0] IRQ;

  task wait_for_interrupt_0(); @(posedge IRQ[0]); endtask
  task wait_for_interrupt_1(); @(posedge IRQ[1]); endtask
  // ... 0~63

  function bit is_interrupt_0_cleared();
    return (IRQ[0] == 0);
  endfunction
endinterface
```

### 4.5 接口实例化与绑定

`verify/st/th/soc_top_include/soc_top_itf_inst.sv`：

```systemverilog
clock_if #(300, 0) soc_top_ehs_clk();
clock_if #(200, 0) soc_top_els_clk();
clock_if #(100, 0) soc_top_jtag_clk();

reset_if #(20000) soc_top_pad_rst(
  .clk(soc_top_ehs_clk.CLOCK), .rst_n(soc_top_pad_rst.RESET));

ahb_if soc_top_ahb_vif(
  `HIER_SOC_TOP.x_cpu_top.pad_core_clk,
  `HIER_SOC_TOP.x_cpu_top.pad_core_rst_b);
```

`verify/st/th/soc_top_include/soc_top_itf_config.sv` 通过名字把接口写入：

| 接口 | resource_db 名字 |
|------|------------------|
| 300MHz 时钟 | `SOC_TOP_ehs_clk` |
| 200MHz 时钟 | `SOC_TOP_els_clk` |
| 100MHz 时钟 | `SOC_TOP_jtag_clk` |
| 复位 | `SOC_TOP_pad_rst` |
| AHB vif | `uvm_config_db` 路径 `uvm_test_top.m_env.ahb_env.*` |

接口池名为 `interface_pool`，test base 和设备 config 按名字读取。

---

## 5. 测试用例开发

### 5.1 C 语言测试用例

位置：`verify/st/c_case/`。

| 用例 | 路径 | 说明 |
|------|------|------|
| timer | `timer/timer_test.c` | 定时器中断（默认） |
| pwm | `pwm/pwm_test.c` | PWM 输出 |
| gpio | `gpio/gpio_test.c` | GPIO 输入输出 |
| rtc | `rtc/rtc_test.c` | 实时时钟 |
| wdt | `wdt/wdt_test.c` | 看门狗 |
| dma | `dma/dma_test.c` | DMA 传输 |
| usi_uart | `usi_uart/usi_uart_test.c` | UART |
| usi_spi | `usi_spi/usi_spi_test.c` | SPI |
| usi_i2c | `usi_i2c/usi_i2c_test.c` | I2C |
| addr_map | `addr_map/map_test.c` | 地址映射 |
| had | `had_soc/e902_had_test.c` | HAD 调试 |

C 用例通过 `make sc=<路径>` 选择，例如：

```bash
make all sc=timer/timer_test.c
```

### 5.2 UVM 测试用例

位置：`verify/st/tc/`。

| UVM 用例 | 文件 | 用途 | 推荐命令 |
|----------|------|------|----------|
| `soc_top_for_c_case_test` | `soc_top_test_lib.svh` | CPU 执行 C 用例，等待 C 结束标志 | `make all` |
| `soc_top_smoke_test` | `soc_top_test_lib.svh` | AHB VIP 替代 CPU，驱动 Timer | `make all mode=nocpu tc=soc_top_smoke_test` |
| `soc_top_vip_run_with_c_test` | `soc_top_test_lib.svh` | AHB VIP + DPI 调用 C 用例 | 见 6.10 |
| `soc_top_reg_smoke_test` | `soc_top_reg_test.svh` | 寄存器 smoke（当前在 `tc_list.sv` 中被注释） | 按需启用 |

`tc/tc_list.sv` 决定参与编译的测试与序列：

```systemverilog
`include "seq_list.sv"
`include "soc_top_test_base.svh"
//`include "soc_top_reg_test.svh"
`include "soc_top_test_lib.svh"
```

### 5.3 测试基类与 UVM Phase

`soc_top_test_base` 在 `tc/soc_top_test_base.svh` 中实现，关键 phase：

```systemverilog
task soc_top_test_base::reset_phase(uvm_phase phase);
  super.reset_phase(phase);
  phase.raise_objection(this);
  clear_data_sram();          // 清空数据 SRAM
  phase.drop_objection(this);
endtask

task soc_top_test_base::post_reset_phase(uvm_phase phase);
  super.post_reset_phase(phase);
  phase.raise_objection(this);
  load_pgm();                 // 按 +PAT_FILE 加载 <case>.pat 到 ISRAM
  phase.drop_objection(this);
endtask
```

`run_phase` 中还注册了程序重载线程（`e902_reload_program`），用于运行中重新加载固件。

`final_phase` 的 PASS/FAIL 判定：

```systemverilog
err_num = server.get_severity_count(UVM_ERROR)
        + server.get_severity_count(UVM_FATAL);
if(!err_num) `uvm_info("UVM_CASE_PASS", "**********UVM TEST PASSED*********", UVM_NONE)
else         `uvm_info("UVM_CASE_FAIL", "**********UVM TEST FAILED*********", UVM_NONE)
```

**重要变化**：程序加载已从 `tb_top` 的 `initial` 块迁移到 UVM `reset_phase` / `post_reset_phase`，见 6.7 节。

### 5.4 冒烟虚拟序列

`tc/seq/soc_top_v_sequence.svh`：

```systemverilog
class soc_top_smoke_reg_sequence extends ahb_master_base_sequence;
  `uvm_object_utils(soc_top_smoke_reg_sequence)

  task body();
    int int_tim_flag=0;
    int int_tim_eoi=0;
    $display("Hello Friend!");
    mem_write32_(32'h50000008, 32'h2);       // 禁能 Timer1
    mem_write32_(32'h50000000, 32'h400);     // 设置计数值
    mem_write32_(32'h50000008, 32'h3);       // 使能 Timer1
    mem_read32_ (32'h50000010, int_tim_flag);
    while (int_tim_flag != 'h1) begin
      mem_read32_(32'h50000010, int_tim_flag);
    end
    mem_read32_(32'h5000000c, int_tim_eoi);  // 清中断
    $display("\ntimer test successfully");
  endtask
endclass

class soc_top_smoke_v_sequence extends soc_top_v_sequence_base;
  `uvm_object_utils(soc_top_smoke_v_sequence)

  task body();
    `ifdef USE_AHB_VIP_TO_REPLACE
      soc_top_smoke_reg_sequence reg_seq;
      `uvm_do_on(reg_seq, p_sequencer.ahb_mst_sqr)
    `endif
  endtask
endclass
```

注意：该序列只在定义 `USE_AHB_VIP_TO_REPLACE` 时生效，对应 `mode=nocpu`。

### 5.5 用例结果判定

- UVM 侧：`final_phase` 中 UVM_ERROR + UVM_FATAL 计数为 0 时打印 `UVM TEST PASSED`
- C 侧：C 用例调用 `sim_end()` 写 `0x20007c50` 两次 `0x2002`，`soc_top_for_c_case_test` 等到 `cpu_c_finish_e` 后判定通过；写两次 `0x1001` 为失败
- 两种判定需同时满足

---

## 6. C 用例编译与启动流程

### 6.1 编译流程概述

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  C 源文件   │────►│  交叉编译   │────►│  链接生成   │────►│  格式转换   │
│  (.c)       │     │  (.o)       │     │  (.elf)     │     │  (.pat)     │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                   │
                                                                   ▼
                                                          ┌─────────────┐
                                                          │  UVM 加载   │
                                                          │  (ISRAM)    │
                                                          └─────────────┘
```

### 6.2 编译脚本 (make_hex)

位置：`verify/st/script/make_hex`（Perl）。主要流程：

1. 解析 `sc` 参数（例如 `timer/timer_test.c`）
2. 在 `sim/<case>_code/` 下创建临时编译目录
3. 复制 `verify/st/c_case/<case>/` 中的 `.c` 文件
4. 复制 `verify/firmware_ksim/lib` 的 clib、newlib_wrap、`Makefile`、`crt0.s`、`linker.lcf`
5. 调用 `make all CPU=e902m ENDIAN_MODE=little-endian FILE=<case> `
6. 把生成的 `test.pat` 原子重命名为 `<case_make>.pat` 并放到 `sim/`（平行仿真时由 Makefile 复制到各 `RESULT_DIR`）

关键片段：

```perl
!system("cp $ENV{PROJ_HOME}/verify/firmware_ksim/lib/clib/*.h  .");
!system("cp $ENV{PROJ_HOME}/verify/firmware_ksim/lib/clib/*.c  .");
!system("cp $ENV{PROJ_HOME}/verify/firmware_ksim/lib/newlib_wrap/*.c .");

!system("cp $ENV{PROJ_HOME}/verify/firmware_ksim/lib/Makefile ./Makefile");
!system("cp $ENV{PROJ_HOME}/verify/firmware_ksim/lib/crt0.s ./crt0.s");
!system("cp $ENV{PROJ_HOME}/verify/firmware_ksim/lib/linker.lcf ./linker.lcf");

!system("make clean; make all CPU=e902m ENDIAN_MODE=little-endian FILE=$case_make HGPR=");

!system("cp test.pat $pat_tmp") or die "cant't copy $pat_tmp";
!system("mv $pat_tmp ../$pat_name") or die "cant't move $pat_name";
```

> **实现要点**：编译临时目录用 `<case>.c_code_<pid>/` 避免并行覆盖；`PAT_FILE` 由 `sc` 推导，`load_pgm()` 按 `+PAT_FILE` 加载。

### 6.3 编译工具链

`verify/firmware_ksim/lib/Makefile`：

```makefile
TOOL_EXTENSION = ${TOOL_PATH}/bin/riscv64-unknown-elf-
CC      = ${TOOL_EXTENSION}gcc
AS      = ${TOOL_EXTENSION}as
LINK    = ${TOOL_EXTENSION}ld
OBJDUMP = ${TOOL_EXTENSION}objdump
OBJCOPY = ${TOOL_EXTENSION}objcopy
CONVERT = ${PROJ_HOME}/verify/firmware_ksim/tools/Srec2vmem.py

ifeq ($(findstring e902m, ${CPU_M}), e902m)
    CFLAGS = -march=rv32emc -mabi=ilp32e
else
    CFLAGS = -march=rv32ec -mabi=ilp32e
endif

CFLAGS += -D${DEFSYM} -Wa,--defsym=${DEFSYM}=1
CFLAGS += -O3 -funroll-all-loops -fgcse-sm -finline-limit=500 \
          -fno-schedule-insns -ffunction-sections -fdata-sections
LINKFLAGS = -Tlinker.lcf -nostartfiles
LINKLIBS += $(LDFLAGS) -lc -lgcc
```

### 6.4 链接脚本 (linker.lcf)

```text
MEMORY
{
    MEM1(RWX)  : ORIGIN = 0x00000000,  LENGTH = 0x10000   # 指令 RAM
    RAND(RW)   : ORIGIN = 0x0000eff0,  LENGTH = 0x1000    # 数据区
}

__kernel_stack = 0x2000fff8;
__user_stack   = 0x2000fcf8;

ENTRY(__start)

SECTIONS {
    .text : { crt0.o (.text) *(.text*) *(.rodata*) } >MEM1
    .data : { *(.data*) } >MEM1
    .bss  : { *(.bss) *(COMMON) } >MEM1
}
```

### 6.5 启动代码 (crt0.s)

```asm
.text
.ifdef e902
    .global __start
__start:
    # 1. 初始化通用寄存器 x1-x15
    # 2. 设置内核栈 __kernel_stack 并清零栈空间
    # 3. 设置 mtvec -> __trap_handler
    # 4. jal test_start 进入 C 程序
__fail:
    li x4, 0x20007c50
    li x3, 0x1001
    sw x3, 0(x4)
    jal __fail
__exit:
    li x4, 0x20007c50
    li x3, 0x2002
    sw x3, 0(x4)
    jal __exit
__trap_handler:
    j __synchronous_exception
    j __asychronous_int
.endif
```

### 6.6 格式转换 (Srec2vmem.py)

```python
# SREC: S3150000000023004000C0460000C0460000C0460000C0
# test.pat:
# @00000000 40002300
# @00000001 000046c0
```

脚本位于 `verify/firmware_ksim/tools/Srec2vmem.py`，shebang 已改为 `#!/usr/bin/python3`。

### 6.7 程序加载（UVM Phase 版本）

`verify/st/th/soc_top_include/soc_top_program_download.sv` 中的旧 `initial` 块已注释，程序加载统一由 `verify/st/tc/soc_top_test_base.svh` 完成：

```systemverilog
task soc_top_test_base::clear_data_sram();
  for (int j = 0; j < 32'h4000; j++) begin
    tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_sms0_top.x_sms_sram.
      x_fpga_spram.x_fpga_byte3_spram.mem[j][7:0] = 8'h0;
    // byte2 / byte1 / byte0 同理
  end
endtask

task soc_top_test_base::load_pgm();
  reg [31:0] temp_mem[integer];
  reg [31:0] one_word;
  string pat_file;
  if (!$value$plusargs("PAT_FILE=%s", pat_file)) pat_file = "test.pat";
  $readmemh(pat_file, temp_mem);
  for (int k = 0; k < 32'h4000; k++) begin
    one_word = temp_mem[k];
    tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_isram_top.x_sms_sram.
      x_fpga_spram.x_fpga_byte3_spram.mem[k][7:0] = one_word[7:0];
    // byte2 / byte1 / byte0 同理
  end
endtask
```

时序：`reset_phase` 清数据 SRAM → `post_reset_phase` 按 `+PAT_FILE` 加载 `<case>.pat` → `run_phase` 等待 CPU 运行/重载事件。

### 6.8 Boot 流程

```
┌─────────────────────────────────────────────────────────────────────┐
│                          系统启动流程                                │
├─────────────────────────────────────────────────────────────────────┤
│  1. 复位阶段      reset_if 驱动 soc_top_pad_rst，PI_SOC_RST_B=0      │
│  2. 复位释放      RESET_DELAY=20000ns 后 RESET=1                     │
│  3. UVM reset     clear_data_sram() 清数据区                         │
│  4. UVM post_rst  load_pgm() 把 <case>.pat 写入 ISRAM (0x00000000)   │
│  5. CPU 启动      crt0.s: 初始化寄存器/栈/mtvec -> jal test_start     │
│  6. 主程序        C 用例执行，printf 通过 0x20007c50 写字符输出       │
│  7. 仿真结束      sim_end(): 写 0x2002 两次；sim_fail(): 0x1001 两次  │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.9 仿真控制接口

控制寄存器：`0x20007c50`。

| 写入值 | 含义 |
|--------|------|
| `0x1001`（连续两次） | 测试失败，触发 `cpu_c_finish_e` 携带 0x1001 |
| `0x2002`（连续两次） | 测试成功，触发 `cpu_c_finish_e` 携带 0x2002 |
| `0x3003`（连续两次） | 保存状态（当前流程未使用） |
| 其它值 | 低 8 位按字符输出（C `printf` 实现） |

实现位置：`verify/st/th/soc_top_include/busmnt.v`，监视 CPU 的 AHB 写事务。

C 库函数（firmware clib）：

```c
void sim_end()  { *(volatile uint32_t *)0x20007c50 = 0x2002;
                  *(volatile uint32_t *)0x20007c50 = 0x2002; }
void sim_fail() { *(volatile uint32_t *)0x20007c50 = 0x1001;
                  *(volatile uint32_t *)0x20007c50 = 0x1001; }
```

### 6.10 VIP DPI 模式（参考流程）

`verify/st/script/make_hex_for_vip` 把 C 用例编译成共享库：

```bash
cd verify/st/sim
../script/make_hex_for_vip timer/timer_test.c   # 生成 ../test_start.so
make all mode=nocpu tc=soc_top_vip_run_with_c_test udr="-sv_lib test_start"
```

对应 `run_phase` 中通过 `test_start()` 直接调用 C 函数，C 侧 `mem_write32_` 等通过 DPI 回调 AHB VIP。

> 该路径本次未做回归验证；使用前请确认 `test_start.so` 已生成在 `verify/st/sim/` 下。

---

## 7. 仿真执行流程

### 7.1 环境准备

```bash
source /eda_tools/synopsys/.bashrc.synopsys
cd /home/IC_verify/project/claude_prj/prj2_wujian/wujian100_uvm/verify/st/sim
source ../../dv.cshrc
```

### 7.2 常用命令

```bash
# 默认冒烟：CPU + timer C 用例
make all

# 只编译 C 固件
make sw_comp sc=timer/timer_test.c

# 只编译 RTL/TB
make compile

# 只运行（不重新进行 VCS 编译，但会重新编译 C 固件）
make sim

# 更换 C 用例
make all sc=gpio/gpio_test.c

# AHB VIP 冒烟
make all mode=nocpu tc=soc_top_smoke_test

# 子系统 C 用例：运行时选择 HW 激励（同一个 simv_soc_test）
make all mode=soc_test sc=gpio/gpio_test.c      stim=gpio
make all mode=soc_test sc=pwm/pwm_test.c        stim=pwm
make all mode=soc_test sc=usi_spi/usi_spi_test.c stim=spi
make all mode=soc_test sc=usi_i2c/usi_i2c_test.c stim=i2c
make all mode=soc_test sc=usi_uart/usi_uart_test.c stim=uart
make all mode=soc_test sc=addr_map/map_test.c   stim=map
# HAD/JTAG 也已迁入 tc
make all mode=soc_test sc=had_soc/e902_had_test.c stim=had

# VIP DPI 模式（先编译共享库，再运行）
../script/make_hex_for_vip timer/timer_test.c
make all mode=nocpu tc=soc_top_vip_run_with_c_test DPI=1

# 18 条回归（框架位于 ~/script/regression_v1.0）
python3 ~/script/regression_v1.0/regr_run.py -c regress.cfg -l case.lst

# 更换随机种子 / UVM 冗余度
make all seed=456 pl=UVM_HIGH

# 关闭波形、关闭覆盖率
make all wave=0 cov=0

# 生成覆盖率报告
make urg COV_RPT=1

# 清理（不删除 out/）
make clean

# 彻底清理（会删除 out/<mode>/，谨慎）
make distclean
```

### 7.3 Makefile 变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `tc` | `soc_top_for_c_case_test` | UVM 用例名 |
| `sc` | `timer/timer_test.c` | C 用例，相对 `verify/st/c_case/` |
| `mode` | `soc_test` | 仿真模式，决定宏和产物目录 `out/<mode>/` |
| `seed` | 随机（时间戳） | 随机种子；`seed=123` 可固定用于复现 |
| `stim` | 空 | 运行时 HW 激励：`gpio/pwm/spi/i2c/uart/map`，转成 `+HW_STIM` |
| `HDL_ACCESS` | 空 | 非空时编译加 `-debug_access+all`（`uvm_hdl_*` 需要） |
| `pl` | `UVM_MEDIUM` | UVM verbosity |
| `wave` | `1` | 1 生成 FSDB 波形；0 关闭 |
| `cov` | `1` | 1 打开代码覆盖率 |
| `RESULT_DIR` | `out/$(mode)` | 产物目录 |
| `SIMV_NAME` | `simv_$(mode)` | 可执行文件名 |
| `udc` | 空 | 用户追加编译选项 |
| `udr` | 空 | 用户追加运行选项 |
| `DPI` | `0` | 1 时运行参数追加 `-sv_lib ./test_start` |
| `PAT_FILE` | `$(basename $(notdir $(sc))).pat` | 由 `sc` 推导的固件文件名，运行参数传 `+PAT_FILE=$(RESULT_DIR)/$(PAT_FILE)` |
| `COV_ARGS` | 空 | 覆盖率选项覆盖 |
| `COV_RPT` | `0` | 1 时 `make urg` 生成报告 |
| `VCS_LOG` | `1` | 1 输出编译/仿真日志到 `RESULT_DIR` |

### 7.4 模式 (mode) 与宏

`mode` 通过关键字匹配追加 `+define+`：

| mode 关键字 | 追加宏 | 说明 |
|-------------|--------|------|
| `nocpu` | `USE_AHB_VIP_TO_REPLACE` | AHB VIP 替代 CPU（VIP 冒烟） |
| `gpio` | `USE_APB1+USE_APB1_GPIO` | GPIO 子系统 |
| `spi` | `USE_APB0+USE_APB0_USI+USI_SPI` | SPI |
| `i2c` | `USE_APB0+USE_APB0_USI+USI_I2C` | I2C |
| `uart` | `USE_APB0+USE_APB0_USI+USI_UART` | UART |
| `pwm` | `USE_APB0+USE_APB0_PWM` | PWM |
| `map` | `USE_TOP_SIM+USE_ADDR_MAP` | 地址映射 |
| `e902` | `USE_TOP_SIM+USE_HAD` | HAD 调试 |
| `ahb_hs` | `USE_AHB_HS+USE_SOC_DMA` | AHB_HS/DMA 结构冒烟（TB 占位） |
| `ahb_ls` | `USE_AHB_LS` | AHB_LS 结构冒烟（TB 占位） |
| `gate` | `USE_GATE_SIM+USE_SDF_SIM` | 门级结构冒烟（无网表/SDF，实际仍为 RTL） |
| `struct` | `USE_AHB_HS+USE_SOC_DMA+USE_GATE_SIM+USE_SDF_SIM` | AHB_HS/GATE 两条结构冒烟共用一次编译 |
| `all` | 上述宏合集（含 AHB/GATE） | 全部子系统宏 |

> **回归实际只编译 3 个 mode**：`soc_test`（CPU + 运行时激励）、`nocpu`（AHB VIP）、`struct`（空 TB 结构冒烟）。
>
> `gpio/pwm/spi/i2c/uart/map` 的激励已迁到 `tc/soc_top_stimulus.svh`，通过 `stim=<name>`（`+HW_STIM`）在运行时选择，不再需要对应的编译 mode。上表中这些 per-IP mode 仍保留，仅用于隔离调试。AHB/GATE 的 TB 是空占位，仓库无网表/SDF。

### 7.5 编译与运行参数

编译核心选项：

```makefile
VCS_OPTS += vcs -sverilog -full64 -kdb -DVCS -lca -ntb_opts uvm-1.2 \
            +vpi +lint=TFIPC,PCWM +vcs+lic+wait \
            +debug_region=cell+lib +vcs+initreg+random
COMPOPTS += -top tb_top -timescale=1ns/1ps
COMPOPTS += -o $(RESULT_DIR)/$(SIMV_NAME)
COMPOPTS += -f ../cfg/rtl.f -f ../cfg/tb.f
```

`wave=1` 时加 `-debug_access+all`，`wave=0` 时加 `-debug_pp`。

运行选项：

```makefile
SIMOPTS  = $(RESULT_DIR)/$(SIMV_NAME)
SIMOPTS += +UVM_TESTNAME=$(tc) +vcs+initreg+0
SIMOPTS += +UVM_VERBOSITY=$(pl) +ntb_random_seed=$(seed)
SIMOPTS += -ucli -i run.tcl +UVM_VERDI_TRACE="UVM_AWARE+HIER"
```

### 7.6 产物与波形

每次运行产物位于 `verify/st/sim/out/<mode>/`：

| 文件 | 说明 |
|------|------|
| `simv_<mode>` | 可执行仿真器 |
| `compile_<mode>.log` | 编译日志 |
| `<tc>_<seed>.log` | 运行日志（主判定文件） |
| `sim_<tc>_<seed>.fsdb` | 波形（wave=1） |
| `simv_<mode>.vdb/` | 覆盖率数据库（cov=1） |

`run.tcl`：

```tcl
set wave $env(wave)
fsdbDumpfile "./${RESULT_DIR}/sim_${tc}_${seed}.fsdb"
fsdbDumpvars 0 tb_top +mda +struct
run 10ms
quit
```

查看波形：

```bash
verdi -ssf out/soc_test/sim_soc_top_for_c_case_test_123.fsdb
verdi -ssf out/nocpu/sim_soc_top_smoke_test_123.fsdb
```

### 7.7 注意事项

1. `all: compile sim` 且 `sim: sw_comp`，因此 `make all` 只执行一次 C 编译。需要单独控制时可分开执行 `make sw_comp`、`make compile`、`make sim`。
2. `make clean` 只删除 `*log csrc *key`，不会删除 `out/`；需要重建产物时请手动指定新的 `RESULT_DIR` 或谨慎使用 `make distclean`。
3. `make sim` 不会触发编译，依赖已存在的 `out/<mode>/simv_<mode>`；修改 UVM/TB 或 `PAT_FILE` 逻辑后必须重新 `make compile` 或 `make all`。
4. 仿真结束时 `run.tcl` 执行 `run 10ms` 后 `quit`；UVM 用例正常结束时 `$finish` 会提前退出。
5. 默认工作目录必须是 `verify/st/sim`，因为 `run.tcl`、`cm.cfg`、`<case>.pat` 与 `RESULT_DIR` 均按相对路径读写。

---

## 8. 覆盖率策略

### 8.1 覆盖率开关

`sim/Makefile` 默认 `cov=1`：

```makefile
VCS_OPTS_COV = -lca -cm line+cond+fsm+branch+tgl+assert \
               -cm_name $(COV_DB_NAME) -cm_hier cm.cfg \
               -cm_assert_hier cm_assert.cfg
SIM_OPTS_COV = -cm line+cond+fsm+branch+tgl+assert \
               -cm_name $(COV_DB_NAME) -cm_hier cm.cfg \
               -cm_assert_hier cm_assert.cfg
```

`cm.cfg` 当前内容：

```text
+tree tb_top.dut
+tree tb_top.uvm_test_top.m_env.cov
+tree tb_top.soc_topahb_vif
-tree uvm_pkg
-tree tb_top.soc_toppad_rst
```

统计 DUT、功能覆盖率组件和 AHB 接口断言；排除 UVM 库内部断言与未使用的复位 helper 断言。

`cm_assert.cfg`：

```text
+tree tb_top.soc_topahb_vif
```

### 8.2 覆盖率数据库与报告

- 数据库：`out/<mode>/simv_<mode>.vdb/`，回归时为 `regress_results_<date>/<mode>/simv_<mode>.vdb/`
- 单模式报告：

```bash
make urg COV_RPT=1
# 等价于：
urg -dir out/soc_test/simv_soc_test.vdb \
    -report out/soc_test/simv_soc_test_cov_rpt
```

- 全量回归自动合并：`regress.cfg` 中 `coverage = true`、`urg_report = true`，`regr_run.py` 会把所有 mode 的 vdb 合并到
  `regress_results_<date>/coverage_report/`。

### 8.3 覆盖率结果（2026-10-24 覆盖率回归）

| 类型 | 目标 | 全 SoC 口径 | core+peripheral 口径 | 结论 |
|------|------|-------------|----------------------|------|
| 代码 line | > 90% | 35.31% | 69.76% | **未达标** |
| 代码 cond | > 90% | 21.98% | 44.23% | **未达标** |
| 代码 toggle | > 90% | 28.68% | 34.74% | **未达标** |
| 代码 branch | > 90% | 27.58% | 58.65% | **未达标** |
| 代码 FSM | > 90% | 2.06% | 22.49% | **未达标** |
| 功能覆盖 | > 85% | 88.89% | **91.67%** | 达标 |
| 断言覆盖 | > 95% | 100.00% | **100.00%** | 达标 |

- 全 SoC 口径：`cm.cfg` 未排除任何模块，含生成式 7×12 AHB 互连。
- core+peripheral 口径：`cm.cfg` 排除 `x_ahb_matrix_7_12_main`（生成式矩阵）、主总线 dummy 从设备与 `x_pmu_top`（dummy PMU）；**DMAC 保留**。
- 功能覆盖从 88.89% 提升到 91.67%：`cp_region` 12/12（含 `isram`）、`cx_kind_region` 24/24；剩余缺口是 `cp_busy` 2/4（`zero` 为死 bin、`high` 未命中）。

- 功能覆盖：`soc_top_coverage::ahb_cov`，覆盖读/写、地址区域（ISRAM/DSRAM/DMA/TIMER/WDT/PWM/USI/RTC/GPIO/USI1/DUMMY/OTHER）、size/resp/busy 及 kind×region 交叉；未覆盖 bin 为 `cp_region.isram`、`cp_busy.high` 和 2 个交叉 bin。
- 断言覆盖：AHB 接口上的 `a_no_x`、`a_hresp_okay` 与 4 个 cover property（read/write/wait/idle）全部命中；RTL 本身没有 SVA。
- 代码覆盖率未达标的主要原因：CPU 核 `cr_*` 模块、未使用的 timer/PWM 通道、DMA 描述符路径、PMU/CLIC 等大量逻辑未被现有 C 用例覆盖；这是全 SoC 级别的统计，不是单个外设模块的覆盖率。
- 数据来源：2026-10-24 覆盖率回归（`-j 1 --coverage --urg`，3 个 mode 合并），报告 `regress_results_20261024/coverage_report/dashboard.html`（组：`groups.html`，断言：`asserts.html`）。表中"全 SoC"为排除前一轮，"core+peripheral"为排除后最新一轮。

### 8.4 覆盖率缺口与收敛计划（2026-10-24）

**2026-10-24 收敛结果**
- 功能覆盖 **91.67%**（`cp_region` 12/12、`cx_kind_region` 24/24），已达标。
- 代码 line **66.55%**（core+peripheral 口径），较全 SoC 的 35.31% 更能反映验证目标，但距 90% 仍有差距。
- 剩余主要缺口：CPU 核（`cr_*`）、`i2cs` 未覆盖路径、`pwm_apbif`/`i2cm` 边界、`cp_busy.high`。新增 DMA 用例后 `fsmc` line 66.67%→**81.48%**。

**代码覆盖缺口（已核对，排除前）**

| 模块 | line | 说明 |
|---|---|---|
| `ahb_matrix_7_12_arb` | 9.19% | 生成式 7×12 矩阵（`matrix.v` 36667 行），84 条通路大部分未使用，贡献约 87% 的未覆盖行 |
| `ahb_matrix_1_6_sub_dec` | 51.30% | APB 桥译码，部分触达 |
| `pwm_apbif` | 62.05% | `pwm_test.c` 触达 |
| `i2cm` | 67.50% | 仅主机模式 |
| `fsmc` | 66.67% | **无 C 用例** |
| `i2cs` | 76.44% | **无 C 用例** |
| `cr_clic_arb` / `cr_lsu_dp` | 20.16% / 34.29% | CPU 核，指令/中断覆盖窄 |

- `dmac_top`、`E902_20191018` 只有 toggle 数据，疑似 line/cond/branch 未插桩（工具配置问题，会直接压低总分）。
- `cm.cfg` 目前只有 `+tree tb_top.dut`，没有任何排除项。

**功能覆盖缺口**
- `cp_region.isram = 0`；`cx_kind_region` 的 `read|isram`、`write|isram` 未命中。
  - 根因：AHB monitor 绑定 CPU **m2 (BIU)** 口，而 ISRAM 流量走 m0/m1，C 用例（数据访问）打不到该 bin；backdoor `load_pgm()` 也不是总线事务。
  - 处理：在 `nocpu` 的 VIP 序列（驱动 m0）中增加对 `0x0000_eff0` 的写/读，已通过单例验证（`isram test successfully`）。
- `cp_busy` 4 个 bin 命中 2 个：`zero` 不可达（`ahb_monitor::wait_ready()` 先自增再判断 `hready`，busy 恒 ≥1，属模型缺陷）；`high` 需要 ≥9 个等待周期的慢从设备。
- 断言 100% 仅来自 AHB vif 上的 2 条 property，设计内部无 SVA，不能单独作为验证充分性的证据。

**收敛计划（按性价比）**
1. ✅ ~~新增 ISRAM C 用例~~ → 已改为 VIP 序列定向访问；功能覆盖 88.89% → **91.67%**。
2. ✅ 已新增 `dma_modes_test.c`（`fsmc` line 66.67%→81.48%）与 `usi_i2c_slave_test.c`（`i2cs` 仍 76.44%，走同一 slave RX 路径；继续收敛需 slave TX/地址不匹配等新路径）。
3. 修 `cp_busy` 模型（`zero` 改分档或 waive）；`high` 用长 latency 从设备定向激励或 waive。
4. ✅ 覆盖口径：`cm.cfg` 已排除 `tb_top.dut.x_pdu_top.x_main_bus_top`（生成式 7×12 互连）与 `tb_top.dut.x_aou_top.x_pmu_top`（dummy PMU），代码 line 63.89%；对外承诺应为"排除项之外 ≥90%"，当前仍未达到。
5. 为 wdt/rtc/timer/dma 接口补 SVA，避免"断言 100%"名不副实。

> 本轮 18 条回归全部 PASS，上述缺口属于激励/建模/统计口径问题，不是回归失败。

### 8.5 SoC 接口覆盖率（验收口径，目标 85%）

口径：**SoC 顶层 IO（64 个 pad）+ 顶层块接口**（`core_top`/`pdu_top`/`ahb_matrix_top`/`retu_top`/`aou_top` 的模块端口）。对 RTL 中固定电平/未接通/功能模式下不可达的端口做正式 waive（`cm.cfg` 中 154 条 `-node`）。

| 模块 | 端口 | bit |
|---|---|---|
| `wujian100_open_top`（顶层 IO） | **64/64 = 100%** | **128/128 = 100%** |
| `aou_top` | 114/121 = 94.2% | 630/804 = 78.4% |
| `pdu_top` | 153/210 = 72.9% | 1438/2162 = 66.5% |
| `ahb_matrix_top` | 51/101 = 50.5% | 1223/1818 = 67.3% |
| `retu_top` | 18/42 = 42.9% | 620/884 = 70.1% |
| `core_top` | 15/43 = 34.9% | 399/714 = 55.9% |
| **合计** | **415/581 = 71.43%** | **4438/6510 = 68.17%** |

- 顶层 IO 100% 达标；顶层块接口 85% **未达到**，缺口为已实现总线/中断端口的未翻转位（测试缺口，未 waive）。
- 功能覆盖 91.67%、断言 100%。
- 收敛计划（CLIC 中断、映射寄存器扫描、总线地址/数据扫描、USI2 功能）见 `doc/wujian_verification_report.md` 第 8 节。

## 9. 回归测试

### 9.1 用例与模式对照

| 用例 | UVM 用例 | mode | 当前状态（2026-10-23） |
|------|----------|------|------------------------|
| timer/timer_test.c | `soc_top_for_c_case_test` | `soc_test` | PASS |
| rtc/rtc_test.c | `soc_top_for_c_case_test` | `soc_test` | PASS |
| cpu_exception/cpu_exception_test.c | `soc_top_for_c_case_test` | `soc_test` | PASS（ecall/ebreak/illegal/misaligned） |
| dma/dma_test.c | `soc_top_for_c_case_test` | `soc_test` | PASS |
| dma_modes/dma_modes_test.c | `soc_top_for_c_case_test` | `soc_test` | PASS（8/16/32-bit、fixed/inc/dec、group、endian） |
| wdt/wdt_test.c | `soc_top_for_c_case_test` | `soc_test` | PASS（460.369us，见 C.2） |
| gpio/gpio_test.c | `soc_top_for_c_case_test` | `soc_test` + `stim=gpio` | PASS |
| pwm/pwm_test.c | `soc_top_for_c_case_test` | `soc_test` + `stim=pwm` | PASS |
| usi_spi/usi_spi_test.c | `soc_top_for_c_case_test` | `soc_test` + `stim=spi` | PASS |
| usi_i2c/usi_i2c_test.c | `soc_top_for_c_case_test` | `soc_test` + `stim=i2c` | PASS |
| usi_i2c_slave/usi_i2c_slave_test.c | `soc_top_for_c_case_test` | `soc_test` + `stim=i2c` | PASS（0x3c/0x55 双地址 slave 接收） |
| usi_i2c_slave_tx/usi_i2c_slave_tx_test.c | `soc_top_for_c_case_test` | `soc_test` + `stim=i2c` | PASS（slave TX，4 字节） |
| usi_uart/usi_uart_test.c | `soc_top_for_c_case_test` | `soc_test` + `stim=uart` | PASS |
| addr_map/map_test.c | `soc_top_for_c_case_test` | `soc_test` + `stim=map` | PASS |
| had_soc/e902_had_test.c | `soc_top_for_c_case_test` | `soc_test` + `stim=had` | PASS（`HAD TEST PASS`，8.5us） |
| — | `soc_top_smoke_test` | `nocpu` | PASS |
| dma/dma_test.c | `soc_top_for_c_case_test` | `struct` | PASS（结构冒烟） |
| timer/timer_test.c | `soc_top_for_c_case_test` | `struct` | PASS（结构冒烟，覆盖 GATE 路径） |
| timer/timer_test.c | `soc_top_vip_run_with_c_test` | `nocpu` + DPI | PASS（单独验证，不在 18 条回归内） |

说明：子系统激励由 `tc/soc_top_stimulus.svh` 在运行时选择：`+HW_STIM=<name>`（回归里写 `stim=<name>`）在 `run_phase` 中 fork 对应 task，底层用 `uvm_hdl_force/read/release` 操作 pad，等待采用 1ns 轮询（可用 `+STIM_POLL_NS` 调整）。7 类激励（gpio/pwm/spi/i2c/uart/map/had）全部迁入 tc，因此 timer/rtc/wdt/dma 与这些子系统用例共用同一个 `simv_soc_test`，不再需要 `USE_*` 编译宏。`struct` 承载 AHB_HS/GATE 空 TB 的结构冒烟；`nocpu` 走 AHB VIP。子系统 smoke UVM testcase 的 `body()` 仍为空，本轮以 C 用例 + 激励日志关键字作为判据。

**2026-10-24 全量回归（v2.6）：18 条用例，18 PASS / 0 FAIL（随机种子连续 3 轮，单轮 1m56s，3 个编译 mode）。**

### 9.2 回归执行方式（`~/script/regression_v1.0`）

配置：`verify/st/sim/regress.cfg`（`jobs=4`、`coverage=false`、`urg_report=false`、`wave=0`）与 `verify/st/sim/case.lst`。

```bash
cd verify/st/sim
source /eda_tools/synopsys/.bashrc.synopsys
source ../../dv.cshrc
python3 ~/script/regression_v1.0/regr_run.py -c regress.cfg -l case.lst
```

要点：
- `case.lst`：`tc=... mode=... sc=... [stim=<name>]`；日志名 `<sc>_<tc>_<seed>.log`，结果键 `<mode>_<sc>_<tc>`。
- 结果目录 `regress_results_YYYYMMDD/<mode>/`，汇总见 `logging.txt`、`report_<timestamp>.html`、`coverage_report/`。
- 每个 C 用例独立 `<case>.pat`，支持 `jobs=4` 并行。
- 种子：`case.lst` 不写 seed，脚本每次生成；复现时加回 `seed=<n>`。用例按实测时长降序。
- 回归默认 `wave=0`；覆盖率需要时用 `-j 1 --coverage --urg`。
- 运行时激励：`stim=<name>` → `+HW_STIM`；`uvm_hdl_*` 需要 `HDL_ACCESS=1`（已写入 `global_args`）。
- 基线：18/18 PASS × 3 轮，单轮 1m56s，3 个编译 mode。

---

## 附录 A: DPI-C 接口

### A.1 C 语言接口函数

```c
void sim_end();
void sim_fail();
void mem_write32_(longint addr, longint data);
void mem_read32_(longint addr, longint *data);
void cpu_delay(int time_num);
```

### A.2 SystemVerilog 导出

```systemverilog
export "DPI-C" mem_write32_ = task mem_write32_;
export "DPI-C" mem_read32_  = task mem_read32_ ;
export "DPI-C" cpu_delay    = task delay_time  ;
export "DPI-C" sim_fail     = function sim_fail;
export "DPI-C" sim_end      = function sim_end ;
```

### A.3 实现要点

- `ahb_pkg` 中 `mem_write32_` / `mem_read32_` 转发到 `ahb_master_run_with_c_sequence` 句柄 `core`
- VIP DPI 用例 (`soc_top_vip_run_with_c_test`) 必须先启动对应的 C 共享库 (`-sv_lib test_start`)
- CPU C 用例模式不使用 DPI，`sim_end` 由 firmware clib 写 `0x20007c50` 实现

---

## 附录 B: 当前限制与已知问题

1. **AHB/GATE 仅有结构占位** — AHB_HS/AHB_LS/GATE 的 TB 全为空模块，`mode=struct` 一次编译承载 ahb_hs/gate 两条冒烟。仓库无网表/SDF，门级仅为结构冒烟。
2. **RAL/寄存器测试缺失** — `tc/soc_top_reg_test.svh` 依赖未定义的 `rgm`/`self_reg_access_seq`，仓库无 `reg_model/`。
3. **代码覆盖率未达标** — line 36.05% / cond 22.47% / toggle 29.01% / branch 28.37% / FSM 2.22%；功能 88.89%、断言 100% 已达标。缺口主要在 CPU 核、未用外设通道、DMA、PMU/CLIC。
4. **子系统 smoke 用例 `body()` 为空** — 子系统 smoke UVM testcase 目前以 C 用例 + 激励日志关键字判定。
5. **旧目录残留** — `verify/st/soc_top/`、`cfg/bench.f`、`sim/Makefile.orig`、`Makefile.soc_soc_top`、`tc/all_testcases.svh` 不参与编译，不要修改。

> 调试过程、历史变更与已修复问题见 [`doc/debug.log`](debug.log)。

---

## 附录 C: 参考文档

1. Wujian100 Open Userguide v1.0（`doc/wujian100_open Userguide v1.0.docx`）
2. Wujian100 设计文档（`doc/wujian_design.md`）
3. UVM 1.2 Class Reference
4. Synopsys VCS User Guide
5. AMBA AHB Protocol Specification

---

*本文档由 Claude Code 维护，最后更新：2026-10-24*
