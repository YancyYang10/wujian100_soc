`ifndef _TOP_CFG_SV_
`define _TOP_CFG_SV_

class top_cfg extends uvm_object;

    // === Agent instance active/passive config ===
    uvm_active_passive_enum axi_master_agt_is_active = UVM_ACTIVE;
    uvm_active_passive_enum apb_slave_agt_is_active = UVM_ACTIVE;
    uvm_active_passive_enum cfg_apb_agt_is_active = UVM_ACTIVE;
    uvm_active_passive_enum intr_mon_agt_is_active = UVM_PASSIVE;
    uvm_active_passive_enum debug_mon_agt_is_active = UVM_PASSIVE;

    int is_active;
    int scb_en;
    int timeout_cycles;

    `uvm_object_utils_begin(top_cfg)
//        `uvm_field_string(xxx, UVM_DEFAULT)
//        `uvm_field_sarray_int(xxx, UVM_DEFAULT)
//        `uvm_field_array_int(xxx, UVM_DEFAULT)
//        `uvm_field_queue_int(xxx, UVM_DEFAULT)
//        `uvm_field_aa_int_string(xxx, UVM_DEFAULT)
//        `uvm_field_aa_int_int(xxx, UVM_DEFAULT)

//        `uvm_field_int(is_active, UVM_DEFAULT)
//        `uvm_field_int(scb_en, UVM_DEFAULT)
//        `uvm_field_int(timeout_cycles, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "top_cfg");
        super.new(name);
    endfunction

endclass

`endif
