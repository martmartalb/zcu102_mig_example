

create_waiver -internal -user ddr4_v2_2_28 -scope -type METHODOLOGY -id {TIMING-17} -description "Ignore the TIMING-17 Critical Warning for sl_iport_i" -objects [get_pins -quiet -leaf -of [get_nets -quiet u_ddr4_*/inst/u_ddr4_mem_intfc/u_ddr_cal_top/u_ddr_cal/U_XSDB_SLAVE/sl_iport_i*] -filter {DIRECTION==IN}]

#Pin LOC constraints for the status signals init_calib_complete and data_compare_error

#Ports related to the System

# Bank: 44 - GPIO_LED_0
set_property PACKAGE_PIN AG14 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property SLEW SLOW [get_ports {led[0]}]

# Bank: 44 - GPIO_LED_1
set_property PACKAGE_PIN AF13 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property SLEW SLOW [get_ports {led[1]}]

# Bank: 44 - GPIO_LED_2
set_property PACKAGE_PIN AE13 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property SLEW SLOW [get_ports {led[2]}]

# Bank: 44 - GPIO_LED_3
set_property PACKAGE_PIN AJ14 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property SLEW SLOW [get_ports {led[3]}]

set_property PACKAGE_PIN AM13 [get_ports sys_rst]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst]
