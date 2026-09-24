############################################################################
# create_project.tcl
#
# Regenerates the Vivado project for this sample from source. Keeping only
# sources + this script under version control (instead of the binary .xpr
# project directory) is the standard way to keep an FPGA project
# git-friendly.
#
# Usage (from the Vivado Tcl Console or `vivado -mode batch -source`):
#   cd scripts
#   source create_project.tcl
#
# Then open ../vivado/basys3_sample_project.xpr in the Vivado GUI, or
# continue in batch mode with synth_design / impl / write_bitstream.
############################################################################

set proj_name   "basys3_sample_project"
set proj_dir    "../vivado"
set part        "xc7a35tcpg236-1"
#Not working
#set board_part  "digilentinc.com:basys3:part0:1.2"

create_project $proj_name $proj_dir -part $part -force

# Board part is optional and only takes effect if the Basys 3 board files
# are installed in this Vivado install; ignore failure if not.
if {[catch {set_property board_part $board_part [current_project]} err]} {
    puts "NOTE: could not set board_part ($err) - continuing with part-only flow."
}

add_files {../src/top.v}
add_files {../src/seven_seg_hex.v}
add_files {../src/clock_divider.v}
add_files {../sim/top_tb.v}
add_files -fileset constrs_1 {../constraints/Basys3_Master.xdc}


set_property top top [current_fileset]
set_property top top_tb [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project '$proj_name' created at $proj_dir/$proj_name.xpr"
puts "Open it in the Vivado GUI, or run synth_design / launch_runs from here."
