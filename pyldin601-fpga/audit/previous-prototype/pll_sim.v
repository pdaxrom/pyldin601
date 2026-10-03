// Simulation clock boundary only. Does not model EHXPLLJ or validate PLL timing.
module classic_pll(input CLKI,output CLKOP,CLKOS,CLKOS2,LOCKED);
assign CLKOP=CLKI;assign CLKOS=0;assign CLKOS2=0;assign LOCKED=1;
endmodule
