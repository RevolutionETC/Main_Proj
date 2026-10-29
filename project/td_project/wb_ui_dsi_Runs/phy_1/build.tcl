if {[catch {
 source {C:/APP2/ALTD/doc/scripts/DefaultFlow.tcl}
 source ../../../tools/finalize_timing.tcl
 set_param bitgen compress off
 bitgen -bit wb_ui_dsi.bit
 set_param bitgen compress on
 bitgen -bit wb_ui_dsi.bit
} taskError]} {puts stderr $taskError; exit 1}
exit