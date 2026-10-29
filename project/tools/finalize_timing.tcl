# Adapted from Lproject's TIMING_RECOVERY.tcl. Physical changes only.
# All clock periods, CDC maximum datapath bounds and remaining checks stay active.
proc final_slacks {} {
 global prj_name
 set f [open ${prj_name}_pr.timing r]
 set text [read $f]
 close $f
 if {![regexp {SWNS:\s*(-?[0-9.]+)ns} $text all sw] ||
     ![regexp {HWNS:\s*(-?[0-9.]+)ns} $text all hw] ||
     ![regexp {Period Check WNS:\s*(-?[0-9.]+)ns} $text all period]} {
  error "Missing final setup/hold/period report"
 }
 return [list $sw $hw $period]
}
set slacks [final_slacks]
if {[lindex $slacks 1] < 0} {
 puts "FINAL_TIMING: standalone hold repair: $slacks"
 fix_hold
 set_param route fix_hold on
 update_timing -mode final
 report_timing_summary -file ${prj_name}_pr.timing
 report_timing_exception -file ${prj_name}_exception.timing
 report_area -io_info -file ${prj_name}_phy.area
 report_timing_status -file ${prj_name}_phy.ts
 export_db ${prj_name}_pr.db
 set slacks [final_slacks]
}
if {[lindex $slacks 0] < 0 || [lindex $slacks 1] < 0} {
 puts "FINAL_TIMING: optimizing remaining timed paths: $slacks"
 phys_opt -post_route -effort high
 fix_hold
 update_timing -mode final
 report_timing_summary -file ${prj_name}_pr.timing
 report_timing_exception -file ${prj_name}_exception.timing
 report_area -io_info -file ${prj_name}_phy.area
 report_timing_status -file ${prj_name}_phy.ts
 export_db ${prj_name}_pr.db
}
set slacks [final_slacks]
if {[lindex $slacks 0] < 0 || [lindex $slacks 1] < 0 || [lindex $slacks 2] < 0} {
 error "Final timing failed: setup/hold/period $slacks; bitstream rejected"
}
report_route_status -file ${prj_name}_route_status.rpt
report_route_status -drc -file ${prj_name}_route_drc.rpt
puts "FINAL_TIMING: period check [lindex $slacks 2] ns"
# Preserve the original PASS record format for existing build-log consumers.
set slacks [lrange $slacks 0 1]
puts "PASS FINAL_TIMING: setup/hold $slacks ns"
