set ::env(DESIGN_NAME) "top"
# 建議：把 RTL 放 src/ 會最乾淨
# 如果你還沒整理，也可先用 "dir::." 直接吃當前資料夾的 .v
set ::env(VERILOG_FILES) [glob \
    $::env(DESIGN_DIR)/src/*.v \
]

set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "15.625"
set ::env(SDC_FILE) "$::env(DESIGN_DIR)/constraints.sdc"

# 保守一點，避免 placement/routing 卡住
set ::env(FP_CORE_UTIL) 35
set ::env(PL_TARGET_DENSITY) 0.45
# Flow switches
set ::env(RUN_CTS) 1
set ::env(RUN_ROUTING) 1
