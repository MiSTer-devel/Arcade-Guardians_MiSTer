# Fitted production F0 sampler audit; run with quartus_sta -t this script.
package require ::quartus::project
package require ::quartus::sta
project_open Arcade-Guardians
create_timing_netlist
read_sdc
update_timing_netlist
foreach pattern {
    *graphics_sdram*sdram_input_samples*|ddio_ina*
    *graphics_sdram*sdram_input_samples*|dataout_l*
} {
    set count [get_collection_size [get_registers -nowarn $pattern]]
    puts "F0 AUDIT: $pattern = $count fitted registers"
    if {$count != 16} { error "Expected sixteen falling-edge captures and low-data retimers" }
}
set memory_clocks [get_clocks -nowarn {*emu|pll*PLL_OUTPUT_COUNTER*|divclk}]
# Quartus merged the identical nominal outputs in the verified private fit.
# One common counter or two equal counters is valid; neither changes phase.
set clock_count [get_collection_size $memory_clocks]
if {$clock_count < 1 || $clock_count > 2} { error "Expected fixed memory PLL counter(s)" }
foreach_in_collection memory_clock $memory_clocks {
    set period [get_clock_info -period $memory_clock]
    puts "F0 AUDIT: memory PLL clock period $period ns"
    if {abs($period - 14.5454545) > 0.002} { error "Memory frequency differs from 68.75 MHz" }
}
report_clocks -file output_files/sdram-f0-clocks.rpt
set report_file output_files/sdram-f0-client-paths.rpt
report_timing -setup -from [get_registers {*graphics_sdram*sdram_input_samples*|dataout_l*}] \
    -npaths 3 -detail full_path -file $report_file
set handle [open $report_file r]
set report_text [read $handle]
close $handle
if {![regexp {Found 3 setup paths \(0 violated\)} $report_text]} {
    error "Fitted F0 capture-to-client paths are missing or violating"
}
puts "PASS: sixteen fixed F0 input captures, baseline memory clocks and timed F0 client paths"
puts "NOTE: external SDRAM I/O remains unconstrained; this is an internal audit"
delete_timing_netlist
project_close
