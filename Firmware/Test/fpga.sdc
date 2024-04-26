# Oscillator clock input
create_clock -period 50MHz [get_ports clk50]

# Slot clock input
#create_clock -period 3.58MHz [get_ports pSltClk]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty
