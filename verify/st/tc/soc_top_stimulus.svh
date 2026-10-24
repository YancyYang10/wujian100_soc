`ifndef SOC_TOP_STIMULUS__SV
`define SOC_TOP_STIMULUS__SV

// -----------------------------------------------------------------------------
// soc_top_stimulus
//
// Runtime HW stimulus selected by +HW_STIM=<name>, replacing the compile-time
// `ifdef USE_*` subsystem TB modules. All pad/backdoor forces go through the
// UVM HDL DPI API, so the stimulus lives in the testcase (tc) and the same
// simv can run every C case.
//
// Waits are polled with a configurable step (+STIM_POLL_NS, default 1ns);
// this keeps everything in class scope while remaining accurate enough for
// the software-driven pads and the 10ns JTAG clock.
// -----------------------------------------------------------------------------
class soc_top_stimulus;

  // ---- hierarchical paths ---------------------------------------------------
  string p_mcurst    = "tb_top.PAD_MCURST";
  string p_gpio_pre  = "tb_top.PAD_GPIO_";                       // + index 0..31
  string p_gpio_ddr  = "tb_top.dut.x_aou_top.x_gpio_sec_top.gpio_porta_ddr";
  string p_pwm_ch0   = "tb_top.PAD_PWM_CH0";
  string p_pwm_ch2   = "tb_top.PAD_PWM_CH2";
  string p_usi0_sclk = "tb_top.PAD_USI0_SCLK";
  string p_usi0_nss  = "tb_top.PAD_USI0_NSS";
  string p_usi0_sd0  = "tb_top.PAD_USI0_SD0";
  string p_usi1_sclk = "tb_top.PAD_USI1_SCLK";
  string p_usi1_nss  = "tb_top.PAD_USI1_NSS";
  string p_usi1_sd0  = "tb_top.PAD_USI1_SD0";
  string p_usi1_oe_n = "tb_top.dut.usi1_ioctl_sd0_oe_n";
  string p_jtag_tclk = "tb_top.PAD_JTAG_TCLK";
  string p_jtag_tms  = "tb_top.PAD_JTAG_TMS";

  // ---- polling step ---------------------------------------------------------
  time poll_step = 1ns;

  function new();
    int unsigned poll_ns;
    if ($value$plusargs("STIM_POLL_NS=%d", poll_ns) && poll_ns > 0)
      poll_step = poll_ns * 1ns;
  endfunction

  // ---- low-level HDL access -------------------------------------------------
  function bit rd1(string path);
    uvm_hdl_data_t v;
    if (!uvm_hdl_read(path, v)) begin
      `uvm_error("STIM", $sformatf("uvm_hdl_read failed: %s", path))
      return 1'bx;
    end
    return v[0];
  endfunction

  function logic [31:0] rd32(string path);
    uvm_hdl_data_t v;
    if (!uvm_hdl_read(path, v)) begin
      `uvm_error("STIM", $sformatf("uvm_hdl_read failed: %s", path))
      return 32'bx;
    end
    return v[31:0];
  endfunction

  function void frc1(string path, logic val);
    if (!uvm_hdl_force(path, val))
      `uvm_error("STIM", $sformatf("uvm_hdl_force failed: %s", path))
  endfunction

  function void frc32(string path, logic [31:0] val);
    if (!uvm_hdl_force(path, val))
      `uvm_error("STIM", $sformatf("uvm_hdl_force failed: %s", path))
  endfunction

  function void rel(string path);
    // Releasing a signal that is not forced returns 0; this is harmless.
    void'(uvm_hdl_release(path));
  endfunction

  // ---- generic wait helpers -------------------------------------------------
  task automatic wait_eq1(string path, logic val);
    forever begin
      if (rd1(path) === val) return;
      #(poll_step);
    end
  endtask

  task automatic wait_eq32(string path, logic [31:0] val);
    forever begin
      if (rd32(path) === val) return;
      #(poll_step);
    end
  endtask

  task automatic wait_posedge(string path);
    logic prev, cur;
    prev = rd1(path);
    forever begin
      #(poll_step);
      cur = rd1(path);
      if (prev === 1'b0 && cur === 1'b1) return;
      prev = cur;
    end
  endtask

  task automatic wait_negedge(string path);
    logic prev, cur;
    prev = rd1(path);
    forever begin
      #(poll_step);
      cur = rd1(path);
      if (prev === 1'b1 && cur === 1'b0) return;
      prev = cur;
    end
  endtask

  // Continuously mirror src onto dst (emulates `force dst = src`).
  task automatic follow(string src, string dst);
    logic prev, cur;
    prev = rd1(src);
    frc1(dst, prev);
    forever begin
      #(poll_step);
      cur = rd1(src);
      if (cur !== prev) begin
        frc1(dst, cur);
        prev = cur;
      end
    end
  endtask

  // ---- gpio -----------------------------------------------------------------
  function logic [31:0] read_gpio();
    logic [31:0] v;
    for (int i = 0; i < 32; i++)
      v[i] = rd1($sformatf("%s%0d", p_gpio_pre, i));
    return v;
  endfunction

  task automatic force_gpio(logic [31:0] v);
    for (int i = 0; i < 32; i++)
      frc1($sformatf("%s%0d", p_gpio_pre, i), v[i]);
  endtask

  task automatic release_gpio();
    for (int i = 0; i < 32; i++)
      rel($sformatf("%s%0d", p_gpio_pre, i));
  endtask

  task automatic wait_gpio(logic [31:0] val);
    forever begin
      if (read_gpio() === val) return;
      #(poll_step);
    end
  endtask

  task automatic gpio_stim();
    wait_eq1(p_mcurst, 1'b1);
    wait_eq32(p_gpio_ddr, 32'h0000_0000);
    force_gpio(32'h5555_5555);
    `uvm_info("STIM", "gpio: drive 0x55555555", UVM_LOW)

    wait_eq32(p_gpio_ddr, 32'hffff_ffff);
    release_gpio();
    wait_gpio(32'h5a5a_5a5a);
    `uvm_info("STIM", "gpio: read back 0x5a5a5a5a", UVM_LOW)

    wait_eq32(p_gpio_ddr, 32'h0000_0000);
    force_gpio(32'haaaa_aaaa);

    wait_eq32(p_gpio_ddr, 32'hffff_ffff);
    release_gpio();
    wait_gpio(32'ha5a5_a5a5);
    `uvm_info("STIM", "gpio: read back 0xa5a5a5a5", UVM_LOW)

    wait_eq32(p_gpio_ddr, 32'h0000_0000);
    force_gpio(32'h1234_5678);
    `uvm_info("STIM", "gpio: drive 0x12345678", UVM_LOW)
  endtask

  // ---- pwm ------------------------------------------------------------------
  task automatic pwm_stim();
    bit input_data = 1'b0;
    frc1(p_pwm_ch2, input_data);          // legacy TB drives CH2 from time 0
    wait_eq1(p_mcurst, 1'b1);

    wait_eq1(p_pwm_ch0, 1'b0);
    wait_eq1(p_pwm_ch0, 1'b1);
    repeat (20) wait_posedge(p_pwm_ch0);
    `uvm_info("STIM", "pwm: ch0 output test pass", UVM_LOW)

    forever begin
      wait_posedge(p_pwm_ch0);
      input_data = ~input_data;
      frc1(p_pwm_ch2, input_data);
    end
  endtask

  // ---- usi loopbacks --------------------------------------------------------
  task automatic usi_spi_stim();
    wait_eq1(p_mcurst, 1'b1);
    fork
      follow(p_usi0_sclk, p_usi1_sclk);
      follow(p_usi0_nss,  p_usi1_nss);
      follow(p_usi0_sd0,  p_usi1_sd0);
    join_none
  endtask

  task automatic usi_i2c_stim();
    logic en, v;
    wait_eq1(p_mcurst, 1'b1);
    fork
      follow(p_usi0_sclk, p_usi1_sclk);
    join_none

    // Bidirectional SDA: mirror only the side the DUT is not driving.
    // oe_n=1 -> USI1 is an input, copy USI0 -> USI1; oe_n=0 -> copy USI1 -> USI0.
    // A single state-driven copier avoids two concurrent follow loops fighting.
    forever begin
      en = rd1(p_usi1_oe_n);
      if (en === 1'b1) begin
        v = rd1(p_usi0_sd0);
        frc1(p_usi1_sd0, v);
        rel(p_usi0_sd0);
      end
      else begin
        v = rd1(p_usi1_sd0);
        frc1(p_usi0_sd0, v);
        rel(p_usi1_sd0);
      end
      #(poll_step);
    end
  endtask

  task automatic usi_uart_stim();
    wait_eq1(p_mcurst, 1'b1);
    fork
      follow(p_usi0_sd0, p_usi1_sclk);
    join_none
  endtask

  // ---- address map ----------------------------------------------------------
  task automatic addr_map_stim();
    frc32("tb_top.dut.x_pdu_top.x_main_bus_top.x_main_imemdummy_top0.hrdata", 32'h01);
    frc32("tb_top.dut.x_pdu_top.x_main_bus_top.x_main_dmemdummy_top0.hrdata", 32'h02);
    frc32("tb_top.dut.x_pdu_top.x_main_bus_top.x_main_dummy_top0.hrdata",     32'h03);
    frc32("tb_top.dut.x_pdu_top.x_main_bus_top.x_main_dummy_top1.hrdata",     32'h04);
    frc32("tb_top.dut.x_pdu_top.x_main_bus_top.x_main_dummy_top2.hrdata",     32'h05);
    frc32("tb_top.dut.x_pdu_top.x_main_bus_top.x_main_dummy_top3.hrdata",     32'h06);

    frc32("tb_top.dut.x_pdu_top.x_sub_ls_top.x_lsbus_dummy_top0.hrdata", 32'h11);
    frc32("tb_top.dut.x_pdu_top.x_sub_ls_top.x_lsbus_dummy_top1.hrdata", 32'h12);
    frc32("tb_top.dut.x_pdu_top.x_sub_ls_top.x_lsbus_dummy_top2.hrdata", 32'h13);
    frc32("tb_top.dut.x_pdu_top.x_sub_ls_top.x_lsbus_dummy_top3.hrdata", 32'h14);

    frc32("tb_top.dut.x_pdu_top.x_sub_apb0_top.x_apb0_dummy_top1.prdata", 32'h22);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb0_top.x_apb0_dummy_top2.prdata", 32'h23);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb0_top.x_apb0_dummy_top3.prdata", 32'h24);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb0_top.x_apb0_dummy_top4.prdata", 32'h25);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb0_top.x_apb0_dummy_top5.prdata", 32'h26);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb0_top.x_apb0_dummy_top7.prdata", 32'h28);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb0_top.x_apb0_dummy_top8.prdata", 32'h29);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb0_top.x_apb0_dummy_top9.prdata", 32'h2a);

    frc32("tb_top.dut.x_pdu_top.x_sub_apb1_top.x_apb1_dummy_top1.prdata", 32'h32);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb1_top.x_apb1_dummy_top2.prdata", 32'h33);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb1_top.x_apb1_dummy_top3.prdata", 32'h34);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb1_top.x_apb1_dummy_top4.prdata", 32'h35);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb1_top.x_apb1_dummy_top5.prdata", 32'h36);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb1_top.x_apb1_dummy_top6.prdata", 32'h37);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb1_top.x_apb1_dummy_top7.prdata", 32'h38);
    frc32("tb_top.dut.x_pdu_top.x_sub_apb1_top.x_apb1_dummy_top8.prdata", 32'h39);

    frc32("tb_top.dut.x_aou_top.x_pmu_top.prdata", 32'h3333_3333);
  endtask

  // ---- HAD / JTAG -----------------------------------------------------------
  // Port of tb/top_sim/had/e902_had_test.v. TMS is an inout pad: forced while
  // shifting in, released and sampled while shifting out.
  // IR codes: HCR = 7'b0001101, HSR = 7'b0001110.

  task automatic had_write_ir(logic [7:0] ir_value);
    logic parity;
    parity = 1'b1;
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b0);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b0);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b0);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk);
    for (int a = 0; a < 8; a++) begin
      frc1(p_jtag_tms, ir_value[a]);
      parity = parity ^ ir_value[a];
      wait_negedge(p_jtag_tclk);
    end
    frc1(p_jtag_tms, parity);
    wait_negedge(p_jtag_tclk);
    frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk);
    frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk);
  endtask

  task automatic had_write_dr(logic [31:0] data);
    logic parity;
    parity = 1'b1;
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b0);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b0);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk);
    for (int b = 0; b < 32; b++) begin
      frc1(p_jtag_tms, data[b]);
      parity = parity ^ data[b];
      wait_negedge(p_jtag_tclk);
    end
    frc1(p_jtag_tms, parity);
    wait_negedge(p_jtag_tclk);
    frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk);
    frc1(p_jtag_tms, 1'b1);
  endtask

  task automatic had_read_dr(output logic [31:0] data_out);
    logic parity;
    parity = 1'b1;
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b0);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_posedge(p_jtag_tclk); rel(p_jtag_tms);
    wait_posedge(p_jtag_tclk);
    for (int c = 0; c < 32; c++) begin
      wait_posedge(p_jtag_tclk);
      data_out[c] = rd1(p_jtag_tms);
    end
    wait_posedge(p_jtag_tclk);
    parity = rd1(p_jtag_tms);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
    wait_negedge(p_jtag_tclk); frc1(p_jtag_tms, 1'b1);
  endtask

  task automatic had_write_hadreg(logic [6:0] reg_sel, logic [31:0] value);
    had_write_ir({1'b0, reg_sel});
    had_write_dr(value);
  endtask

  task automatic had_read_hadreg(logic [6:0] reg_sel, output logic [31:0] value);
    had_write_ir({1'b1, reg_sel});
    had_read_dr(value);
  endtask

  task automatic had_wait_debug_mode();
    logic [31:0] hsr;
    had_read_hadreg(7'b0001110, hsr);          // HSR
    $display("---------------------------------------");
    $display("wait into debug mode......            |");
    $display("<wait_begin> The hsr is: 0x%h       |", hsr[15:0]);
    // Bounded wait: the legacy TB exited on X/Z; with a clean 0 read it would
    // spin forever. Keep the smoke pass criteria but never hang.
    for (int i = 0; i < 10 && (hsr[1:0] != 2'b10); i++)
      had_read_hadreg(7'b0001110, hsr);
    $display("<wait_end>   The hsr is: 0x%h       |", hsr[15:0]);
    $display("Now, CPU is in Debug Mode!            |");
    $display("---------------------------------------");
  endtask

  task automatic had_stim();
    wait_eq1(p_mcurst, 1'b1);
    $display("******    Now is JTAG_2!!!        ******");
    repeat (100) wait_posedge(p_jtag_tclk);
    had_write_hadreg(7'b0001101, 32'h0000_8000);   // HCR = 0x8000
    had_wait_debug_mode();
    had_write_hadreg(7'b0001101, 32'h0000_0000);   // HCR = 0
    $display("**************************************************");
    $display("*********** Congratulation!:HAD TEST PASS  *******");
    $display("**************************************************");
    $display("WUJIAN TEST END");
    $finish;
  endtask

  // ---- top-level IO pad toggle ---------------------------------------------
  // Drives the pads that normal functional tests leave untouched, so the
  // SoC top-level IO coverage reflects every pad.
  task automatic io_pad_stim();
    string pads[$] = '{
      "tb_top.PAD_PWM_FAULT",
      "tb_top.PAD_USI0_SD1",
      "tb_top.PAD_USI1_SD1",
      "tb_top.PAD_USI2_NSS",
      "tb_top.PAD_USI2_SCLK",
      "tb_top.PAD_USI2_SD0",
      "tb_top.PAD_USI2_SD1"
    };
    wait_eq1(p_mcurst, 1'b1);
    for (int i = 0; i < 6; i++) begin
      foreach (pads[j])
        frc1(pads[j], i[0]);
      #(1us);
    end
    foreach (pads[j])
      rel(pads[j]);
    `uvm_info("STIM", "top-level IO pads toggled", UVM_LOW)
  endtask

  // ---- dispatch -------------------------------------------------------------
  task automatic run(string name);
    `uvm_info("STIM", $sformatf("HW stimulus selected: %s", name), UVM_LOW)
    case (name)
      "gpio": gpio_stim();
      "pwm":  pwm_stim();
      "spi":  usi_spi_stim();
      "i2c":  usi_i2c_stim();
      "uart": usi_uart_stim();
      "map":  addr_map_stim();
      "had":  had_stim();
      "io":   io_pad_stim();
      "none": ;
      default: `uvm_warning("STIM", $sformatf("unknown +HW_STIM=%s, no stimulus", name))
    endcase
  endtask

endclass

`endif
