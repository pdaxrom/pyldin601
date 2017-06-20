module p601zero (
	input clk_ext,
	
	input  [3:0] switches,
	input  [3:0] keys,
	output [8:0] seg_led_h,
	output [8:0] seg_led_l,
	output [7:0] leds,
	output [2:0] rgb1,
	output [2:0] rgb2,
	
	input rxd,
	output txd,

	output[16:0] EXT_AD,
	inout[7:0] EXT_DQ,
	output EXT_WE_n,
	output EXT_OE_n,
	output SRAM_CS2,
	
	output sdcs,
	output mosi,
	output msck,
	input miso,
	
	output [1:0] tvout
);
	parameter OSC_CLOCK = 24000000;

	parameter CPU_CLOCK = 6000000;

	parameter CLK_DIV_PERIOD = (OSC_CLOCK / CPU_CLOCK) / 2;
	
	parameter LED_REFRESH_CLOCK = 50;
	
	parameter LED_DIV_PERIOD = (OSC_CLOCK / LED_REFRESH_CLOCK) / 2;

	wire clk_in;
	wire sys_clk_out;
	wire sys_clk;
	wire pixel_clk;
	
	reg [24:0] led_cnt;
	reg [1:0] led_anode;
	wire [7:0] seg_byte;
	
/*
	CPU related
 */

	reg sys_res = 1;
	wire sys_rw;	wire sys_vma;
	wire [15:0] AD;
	wire [7:0] DI;
	wire [7:0] DO;

	wire vpu_irq;
	wire simpleio_irq;
	wire uartio_irq;

	reg [3:0] sys_res_delay = 4'b1000;

	mcu_pll pll_impl(
		.CLKI(clk_ext),
		.CLKOP(clk_in),
		.CLKOS(sys_clk_out),
		.CLKOS2(pixel_clk)
	);

	always @ (posedge clk_in)
	begin		if (sys_res) led_anode <= 2'b01;
		else begin
			if (led_cnt == (LED_DIV_PERIOD - 1)) begin
				led_anode <= ~led_anode;
				led_cnt <= 0;
			end else led_cnt <= led_cnt + 1'b1;
		end
	end

	always @ (posedge sys_clk or negedge keys[3])
	begin
		if (!keys[3]) begin
			sys_res <= 1;
			sys_res_delay = 4'b1000;
		end else begin
			if (sys_res_delay == 4'b0000) begin
				sys_res <= 0;
			end else sys_res_delay <= sys_res_delay - 4'b0001;
		end
	end

	assign seg_led_h[8] = led_anode[1];
	assign seg_led_l[8] = led_anode[0];

	wire DS0 = (AD[15:5] == 11'b11100110000); // $E600
	wire DS1 = (AD[15:5] == 11'b11100110001); // $E620
	wire DS2 = (AD[15:5] == 11'b11100110010); // $E640
	wire DS3 = (AD[15:5] == 11'b11100110011); // $E660
	wire DS4 = (AD[15:5] == 11'b11100110100); // $E680
	wire DS5 = (AD[15:5] == 11'b11100110101); // $E6A0
	wire DS6 = (AD[15:5] == 11'b11100110110); // $E6C0
	wire DS7 = (AD[15:5] == 11'b11100110111); // $E6E0

	wire en_vpu = DS0; // $E600
	wire cs_vpu = en_vpu && sys_vma;
	wire [7:0] vpud;
	
	wire [15:0] VADDR;
	wire vpu_vramcs;
	wire vpu_hold;

	vpu vpu_impl(
		.clk(sys_clk),
		.rst(sys_res),
		.irq(vpu_irq),
		.AD(AD[4:0]),
		.DI(DO),
		.DO(vpud),
		.rw(sys_rw),
		.cs(cs_vpu),
		.pixel_clk(pixel_clk),
		
		.VADDR(VADDR),
		.VDATA(EXT_DQ),
		.vramcs(vpu_vramcs),
		.hold(vpu_hold),
		
		.tvout(tvout)
	);

	wire [1:0] ints_mask;
	wire en_simpleio = DS5 && (AD[4] == 1'b0); // $E6A0
	wire cs_simpleio = en_simpleio && sys_vma;
	wire [7:0] simpleiod;
	simpleio simpleio1 (
		.clk(sys_clk),
		.rst(sys_res),
		.irq(simpleio_irq),
		.AD(AD[3:0]),
		.DI(DO),
		.DO(simpleiod),
		.rw(sys_rw),
		.cs(cs_simpleio),
		.clk_in(clk_in),
		.leds(leds),
		.led7hi(seg_led_h[7:0]),
		.led7lo(seg_led_l[7:0]),
		.rgb1(rgb1),
		.rgb2(rgb2),
		.switches(switches),
		.keys(keys),
		.ints_mask(ints_mask)
	);

	wire en_uartio = DS5 && (AD[4] == 1'b1); // $E6B0
	wire cs_uartio = en_uartio && sys_vma;
	wire [7:0] uartiod;
	uartio uartio1 (
		.clk(sys_clk),
		.rst(sys_res),
		.irq(uartio_irq),
		.AD(AD[2:0]),
		.DI(DO),
		.DO(uartiod),
		.rw(sys_rw),
		.cs(cs_uartio),
		.clk_in(clk_in),
		.rxd(rxd),
		.txd(txd)
	);

	wire en_sdcardio = DS6; // $E6C0
	wire cs_sdcardio = en_sdcardio && sys_vma;
	wire [7:0] sdcardiod;

	// write to external register
	assign sdcs = (cs_sdcardio && (AD[2:0] == 3'b011)) ? ((~sys_clk) & (~sys_rw)) : 1'b0;

	sdcardio sdcardio_impl(
		.clk(sys_clk),
		.rst(sys_res),
		.AD(AD[2:0]),
		.DI(DO),
		.DO(sdcardiod),
		.rw(sys_rw),
		.cs(cs_sdcardio),
		
		.clk_in(clk_in),
		
		.mosi(mosi),
		.msck(msck),
		.miso(miso)
	);

	wire en_pagesel = DS7; // $E6F0
	wire cs_pagesel = en_pagesel && sys_vma;
	wire [7:0] pageseld;
	wire [4:0] mempage;
	wire bram_disable;
	pagesel pagesel_imp (
		.clk(sys_clk),
		.rst(sys_res),
		.AD(AD[4:0]),
		.DI(DO),
		.DO(pageseld),
		.rw(sys_rw),
		.cs(cs_pagesel),
		.page(mempage),
		.bram_disable(bram_disable)
	);

	wire en_brom = (AD[15:11] == 5'b11111);
	wire cs_brom = en_brom && sys_vma;
	wire [7:0] bromd;
	mcu_rom brom (
		.OutClock(sys_clk),
		.Reset(sys_res),
		.OutClockEn(cs_brom),
		.Address(AD[10:0]),
		.Q(bromd)
	);

	wire en_bram = (AD[15:12] == 4'b0000) && (!bram_disable);
	wire cs_bram = en_bram && sys_vma;
	wire [7:0] bramd;
	mcu_ram bram (
		.clk(sys_clk),
		.AD(AD),
		.DI(DO),
		.DO(bramd),
		.rw(sys_rw),
		.cs(cs_bram)
	);

	wire en_ext = !(en_brom | en_bram | en_vpu | en_simpleio | en_uartio | en_sdcardio | en_pagesel);
	wire pageen = mempage[3] && (AD[15:13] == 3'b110) && (!(mempage[4] && (!sys_rw)));
	assign EXT_AD[16:0] = vpu_vramcs ? {1'b0, VADDR} :
						  pageen   ? {1'b1, mempage[2:0], AD[12:0]} : {1'b0, AD};

	assign EXT_OE_n = vpu_vramcs ? 1'b0 : ~((~sys_clk) &  (sys_rw));
	assign EXT_WE_n = vpu_vramcs ? 1'b1 : ~((~sys_clk) & (~sys_rw));
	assign EXT_DQ   = vpu_vramcs ? 8'bZ : (sys_rw) ? 8'bZ : DO;
 
	assign DI = en_ext      ? EXT_DQ:
				en_bram		? bramd:
				en_brom		? bromd:
				en_vpu		? vpud:
				en_simpleio	? simpleiod:
				en_uartio	? uartiod:
				en_sdcardio ? sdcardiod:
				en_pagesel  ? pageseld:
				8'b11111111;

	assign SRAM_CS2 = (en_ext && sys_vma) | vpu_vramcs;

//	reg [2:0] extbus_clkdiv_cnt;
//	reg dyn_clk;
//	always @ (posedge sys_clk_out) begin
//		if (extbus_clkdiv_cnt >= (((en_ext && sys_vma))?3'b001:3'b000)) begin
//			dyn_clk <= !dyn_clk;
//			extbus_clkdiv_cnt <= 0;
//		end else extbus_clkdiv_cnt <= extbus_clkdiv_cnt + 1'b1;
//	end

//	assign sys_clk = dyn_clk;
	assign sys_clk = sys_clk_out;

	wire cpu_hold = vpu_hold;
	wire cpu_irq = (simpleio_irq | uartio_irq | vpu_irq) & ints_mask[0];
	
	cpu68 mc6801 (
		.clk(sys_clk),
		.rst(sys_res),
		.irq(cpu_irq),
		.nmi(1'b0),
		.hold(cpu_hold),
		.halt(1'b0),
		.rw(sys_rw),
		.vma(sys_vma),
		.address(AD),
		.data_in(DI),
		.data_out(DO)
	);

endmodule
