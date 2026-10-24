######################################################################
export LIGHT_ROOT := $(shell pwd)
#### 	for setting
TB_TOP 					?= tb_top
#VERDI_HOME 				?= /opt/synopsys/verdi/verdi/Verdi_O-2018.09-SP2
#VCS_HOME 				?= /opt/synopsys/vcs/vcs-mx/O-2018.09-SP2
#UVM_HOME 				?= /opt/synopsys/vcs/vcs-mx/O-2018.09-SP2/etc/uvm-1.1

######################################################################
#### 	file lists
RTL_FLIST 				?= rtl.f
TB_FLIST 				?= tb.f

######################################################################
#### 	Regression Script Support Variables
# Test case name
tc 					?= soc_top_for_c_case_test
sc 					?= timer/timer_test.c
SC_STEM 				:= $(basename $(notdir $(sc)))
PAT_FILE 				?= $(SC_STEM).pat
#addr_map/map_test.c
#gpio/gpio_test.c
#had_soc/e902_had_test.c
#pwm/pwm_test.c
#usi_i2c/usi_i2c_test.c
#usi_spi/usi_spi_test.c
#usi_uart/usi_uart_test.c
#dma/dma_test.c
#rtc/rtc_test.c
#timer/timer_test.c
#wdt/wdt_test.

# Simulation mode (for compilation product naming: simv_<mode>)
mode 					?= soc_test

# Runtime HW stimulus selected in the UVM testcase (+HW_STIM=<name>).
# Replaces the compile-time USE_* subsystem modes; empty = no extra stimulus.
#   make sim mode=soc_test sc=gpio/gpio_test.c stim=gpio
# Note: the regression parser lowercases custom keys, hence the lowercase name.
stim 					?=

# Random seed (auto-generated if not specified)
# Debug:  make sim seed=123   (command-line seed overrides the default)
# Regression: omit seed (or drop seed= from case.lst) to get a random one.
seed 					?= $(shell date +%s%N | cut -c11-19)

# UVM verbosity level
pl 						?= UVM_MEDIUM

# Waveform dump switch (1=on, 0=off)
wave 					:= 1

# Coverage switch (1=on, 0=off)
cov 					:= 1

# Output directory (supports regression script RESULT_DIR)
RESULT_DIR 				:= out/$(mode)

# Coverage arguments passed by regression script
COV_ARGS 				?=

# User-defined compile options (can be extended based on mode)
udc 					?=
# User-defined run options (can be extended based on mode)
udr 					?=

# VIP DPI shared library (1=link ./test_start)
DPI 					?= 0

# Compiled simulator name (based on mode)
SIMV_NAME 				?= simv_$(mode)

export wave
export tc
export sc
export seed
export mode
export RESULT_DIR
export PAT_FILE

######################################################################
#### 	MODE-based option extension
# Automatically add compile/run options based on mode keywords
# Pattern: if mode contains keyword, append corresponding options

# Demo: MODE keyword -> compile/run options mapping
# Uncomment and customize as needed

# Example 1: If mode contains "rtl_sim", add RTL simulation options
# ifneq ($(findstring rtl_sim,$(mode)),)
#     udc += +define+RTL_SIM
#     udr += +UVM_VERBOSITY=UVM_HIGH
# endif

# Example 2: If mode contains "gate_sim", add gate-level simulation options
# ifneq ($(findstring gate_sim,$(mode)),)
#     udc += +define+GATE_SIM +libext+.v
#     udr += +notimingcheck
# endif

# Example 3: If mode contains "post_layout", add post-layout options
# ifneq ($(findstring post_layout,$(mode)),)
#     udc += +define+POST_LAYOUT +define+SDC_FILE
#     udr += +sdf_delay
# endif

# Example 4: If mode contains "low_power", add low-power simulation options
# ifneq ($(findstring low_power,$(mode)),)
#     udc += +define+LP_SIM
#     LP_SIM = 1
# endif

# Example 5: If mode contains "debug" or "dbg", enable debug options
# ifneq ($(filter %debug %dbg,$(mode)),)
#     DEBUG = 1
#     udc += +define+DEBUG_MODE
# endif

# Example 6: Multiple keywords with OR logic
# ifneq ($(findstring fast,$(mode)),)
#     udr += +UVM_VERBOSITY=UVM_LOW
# else ifneq ($(findstring slow,$(mode)),)
#     udr += +UVM_VERBOSITY=UVM_HIGH
# endif 

ifneq ($(findstring nocpu,$(mode)),)
	udc += +define+USE_AHB_VIP_TO_REPLACE
endif
ifneq ($(findstring gpio,$(mode)),)
	udc += +define+USE_APB1+USE_APB1_GPIO
endif
ifneq ($(findstring spi,$(mode)),)
	udc += +define+USE_APB0+USE_APB0_USI+USI_SPI
endif
ifneq ($(findstring i2c,$(mode)),)
	udc += +define+USE_APB0+USE_APB0_USI+USI_I2C
endif
ifneq ($(findstring uart,$(mode)),)
	udc += +define+USE_APB0+USE_APB0_USI+USI_UART
endif
ifneq ($(findstring pwm,$(mode)),)
	udc += +define+USE_APB0+USE_APB0_PWM
endif
ifneq ($(findstring map,$(mode)),)
	udc += +define+USE_TOP_SIM+USE_ADDR_MAP
endif
ifneq ($(findstring e902,$(mode)),)
	udc += +define+USE_TOP_SIM+USE_HAD
endif
ifneq ($(findstring ahb_hs,$(mode)),)
	udc += +define+USE_AHB_HS+USE_SOC_DMA
endif
ifneq ($(findstring ahb_ls,$(mode)),)
	udc += +define+USE_AHB_LS
endif
ifneq ($(findstring gate,$(mode)),)
	udc += +define+USE_GATE_SIM+USE_SDF_SIM
endif
# Subsystem stimulus is now selected at runtime with +HW_STIM=<name> (see
# tc/soc_top_stimulus.svh), so the APB0/APB1/TOP_SIM modes are no longer needed
# by the regression. The per-IP mode rules above are kept for isolated debug.
# All AHB_HS/AHB_LS/GATE TB modules are empty placeholders (no netlist/SDF),
# so the three structural smokes share one build.
ifneq ($(findstring struct,$(mode)),)
	udc += +define+USE_AHB_HS+USE_SOC_DMA+USE_GATE_SIM+USE_SDF_SIM
endif
ifneq ($(findstring all,$(mode)),)
	udc += +define+USE_TOP_SIM+USE_HAD+USE_APB1+USE_APB1_GPIO+USE_APB0+USE_APB0_USI+USI_SPI+USI_I2C+USI_UART+USE_APB0_PWM+USE_ADDR_MAP+USE_AHB_HS+USE_SOC_DMA+USE_AHB_LS+USE_GATE_SIM+USE_SDF_SIM
endif


######################################################################
#### 	generic simulation control
VCS_OPTS 				+= vcs -sverilog -full64 -kdb -DVCS -lca -ntb_opts uvm-1.2 +vpi +lint=TFIPC,PCWM +vcs+lic+wait +debug_region=cell+lib +vcs+initreg+random 
#VCS_OPTS_VERDI 			=  -debug_access+all 
VCS_OPTS_VERDI 			+= -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab \
						   $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a 
VCS_OPTS_UVM 			+=  +incdir+$(UVM_HOME)/src \
						   $(UVM_HOME)/src/uvm.sv \
						   $(UVM_HOME)/src/uvm_pkg.sv 
						   #$(UVM_HOME)/src/dpi/uvm_dpi.cc 
						   #-CFLAGS -DVCS
ifeq ($(wave),1)
	VCS_OPTS_VERDI 		+=  -debug_access+all
else ifneq ($(stim),)
	# Runtime stimulus uses uvm_hdl_* (VPI backdoor), which needs read/write
	# access even when waveforms are off.
	VCS_OPTS_VERDI 		+=  -debug_access+all
else ifneq ($(HDL_ACCESS),)
	# Regression compiles one simv per mode before the per-case +HW_STIM is
	# known, so it passes HDL_ACCESS=1 via global_args.
	VCS_OPTS_VERDI 		+=  -debug_access+all
else
	VCS_OPTS_VERDI 		+=  -debug_pp
endif


#default options
VCS_COMP_LOG 			?= compile_$(mode).log
VCS_TIMESCALE 			?= 1ns/1ps
VCS_TB_DEFINES 			?= +define+UVM_PACKER_MAX_BYTES=1500000 +define+DEMO_MAKEFILE +define+UVM_EVENT_CALLBACK_FIX +define+SOC_TOP_ASSERTIONS
VCS_TB_ARGS 			?=
VCS_TIMING_MODE 		?= +notimingcheck +nospecify

SIM_LOG 				?= $(SC_STEM)_$(tc)_$(seed).log
SIM_OTHERS 				?= +UVM_NO_RELNOTES
SIM_STRIP_SEL 			?=
COV_DB_NAME 			?= $(SC_STEM)_$(tc)_$(seed)


######################################################################
#### UPF_FILE
LP_SIM 					?= 0
ifeq ($(LP_SIM),1)
	UPF_FILE            =  ../../../bench/test_upf/top.upf
else
	UPF_FILE            =  ../../../upf/tsmc12_top.upf
endif

#### debug control
DEBUG 					?= 0
ifeq ($(DEBUG),1)
	DVE_DEBUG           =  -gui
else
	DVE_DEBUG           =
endif


#### COV setting
# If cov=1 and COV_ARGS is provided, use external coverage args
# Otherwise use default coverage options
ifeq ($(cov),1)
	ifneq ($(COV_ARGS),)
		# Use coverage args from regression script
		VCS_OPTS_COV 	=  -lca $(COV_ARGS) -cm_name $(COV_DB_NAME) -cm_hier cm.cfg -cm_assert_hier cm_assert.cfg
		SIM_OPTS_COV 	=  $(COV_ARGS) -cm_name $(COV_DB_NAME) -cm_hier cm.cfg -cm_assert_hier cm_assert.cfg
	else
		# Default coverage options
		VCS_OPTS_COV 	=  -lca -cm line+cond+fsm+branch+tgl+assert -cm_name $(COV_DB_NAME) -cm_hier cm.cfg -cm_assert_hier cm_assert.cfg
		SIM_OPTS_COV 	=  -cm line+cond+fsm+branch+tgl+assert -cm_name $(COV_DB_NAME) -cm_hier cm.cfg -cm_assert_hier cm_assert.cfg
	endif
else
	VCS_OPTS_COV 		=
	SIM_OPTS_COV 		=
endif

COV_RPT 				?= 0
ifeq ($(COV_RPT),1)
	URG_OPTS 			=  urg -dir $(RESULT_DIR)/$(SIMV_NAME).vdb -report $(RESULT_DIR)/$(SIMV_NAME)_cov_rpt
else
	URG_OPTS 			=
endif

#### SEED setting
ifdef seed
	SIM_OPTS_SEED 		=  +ntb_random_seed=$(seed)
else
	SIM_OPTS_SEED 		=  +ntb_random_seed_automatic
endif

#### lp control


######################################################################
#### local variables and final compilation/simulation option
COMPOPTS 				=  $(VCS_OPTS) $(VCS_OPTS_VERDI) $(VCS_OPTS_UVM) $(VCS_OPTS_VIP)
COMPOPTS 				+= $(VCS_TIMING_MODE)
COMPOPTS 				+= -o $(RESULT_DIR)/$(SIMV_NAME)
COMPOPTS 				+= -timescale=$(VCS_TIMESCALE)
COMPOPTS 				+= +define+$(VCS_TB_DEFINES)
COMPOPTS 				+= $(udc)
COMPOPTS 				+= -top $(TB_TOP)
COMPOPTS 				+= -f ../cfg/$(RTL_FLIST) -f ../cfg/$(TB_FLIST)
COMPOPTS 				+= $(DVE_DEBUG)
COMPOPTS 				+= $(VCS_OPTS_COV)
COMPOPTS 				+= $(UPF_OPTS)
COMPOPTS 				+= +define+TSMC_CM_NO_WARNING+TSMC_DISABLE_CONTENTION_MESSAGE

SIMOPTS 				=  $(RESULT_DIR)/$(SIMV_NAME)
SIMOPTS 				+= +UVM_TESTNAME=$(tc) +vcs+initreg+0
SIMOPTS 				+= +PAT_FILE=$(RESULT_DIR)/$(PAT_FILE)
SIMOPTS 				+= $(SIM_STRIP_SEL)
SIMOPTS 				+= +UVM_VERBOSITY=$(pl)
SIMOPTS 				+= $(if $(stim),+HW_STIM=$(stim))
SIMOPTS 				+= $(DVE_DEBUG) $(SIM_OPTS_WAVE) $(SIM_OPTS_COV) $(SIM_OPTS_SEED)
SIMOPTS 				+= $(VCS_TB_ARGS)
SIMOPTS 				+= $(udr)
SIMOPTS 				+= $(SIM_OTHERS)
SIMOPTS 				+= +licp
SIMOPTS 				+= -ucli -i run.tcl
# UVM transaction tracing writes novas.fsdb into the shared run directory.
# Only enable it when waveforms are requested; in regression (wave=0) parallel
# simulations would overwrite each other's novas.fsdb and crash at end of sim.
ifeq ($(wave),1)
SIMOPTS 				+= +UVM_VERDI_TRACE="UVM_AWARE+HIER"
endif

ifeq ($(DPI),1)
	SIMOPTS 			+= -sv_lib ./test_start
endif

#### VCS LOG setting
VCS_LOG 				?= 1
ifeq ($(VCS_LOG),1)
	COMPOPTS 			+= -l $(RESULT_DIR)/$(VCS_COMP_LOG)
	SIMOPTS 			+= -l $(RESULT_DIR)/$(SIM_LOG)
else
	COMPOPTS 			+=
	SIMOPTS 			+=
endif

######################################################################
#### global rule
all: compile sim

prepare:
	mkdir -p $(RESULT_DIR)
	cp Makefile run.tcl cm.cfg cm_assert.cfg ../cfg/rtl.f ../cfg/tb.f $(RESULT_DIR)/

sw_comp: prepare
	../script/make_hex $(sc)
	cp ./$(PAT_FILE) $(RESULT_DIR)/

vipccomp: prepare
	../script/make_hex_for_vip $(sc)

compile: prepare
	$(COMPOPTS)

sim: sw_comp
	@	echo "=================================================";
	@ 	echo "          Current swts: $(sc)";
	@ 	echo "          Current hwts: $(tc)";
	@ 	echo "          Current seed: $(seed)";
	@ 	echo "          Current mode: $(mode)";
	@	echo "=================================================";
	$(SIMOPTS)

urg: prepare
	$(URG_OPTS)

clean:
	rm -rf *log csrc *key

distclean: clean
	rm -rf $(RESULT_DIR)

######################################################################
#### Help target
help:
	@	echo "Usage: make [target] [VAR=value]"
	@	echo ""
	@	echo "Targets:"
	@	echo "  all         - Software & Hardware Compile and simulate (default)"
	@	echo "  sw_comp     - Software Compile only"
	@	echo "  compile     - Hardware Compile only"
	@	echo "  sim         - Simulate only"
	@	echo "  urg         - Generate coverage report"
	@	echo "  clean       - Remove generated files"
	@	echo "  distclean   - Remove all generated files and output directory"
	@	echo ""
	@	echo "Variables:"
	@	echo "  tc          - Test case name (default: tc_sanity)"
	@	echo "  sc          - C case name (default: hello_world)"
	@	echo "  mode        - Simulation mode (default: default)"
	@	echo "  seed        - Random seed (default: timestamp)"
	@	echo "  pl          - UVM verbosity (default: UVM_MEDIUM)"
	@	echo "  wave        - Waveform dump (default: 1)"
	@	echo "  cov         - Coverage enable (default: 1)"
	@	echo "  RESULT_DIR  - Output directory (default: out)"
	@	echo "  COV_ARGS    - Coverage arguments"
	@	echo "  udc         - User-defined compile options"
	@	echo "  udr         - User-defined run options"
	@	echo ""
	@	echo "Examples:"
	@	echo "  make sim tc=tc_sanity sc=hello_world seed=12345"
	@	echo "  make compile mode=rtl_sim COV_ARGS=\"-cm line+cond\""
	@	echo "  make all RESULT_DIR=sim_out" 
