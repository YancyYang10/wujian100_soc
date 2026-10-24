`ifndef SOC_TOP_TEST_BASE__SV
`define SOC_TOP_TEST_BASE__SV
class soc_top_error_demoter extends uvm_report_catcher;
  function new(string name="soc_top_error_demoter");
    super.new(name);
  endfunction
  //This example demotes "MY_ID" errors to an info message
  function action_e catch();
    if(get_severity() == UVM_ERROR && get_id() == "MY_ID")
      set_severity(UVM_INFO);
    return THROW;
  endfunction
endclass

class soc_top_test_base extends uvm_test;

  // UVM Factory Registration Macro
  //
	`uvm_component_utils(soc_top_test_base)

  //------------------------------------------
  // Data Members
  //------------------------------------------
  uvm_cmdline_processor clp = uvm_cmdline_processor::get_inst();
  `ifndef UVM_VERSION_1_1
  uvm_coreservice_t cs = uvm_coreservice_t::get();
  uvm_factory factory = cs.get_factory();
  `endif
  soc_top_env_config env_cfg;
  integer hierarchy_prt_hdl;
  uvm_table_printer printer;

  // Runtime HW stimulus, selected with +HW_STIM=<name>
  soc_top_stimulus m_stim;
  string           m_hw_stim;

  //------------------------------------------
  // Component Members
  //------------------------------------------
	soc_top_env m_env;
  //use for wait scoreboard compare completely
  //xxx_scoreboard_eot_callback eot_cb; 

  //rgm inst

  //------------------------------------------
  // Methods
  //------------------------------------------
  // Standard UVM Methods:
	extern function new(string name="soc_top_test_base", uvm_component parent);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual function void connect_phase(uvm_phase phase);
	extern virtual function void end_of_elaboration_phase(uvm_phase phase);
	extern virtual function void final_phase(uvm_phase phase);
  extern virtual task reset_phase(uvm_phase phase);
  extern virtual task post_reset_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  
  // User-Defined Methods:
  extern task clear_data_sram();
  extern task load_pgm();


endclass: soc_top_test_base

function soc_top_test_base::new(string name="soc_top_test_base", uvm_component parent);
	super.new(name, parent);
  //env config new
	env_cfg = soc_top_env_config::type_id::create("env_cfg");
  //rgm new

  uvm_config_db#(soc_top_env_config)::set(this, "*", "soc_top_env_config", env_cfg);
  //uvm_config_db#(soc_top_env_config)::set(null, "*", "soc_top_env_config", env_cfg);
endfunction: new

function void soc_top_test_base::connect_phase(uvm_phase phase);
	super.connect_phase(phase);
  //eot_cb = new();
  //uvm_callbacks #(xxx_scoreboard, xxx_scoreboard_callback)::add(m_env.xxx_scb, eot_cb);
  //uvm_callbacks #(xxx_scoreboard, xxx_scoreboard_callback)::delete(m_env.xxx_scb, eot_cb);
  //m_env.axi_system_env.set_report_severity_id_verbosity_hier( UVM_INFO, "send_write_resp"     , UVM_NONE);
  //m_env.axi_system_env.set_report_severity_id_verbosity_hier( UVM_INFO, "receive_write_addr"  , UVM_NONE);
  //m_env.axi_system_env.set_report_severity_id_verbosity_hier( UVM_INFO, "receive_write_data"  , UVM_NONE);
endfunction: connect_phase

function void soc_top_test_base::build_phase(uvm_phase phase);
  soc_top_error_demoter demoter = new;
  super.build_phase(phase);
  // To affect all reporters, use null for the object
  //uvm_report_cb::add(null, demoter); 
  
  // To affect some specific object use the specific reporter
  //uvm_report_cb::add(mytest.myenv.myagent.mydriver, demoter);
  
  // To affect some set of components using the component name
  //uvm_report_cb::add_by_name("*.*driver", demoter);
  
  //virtual clock+reset+interrupt interface config get
	if(!uvm_resource_db #(virtual clock_if#(300,0))::read_by_name("interface_pool", {"SOC_TOP", "_ehs_clk"}, env_cfg.ehs_clk)) begin
		`uvm_error("build_phase", "ehs_clk interface not found");
	end
	if(!uvm_resource_db #(virtual clock_if#(200,0))::read_by_name("interface_pool", {"SOC_TOP", "_els_clk"}, env_cfg.els_clk)) begin
		`uvm_error("build_phase", "els_clk interface not found");
	end
	if(!uvm_resource_db #(virtual clock_if#(100,0))::read_by_name("interface_pool", {"SOC_TOP", "_jtag_clk"}, env_cfg.jtag_clk)) begin
		`uvm_error("build_phase", "jtag_clk interface not found");
	end

  //env new
  m_env = soc_top_env::type_id::create("m_env", this);
  
  //Environment Configuration
  env_cfg.config_env();
  //set_report_max_quit_count(100);
  //uvm_top.set_timeout(1s, 0);

  //Sub_env Configuration
  

  //Set vip sequence

    //Set memory
  
  //Agent Configuration
  //End Agent Configuration
endfunction: build_phase

function void soc_top_test_base::end_of_elaboration_phase(uvm_phase phase);
  uvm_component comps[$];
  `ifdef UVM_VERSION
    uvm_root uvm_top;
  `endif
  super.end_of_elaboration_phase(phase);
  `ifdef UVM_VERSION
    if(`UVM_VERSION == 2016) uvm_top = uvm_root::get();
  `endif
  hierarchy_prt_hdl = $fopen("./hierarchy.txt", "w");
  uvm_top.find_all("*.m_env*", comps);
  foreach(comps[i]) begin
    $fwrite(hierarchy_prt_hdl, "%s\n", comps[i].get_full_name());
  end
  $fclose(hierarchy_prt_hdl);
  comps.delete();
  printer = new();
  printer.knobs.depth=3;
	uvm_top.print_topology(/*printer*/);
endfunction

function void soc_top_test_base::final_phase(uvm_phase phase);
  `ifdef UVM_VERSION
  uvm_root uvm_top;
  `endif
  `ifdef UVM_VERSION_1_1
  uvm_report_server server;
  `else
  uvm_default_report_server server;
  `endif
  int err_num;
	super.final_phase(phase);
	`uvm_info("TRACE", $sformatf("%m"), UVM_HIGH)
  `ifdef UVM_VERSION
  if(`UVM_VERSION == 2016) uvm_top = uvm_root::get();
  `endif
  printer = new();
  printer.knobs.depth=3;
	uvm_top.print_topology(printer);
  factory.print(0);
	`uvm_info(get_type_name(), $sformatf("Verbosity level is set to: %d", get_report_verbosity_level()), UVM_MEDIUM)
  `ifdef UVM_VERSION_1_1
  server = get_report_server();
  `else
  server = new();
  uvm_report_server::set_server(server);
  `endif
  err_num = server.get_severity_count(UVM_ERROR)
          + server.get_severity_count(UVM_FATAL);
          //+ server.get_severity_count(UVM_WAARNING);            
  if(!err_num) `uvm_info("UVM_CASE_PASS", "**********UVM TEST PASSED*********", UVM_NONE)
  else         `uvm_info("UVM_CASE_FAIL", "**********UVM TEST FAILED*********", UVM_NONE)
  $display("WUJIAN TEST END");
endfunction: final_phase

task soc_top_test_base::reset_phase(uvm_phase phase);
  super.reset_phase(phase);
  phase.raise_objection(this);
  clear_data_sram();
  phase.drop_objection(this);
endtask

task soc_top_test_base::post_reset_phase(uvm_phase phase);
    super.post_reset_phase(phase);
    phase.raise_objection(this);
    load_pgm();
    phase.drop_objection(this);
endtask

task soc_top_test_base::run_phase(uvm_phase phase);
    uvm_object_string_pool #(uvm_event#(bit[31:0])) evt_pool;
    uvm_event#(bit[31:0])                           e902_reload_program;
    super.run_phase(phase);
    evt_pool = uvm_object_string_pool #(uvm_event#(bit[31:0]))::get_global_pool();
    e902_reload_program = evt_pool.get("e902_reload_program");
    fork
        e902_reload_program.wait_ptrigger();
        force tb_top.dut.x_cpu_top.pad_core_rst_b = 0;
        #100ns;
        // Release the force instead of forcing 1: a permanent force masks the
        // PMU-generated CPU reset (e.g. the WDT system reset), so the CPU could
        // never be reset again after the initial program load.
        release tb_top.dut.x_cpu_top.pad_core_rst_b;
        $display("\t******START TO RELOAD PROGRAM******\n");
        load_pgm();
        $display("\t******RELOAD PROGRAM DONE******\n");
    join_none

    // Runtime HW stimulus (replaces the compile-time USE_* TB modules).
    // Started in parallel with the CPU program; the selected task waits for
    // PAD_MCURST itself, exactly like the legacy initial blocks did.
    if ($value$plusargs("HW_STIM=%s", m_hw_stim)) begin
        m_stim = new();
        fork
            m_stim.run(m_hw_stim);
        join_none
    end
endtask


task soc_top_test_base::clear_data_sram();
    for (int j = 0; j < 32'h4000; j++) begin
        tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_sms0_top.x_sms_sram.x_fpga_spram.x_fpga_byte3_spram.mem[j][7:0] = 8'h0;
        tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_sms0_top.x_sms_sram.x_fpga_spram.x_fpga_byte2_spram.mem[j][7:0] = 8'h0;
        tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_sms0_top.x_sms_sram.x_fpga_spram.x_fpga_byte1_spram.mem[j][7:0] = 8'h0;
        tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_sms0_top.x_sms_sram.x_fpga_spram.x_fpga_byte0_spram.mem[j][7:0] = 8'h0;
    end
endtask

task soc_top_test_base::load_pgm();
    reg [31:0] temp_mem[integer];
    reg [31:0] one_word;
    string pat_file;
    if (!$value$plusargs("PAT_FILE=%s", pat_file)) pat_file = "test.pat";
    `uvm_info("LOAD_PGM", $sformatf("loading program from %s", pat_file), UVM_LOW)
    $readmemh(pat_file, temp_mem);
    for (int k = 0; k < 32'h4000; k++) begin
        one_word = temp_mem[k];
        tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_isram_top.x_sms_sram.x_fpga_spram.x_fpga_byte3_spram.mem[k][7:0] = one_word[7:0];
        tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_isram_top.x_sms_sram.x_fpga_spram.x_fpga_byte2_spram.mem[k][7:0] = one_word[15:8];
        tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_isram_top.x_sms_sram.x_fpga_spram.x_fpga_byte1_spram.mem[k][7:0] = one_word[23:16];
        tb_top.dut.x_retu_top.x_smu_top.x_sms_top.x_isram_top.x_sms_sram.x_fpga_spram.x_fpga_byte0_spram.mem[k][7:0] = one_word[31:24];
    end
endtask
class ahb_base_test extends soc_top_test_base;

  // UVM Factory Registration Macro
  //
  `uvm_component_utils(ahb_base_test)

  //------------------------------------------
  // TLM/Component Members
  //------------------------------------------

  //------------------------------------------
  // Data Members
  //------------------------------------------

  //------------------------------------------
  // Methods
  //------------------------------------------
  // Standard UVM Methods:
	extern function new(string name = "ahb_base_test", uvm_component parent=null);
	extern virtual function void build_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual task main_phase(uvm_phase phase);

  // User-Defined Methods:
  extern virtual function void set_sequence();

endclass

function ahb_base_test::new(string name = "ahb_base_test", uvm_component parent=null);
  super.new(name,parent);
endfunction: new

function void ahb_base_test::build_phase(uvm_phase phase);
  `uvm_info("build_phase", "Entered...", UVM_LOW)
  super.build_phase(phase);

  set_sequence();
  `uvm_info("build_phase", "Exiting...", UVM_LOW)
endfunction: build_phase

task ahb_base_test::main_phase(uvm_phase phase);
  super.main_phase(phase);
endtask

task ahb_base_test::run_phase(uvm_phase phase);
  super.run_phase(phase);
endtask

function void ahb_base_test::set_sequence();
  //uvm_config_db#(uvm_object_wrapper)::set(this, "ahb_system_env.sequencer.main_phase", "default_sequence", ahb_master_write_read_directed_sequence::type_id::get());
  //uvm_config_db#(int unsigned)::set(this, "ahb_system_env.sequencer.ahb_master_write_read_directed_sequence", "sequence_length", 50);
endfunction


`ifdef  USE_AHB_VIP_TO_REPLACE


`endif


`endif

