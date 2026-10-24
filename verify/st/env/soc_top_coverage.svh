`ifndef SOC_TOP_FUNC_COV__SV
`define SOC_TOP_FUNC_COV__SV
class soc_top_coverage extends uvm_component;
  `uvm_component_utils(soc_top_coverage)

  uvm_analysis_imp #(ahb_seq_item, soc_top_coverage) cov_imp;
  soc_top_env_config env_cfg;
  ahb_seq_item tr;

  typedef enum {
    REG_ISRAM, REG_DSRAM, REG_DMA, REG_TIMER, REG_WDT, REG_PWM,
    REG_USI0, REG_RTC, REG_GPIO, REG_USI1, REG_DUMMY, REG_OTHER
  } region_e;

  function region_e addr_region(bit [31:0] a);
    if (a inside {[32'h0000_0000:32'h0000_ffff]}) return REG_ISRAM;
    else if (a inside {[32'h2000_0000:32'h2000_ffff]}) return REG_DSRAM;
    else if (a inside {[32'h4000_0000:32'h4000_0fff]}) return REG_DMA;
    else if (a inside {[32'h5000_0000:32'h5000_7fff]}) return REG_TIMER;
    else if (a inside {[32'h5000_8000:32'h5000_8fff]}) return REG_WDT;
    else if (a inside {[32'h5001_c000:32'h5001_cfff]}) return REG_PWM;
    else if (a inside {[32'h5002_8000:32'h5002_8fff]}) return REG_USI0;
    else if (a inside {[32'h6000_4000:32'h6000_4fff]}) return REG_RTC;
    else if (a inside {[32'h6001_8000:32'h6001_8fff]}) return REG_GPIO;
    else if (a inside {[32'h6002_8000:32'h6002_8fff]}) return REG_USI1;
    else if (a inside {[32'h6000_0000:32'h6002_ffff]}) return REG_DUMMY;
    else return REG_OTHER;
  endfunction

  covergroup ahb_cov;
    option.name = "ahb_transaction_cov";
    cp_kind: coverpoint tr.kind {
      bins read  = {READ};
      bins write = {WRITE};
    }
    cp_region: coverpoint addr_region(tr.addr) {
      bins isram = {REG_ISRAM};
      bins dsram = {REG_DSRAM};
      bins dma   = {REG_DMA};
      bins timer = {REG_TIMER};
      bins wdt   = {REG_WDT};
      bins pwm   = {REG_PWM};
      bins usi0  = {REG_USI0};
      bins rtc   = {REG_RTC};
      bins gpio  = {REG_GPIO};
      bins usi1  = {REG_USI1};
      bins dummy = {REG_DUMMY};
      bins other = {REG_OTHER};
    }
    cp_size: coverpoint tr.size {
      bins word = {WORD};
    }
    cp_resp: coverpoint tr.resp {
      bins okay = {OKAY};
    }
    cp_busy: coverpoint tr.busy[0] {
      bins zero = {0};
      bins low  = {[1:3]};
      bins mid  = {[4:8]};
      bins high = {[9:$]};
    }
    cx_kind_region: cross cp_kind, cp_region;
  endgroup

  extern function new(string name="soc_top_coverage", uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void write(ahb_seq_item req);
endclass: soc_top_coverage

function soc_top_coverage::new(string name="soc_top_coverage", uvm_component parent);
  super.new(name, parent);
  cov_imp = new("cov_imp", this);
  ahb_cov = new();
  ahb_cov.set_inst_name({get_full_name(), ".ahb_cov"});
endfunction: new

function void soc_top_coverage::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db#(soc_top_env_config)::get(this, "*", "soc_top_env_config", env_cfg))
    `uvm_error("CFGERR", "environment config is not set to func_cov!")
endfunction: build_phase

function void soc_top_coverage::write(ahb_seq_item req);
  tr = req;
  if (tr.busy.size() == 0) tr.busy = new[1];
  ahb_cov.sample();
endfunction: write

`endif
