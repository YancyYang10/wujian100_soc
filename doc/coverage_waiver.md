# 端口覆盖率 Waive 清单

> 日期：2026-10-24
> 口径：SoC 顶层 IO + 顶层块接口（端口 toggle）
> 应用位置：`verify/st/sim/cm.cfg`（VCS `-cm_hier -node`，编译期生效）

## 依据

以下端口在 RTL 中为固定电平、未接通或在功能模式下不可达，任何测试激励都无法使其双向翻转：

1. dummy 从设备中断（`*_dummy*_intr`）恒为 0；
2. DFT/测试模式（`test_mode`、`scan_mode`、`bist0_mode`）在功能仿真中固定；
3. PMU 占位/静态控制（`cpu_pmu_dfs_ack`、`cpu_pmu_sleep_b`、`pmu_*_pclk_en`、`pmu_wic_intr`）；
4. 本 SoC 未使用的 CPU m1 数据端口控制（`cpu_hmain0_m1_hwrite`、`hmain0_cpu_m1_hready`）；
5. PWM capture 输入（`ioctl_pwm_cap*`）与未配置的 USI2 ioctl 输入（`ioctl_usi2_*_in`）。

## 清单

### `tb_top.dut.x_aou_top`（9 个）

`apb1_pmu_psel_s15`, `cpu_pmu_dfs_ack`, `cpu_pmu_sleep_b`, `gpio_wic_intr`, `pmu_apb0_pclk_en`, `pmu_apb1_pclk_en`, `pmu_cpu_dfs_req`, `pmu_wic_intr`, `test_mode`

### `tb_top.dut.x_cpu_top`（45 个）

`apb0_dummy1_intr`, `apb0_dummy2_intr`, `apb0_dummy3_intr`, `apb0_dummy4_intr`, `apb0_dummy5_intr`, `apb0_dummy7_intr`, `apb0_dummy8_intr`, `apb0_dummy9_intr`, `apb1_dummy1_intr`, `apb1_dummy2_intr`, `apb1_dummy3_intr`, `apb1_dummy4_intr`, `apb1_dummy5_intr`, `apb1_dummy6_intr`, `apb1_dummy7_intr`, `apb1_dummy8_intr`, `bist0_mode`, `cpu_hmain0_m1_hwrite`, `cpu_padmux_jtg_tms_o`, `cpu_padmux_jtg_tms_oe`, `cpu_pmu_dfs_ack`, `cpu_pmu_sleep_b`, `dmac0_wic_intr`, `gpio_wic_intr`, `hmain0_cpu_m1_hready`, `lsbus_dummy0_intr`, `lsbus_dummy1_intr`, `lsbus_dummy2_intr`, `lsbus_dummy3_intr`, `main_dmemdummy0_intr`, `main_dummy0_intr`, `main_dummy1_intr`, `main_dummy2_intr`, `main_dummy3_intr`, `main_imemdummy0_intr`, `pmu_cpu_dfs_req`, `pmu_wic_intr`, `pwm_wic_intr`, `scan_en`, `scan_mode`, `test_mode`, `usi0_wic_intr`, `usi1_wic_intr`, `usi2_wic_intr`, `wdt_wic_intr`

### `tb_top.dut.x_pdu_top`（91 个）

`apb0_dummy1_intr`, `apb0_dummy2_intr`, `apb0_dummy3_intr`, `apb0_dummy4_intr`, `apb0_dummy5_intr`, `apb0_dummy7_intr`, `apb0_dummy8_intr`, `apb0_dummy9_intr`, `apb1_dummy1_intr`, `apb1_dummy2_intr`, `apb1_dummy3_intr`, `apb1_dummy4_intr`, `apb1_dummy5_intr`, `apb1_dummy6_intr`, `apb1_dummy7_intr`, `apb1_dummy8_intr`, `apb1_pmu_psel_s15`, `cpu_hmain0_m1_hwrite`, `dmac0_wic_intr`, `hmain0_cpu_m1_hready`, `ioctl_pwm_cap0`, `ioctl_pwm_cap10`, `ioctl_pwm_cap4`, `ioctl_pwm_cap6`, `ioctl_pwm_cap8`, `ioctl_usi0_nss_in`, `ioctl_usi0_sd1_in`, `ioctl_usi1_sd1_in`, `ioctl_usi2_sclk_in`, `ioctl_usi2_sd0_in`, `ioctl_usi2_sd1_in`, `lsbus_dummy0_intr`, `lsbus_dummy1_intr`, `lsbus_dummy2_intr`, `lsbus_dummy3_intr`, `main_dmemdummy0_intr`, `main_dummy0_intr`, `main_dummy1_intr`, `main_dummy2_intr`, `main_dummy3_intr`, `main_imemdummy0_intr`, `pmu_apb0_pclk_en`, `pmu_apb1_pclk_en`, `pwm_ioctl_ch0_oe_n`, `pwm_ioctl_ch10_oe_n`, `pwm_ioctl_ch11_oe_n`, `pwm_ioctl_ch1_oe_n`, `pwm_ioctl_ch2_oe_n`, `pwm_ioctl_ch3_oe_n`, `pwm_ioctl_ch4_oe_n`, `pwm_ioctl_ch5_oe_n`, `pwm_ioctl_ch6_oe_n`, `pwm_ioctl_ch7_oe_n`, `pwm_ioctl_ch8_oe_n`, `pwm_ioctl_ch9_oe_n`, `pwm_wic_intr`, `scan_mode`, `test_mode`, `usi0_ioctl_nss_ie_n`, `usi0_ioctl_nss_oe_n`, `usi0_ioctl_sclk_ie_n`, `usi0_ioctl_sd0_ie_n`, `usi0_ioctl_sd1_ie_n`, `usi0_ioctl_sd1_oe_n`, `usi0_ioctl_sd1_out`, `usi0_wic_intr`, `usi1_ioctl_nss_ie_n`, `usi1_ioctl_nss_oe_n`, `usi1_ioctl_nss_out`, `usi1_ioctl_sclk_ie_n`, `usi1_ioctl_sclk_oe_n`, `usi1_ioctl_sclk_out`, `usi1_ioctl_sd0_ie_n`, `usi1_ioctl_sd1_ie_n`, `usi1_ioctl_sd1_oe_n`, `usi1_ioctl_sd1_out`, `usi1_wic_intr`, `usi2_ioctl_nss_ie_n`, `usi2_ioctl_nss_oe_n`, `usi2_ioctl_nss_out`, `usi2_ioctl_sclk_ie_n`, `usi2_ioctl_sclk_oe_n`, `usi2_ioctl_sclk_out`, `usi2_ioctl_sd0_ie_n`, `usi2_ioctl_sd0_oe_n`, `usi2_ioctl_sd0_out`, `usi2_ioctl_sd1_ie_n`, `usi2_ioctl_sd1_oe_n`, `usi2_ioctl_sd1_out`, `usi2_wic_intr`, `wdt_wic_intr`

### `tb_top.dut.x_pdu_top.x_main_bus_top`（9 个）

`cpu_hmain0_m1_hwrite`, `dmac0_wic_intr`, `hmain0_cpu_m1_hready`, `main_dmemdummy0_intr`, `main_dummy0_intr`, `main_dummy1_intr`, `main_dummy2_intr`, `main_dummy3_intr`, `main_imemdummy0_intr`

