# Wujian100 Open 验证报告

> **报告版本**: v2.0
> **日期**: 2026-10-24
> **验证对象**: Wujian100 Open SoC（E902 + AHB Matrix + APB0/APB1 外设）
> **验证环境**: `verify/st`（UVM 1.2 + VCS/Verdi O-2018.09-SP2）
> **覆盖率口径**: SoC 顶层 IO + 顶层块接口（端口 toggle），目标 85%
> **结论**: 功能回归 **20/20 PASS**；**顶层 IO 100%**；顶层块接口（waive 结构性不可达端口后）**端口 71.43% / bit 68.17%**；功能覆盖 91.67%、断言 100%。**85% 目标未达到**，剩余缺口集中在已实现总线的未翻转位，需继续补定向用例（见第 8 节）。

---

## 1. 验证范围与策略

### 1.1 范围
- **SOC 顶层**：CPU（E902）驱动 + AHB VIP 驱动两种模式。
- **外设**：timer、rtc、wdt、dma（16 通道）、gpio、pwm（12 通道）、usi_spi、usi_i2c（master/slave/slave TX）、usi_uart、addr_map、HAD/JTAG。
- **结构冒烟**：AHB_HS / GATE（仓库无网表/SDF）。
- **不在本轮范围**：RAL/寄存器模型、CPU 全指令集、门级带 SDF 时序、CPU 内部模块端口。

### 1.2 覆盖率验收口径
- **顶层 IO**：`wujian100_open_top` 的 64 个 pad 端口。
- **顶层块接口**：`core_top`、`pdu_top`、`ahb_matrix_top`、`retu_top`、`aou_top` 的模块端口。
- 目标：**85%**（端口数与端口 bit 双向统计）。
- 对 RTL 中固定电平/未接通/功能模式下不可达的端口做正式 waive，清单见 5.2。

---

## 2. 验证环境

| 项目 | 说明 |
|---|---|
| 方法学 | UVM 1.2 |
| 仿真器 | Synopsys VCS O-2018.09-SP2（+ Verdi FSDB） |
| 工作目录 | `verify/st/sim` |
| 回归框架 | `~/script/regression_v1.0/regr_run.py` |
| 编译 mode | `soc_test` / `nocpu` / `struct`（共 3 个） |
| 运行时激励 | `tc/soc_top_stimulus.svh`，`+HW_STIM=<gpio|pwm|spi|i2c|uart|map|had|io>` |
| 激励实现 | `uvm_hdl_force/read/release` + 1ns 轮询 |
| 回归配置 | `regress.cfg`：`jobs=4`、`wave=0`、`HDL_ACCESS=1`；覆盖率按需 `--coverage --urg` |

---

## 3. 测试套件

20 条用例（16 条 C 用例 + VIP smoke + 2 条结构冒烟 + 1 条 pad 用例）：

| # | 用例 | mode / stim | 覆盖点 |
|---|---|---|---|
| 1 | timer/timer_test.c | soc_test | 定时器计数/中断 |
| 2 | rtc/rtc_test.c | soc_test | RTC |
| 3 | wdt/wdt_test.c | soc_test | 看门狗超时 + 系统复位重启 |
| 4 | dma/dma_test.c | soc_test | DMA 基本传输 |
| 5 | dma_modes/dma_modes_test.c | soc_test | 8/16/32-bit、fixed/inc/dec、group、endian、ch0-15 |
| 6 | gpio/gpio_test.c | soc_test + stim=gpio | GPIO 输出/回读 |
| 7 | pwm/pwm_test.c | soc_test + stim=pwm | PWM 通道输出/capture |
| 8 | pwm_all/pwm_all_test.c | soc_test | PWM 12 通道全输出 |
| 9 | usi_spi/usi_spi_test.c | soc_test + stim=spi | SPI 回环 |
| 10 | usi_i2c/usi_i2c_test.c | soc_test + stim=i2c | I2C master TX / slave RX |
| 11 | usi_i2c_slave/usi_i2c_slave_test.c | soc_test + stim=i2c | 0x3c/0x55 双从地址 slave RX |
| 12 | usi_i2c_slave_tx/usi_i2c_slave_tx_test.c | soc_test + stim=i2c | I2C slave TX（master read） |
| 13 | usi_uart/usi_uart_test.c | soc_test + stim=uart | UART 回环 |
| 14 | addr_map/map_test.c | soc_test + stim=map | 地址映射/dummy 读数据 |
| 15 | had_soc/e902_had_test.c | soc_test + stim=had | HAD/JTAG 调试 |
| 16 | cpu_exception/cpu_exception_test.c | soc_test | ecall/ebreak/illegal/misaligned + CSR |
| 17 | io_pad/io_pad_test.c | soc_test + stim=io | 顶层 pad 翻转 |
| 18 | soc_top_smoke_test | nocpu | AHB VIP smoke + ISRAM + 接口地址翻转 |
| 19 | struct (dma) | struct | AHB_HS 结构冒烟 |
| 20 | struct (timer) | struct | GATE 结构冒烟 |

---

## 4. 回归结果

| 轮次 | 用例数 | 结果 | 时长 |
|---|---|---|---|
| R1（覆盖率轮，随机种子） | 20 | 20/20 PASS | — |
| R2（随机种子） | 20 | 20/20 PASS | 2m10s |
| R3（随机种子） | 20 | 20/20 PASS | 2m09s |

- 判定：退出码 + `UVM TEST PASSED` / `HAD TEST PASS` 关键字。
- 随机种子每次生成，失败可在 `case.lst` 加回 `seed=<n>` 复现。
- 结果目录：`verify/st/sim/regress_results_<date>/`。

---

## 5. 覆盖率

### 5.1 顶层 IO（SoC pad）
| 指标 | 实测 | 目标 | 结论 |
|---|---|---|---|
| 端口 | **64/64 = 100%** | ≥85% | ✅ |
| bit | **128/128 = 100%** | ≥85% | ✅ |

所有 pad（GPIO/USI0-2/PWM0-11/JTAG/时钟/复位）均已 0→1、1→0 双向翻转。

### 5.2 顶层块接口（waive 结构性不可达端口后）

| 模块 | 端口 | bit |
|---|---|---|
| `wujian100_open_top`（顶层 IO） | **64/64 = 100%** | **128/128 = 100%** |
| `aou_top` | 114/121 = 94.2% | 630/804 = 78.4% |
| `pdu_top` | 153/210 = 72.9% | 1438/2162 = 66.5% |
| `ahb_matrix_top` | 51/101 = 50.5% | 1223/1818 = 67.3% |
| `retu_top` | 18/42 = 42.9% | 620/884 = 70.1% |
| `core_top` | 15/43 = 34.9% | 399/714 = 55.9% |
| **合计** | **415/581 = 71.43%** | **4438/6510 = 68.17%** |

**Waive 清单**（154 个结构性不可达端口，写入 `cm.cfg` 的 `-node` 排除）：

| 模块 | 数量 | 典型信号 | 依据 |
|---|---|---|---|
| `x_cpu_top` | 45 | `apb0/1_dummy*_intr`、`bist0_mode`、`test_mode`、`scan_mode`、`cpu_hmain0_m1_hwrite/hready` | dummy 从设备中断恒 0；DFT 静态控制；m1 数据端口本 SoC 未使用 |
| `x_pdu_top` | 90 | `ioctl_pwm_cap*`、`ioctl_usi2_*_in`、dummy 中断、`pmu_apb*_pclk_en` | PWM capture 未接；USI2 未配置；PMU 静态使能 |
| `x_main_bus_top` | 9 | `dmac0_wic_intr`、dummy 中断、`hmain0_cpu_m1_hready` | 未使用中断/端口 |
| `x_aou_top` | 9 | `cpu_pmu_dfs_ack`、`cpu_pmu_sleep_b`、`pmu_wic_intr`、`test_mode` | PMU 占位/DFT |

> 注：`-node` waive 为**信号级**；部分总线端口仍为部分翻转（uncovered bit），未做 bit 级 waive，避免掩盖测试缺口。

### 5.3 功能与断言覆盖
| 类型 | 实测 | 目标 | 结论 |
|---|---|---|---|
| 功能覆盖（`ahb_cov`） | **91.67%** | ≥85% | ✅ |
| 断言覆盖 | **100.00%** | ≥95% | ✅ |

- 功能覆盖缺口：`cp_busy.zero`（死 bin，`wait_ready()` 先自增）、`cp_busy.high`（≥9 周期）。
- 断言仅 AHB vif 上 2 条 property，设计内部无 SVA。

### 5.4 内部模块代码覆盖率（参考，不作为验收门槛）
| 类型 | 实测 |
|---|---|
| line | 69.76% |
| cond | 44.23% |
| toggle | 34.74% |
| branch | 58.65% |
| FSM | 22.49% |

---

## 6. 缺陷列表（均已修复）

| # | 问题 | 根因 | 修复 | 状态 |
|---|---|---|---|---|
| 1 | WDT 用例失败，CPU 不复位 | RTL `pmu_wdt_p0rst_b` 依赖自身 `sys_rst`（零宽脉冲）；TB 永久 `force pad_core_rst_b=1` | `pmu_wdt_p0rst_b = pad_mcurst_b`；TB 改 `release` | 已修复 PASS |
| 2 | 并行回归偶发挂死/exit(1) | `wave=0` 仍传 `+UVM_VERDI_TRACE`，争抢共享 `novas.fsdb` | 仅 `wave=1` 传该 plusarg | 已修复 |
| 3 | I2C 运行时激励卡死 | 缺 pullup；双向 SDA 两个 follow 互锁 | `tb_top` 常驻 pullup；按 OE 单向镜像 | 已修复 |
| 4 | DMA 用例挂死总线 | 有符号溢出 UB（`-O3`）；缓冲落在 ISRAM 程序区 | 无符号运算；缓冲移 DSRAM | 已修复 |
| 5 | HAD 运行时激励死循环 | HSR 读回 0，`while` 不退出 | 有界 10 次读取 | 已修复 |
| 6 | DMA 用例对覆盖率无贡献 | 覆盖排除误把 DMAC 一起排除 | 只排除矩阵实例与 dummy 从设备 | 已修复 |

调试证据与时间线：`doc/debug.log`。

---

## 7. 风险评估

| 风险 | 等级 | 说明 / 缓解 |
|---|---|---|
| 顶层块接口 71.4%/68.2%，未达 85% | **高** | 已实现总线的未翻转位属测试缺口；需补 CLIC 中断、映射寄存器扫描、地址/数据多样性 |
| Waive 依赖结构性判断 | 中 | 154 个端口依据 RTL 静态分析；设计变更后需重新核对 |
| 断言覆盖样本小（2 条 AHB property） | 中 | 100% 不代表充分；建议补 APB/外设 SVA |
| RAL 缺失 | 中 | 无自动化寄存器测试，寄存器访问依赖 C 用例 |
| AHB_HS/GATE 无网表/SDF | 中 | 仅结构冒烟，门级时序未验证 |
| CPU 内部模块未纳入验收 | 中 | 本口径已明确排除；CPU 内部状态需单独验证 |

---

## 8. 收敛分析（距 85% 的差距）

**当前（waive 后）**：端口 415/581（71.43%），bit 4438/6510（68.17%）。
**85% 需要**：端口 494/581（+79），bit 5534/6510（+1096）。

未覆盖分布：
- `pdu_top` 724 bit（总线/中断）
- `core_top` 315 bit（中断输入、debug/PMU）
- `ahb_matrix_top` 595 bit（地址高位/区域译码）
- `retu_top` 264 bit（SRAM 地址/数据）
- `aou_top` 174 bit（时钟/复位/PMU）

计划（按收益排序）：
1. **CLIC/中断定向用例**：使能多路 IRQ（TIM/USI/GPIO/RTC/WDT/DMA），触发并处理中断 → 补 `core_top` 中断端口（预计 +150~250 bit）。
2. **安全寄存器扫描**：仅访问已实现的外设寄存器偏移（TIM/WDT/PWM/USI/RTC/GPIO），避免 ERROR 响应 → 补 `pdu_top`/leaf mux（预计 +300~500 bit）。
3. **总线地址/数据扫描**：DSRAM1/2 全地址 + 数据模式；带 trap handler 容错 → 补 `ahb_matrix_top`/`retu_top`（预计 +300~500 bit）。
4. **USI2/SD1 功能用例**：配置 USI2 SPI/UART，驱动 SD1 → 补 `pdu_top`/USI 端口。

综合预计可达 **78~82%**；到 85% 需要进一步覆盖 CPU 中断/调试相关的部分端口，或对更多已实现但当前用例无法触达的总线位做有依据的 waive。

---

## 9. 结论与交付物

**结论**
- 功能回归 20/20 PASS（随机种子多轮）。
- 顶层 IO 覆盖率 **100%**，达到并超过 85% 目标。
- 顶层块接口覆盖率（waive 结构性不可达端口后）**端口 71.43% / bit 68.17%**，**未达到 85%**。
- 功能覆盖 91.67%、断言 100%。
- 主要剩余工作：按第 8 节补 CLIC 中断、寄存器扫描、总线地址/数据扫描、USI2 功能用例。

**交付物**
- UVM 1.2 环境：`verify/st`
- 回归配置与用例：`verify/st/sim/{regress.cfg,case.lst}`
- 覆盖率报告：`verify/st/sim/regress_results_<date>/coverage_report/`
- Waive 清单：`doc/coverage_waiver.md`（154 个端口及依据），应用配置 `verify/st/sim/cm.cfg`
- 文档：`doc/wujian_verify.md`、`doc/debug.log`、本报告
- 备份：`backup/`

**复现**
```bash
cd verify/st/sim
source /eda_tools/synopsys/.bashrc.synopsys
source ../../dv.cshrc
python3 ~/script/regression_v1.0/regr_run.py -c regress.cfg -l case.lst -j 4
python3 ~/script/regression_v1.0/regr_run.py -c regress.cfg -l case.lst -j 1 --coverage --urg
```
