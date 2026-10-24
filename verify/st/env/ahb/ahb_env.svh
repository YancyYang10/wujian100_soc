class ahb_environment extends uvm_env;
  `uvm_component_utils(ahb_environment)
  
  ahb_pkg::ahb_agent mst_agent;
  ahb_pkg::ahb_agent slv_agent;

  // constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction // new
    
  
  virtual function void build_phase(uvm_phase phase);
    bit slv_agent_active = 1;
    super.build_phase(phase);
    void'(uvm_config_db#(bit)::get(this, "", "slv_agent_active", slv_agent_active));
    mst_agent = ahb_pkg::ahb_agent::type_id::create("mst_agent", this);
    slv_agent = ahb_pkg::ahb_agent::type_id::create("slv_agent", this);
    // SOC top drives hready/hresp/hrdata from the DUT; keep the slave monitor-only
    slv_agent.is_active = slv_agent_active ? UVM_ACTIVE : UVM_PASSIVE;
    `ifndef USE_AHB_VIP_TO_REPLACE
    // CPU mode: master is a passive monitor on the CPU m2 bus
    mst_agent.is_active = UVM_PASSIVE;
    `endif
    uvm_config_db#(bit)::set(this, "slv_agent", "is_slave", TRUE);
  endfunction // build_phase

  virtual task run_phase(uvm_phase phase);
    // disable slave agent's monitor transactions reporting
    slv_agent.set_tr_print(FALSE);
    `ifndef USE_AHB_VIP_TO_REPLACE
    mst_agent.set_tr_print(FALSE);
    `endif
  endtask // run_phase
  
endclass // ahb_test
