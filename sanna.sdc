# Inform Quartus that port "clk" is running at 50 MHz (20ns period)
create_clock -name clk -period 20.000 [get_ports {clk}]

# Automatically handle the internal clock uncertainties
derive_clock_uncertainty