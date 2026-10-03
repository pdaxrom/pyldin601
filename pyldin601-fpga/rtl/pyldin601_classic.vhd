library ieee;use ieee.std_logic_1164.all;
entity pyldin601_classic is
 port(
  flash_cs,flash_wp,flash_hold,flash_si,flash_sck:out std_logic;
  clk_ext:in std_logic;
  btn_resetn:in std_logic;
  seg_led_h:out std_logic_vector(8 downto 0);
  seg_led_l:out std_logic_vector(8 downto 0);
  led_rgb:out std_logic_vector(2 downto 0);
  rxd:in std_logic;
  txd:out std_logic;
  ps2clk:in std_logic;
  ps2dat:in std_logic;
  mss:out std_logic;
  msck:out std_logic;
  mosi:out std_logic;
  miso:in std_logic;
  SRAM_ADDR:out std_logic_vector(19 downto 0);
  SRAM_DATA:inout std_logic_vector(15 downto 0);
  SRAM_CE:out std_logic;
  SRAM_OE:out std_logic;
  SRAM_WE:out std_logic;
  SRAM_UB:out std_logic;
  SRAM_LB:out std_logic;
  tvout:out std_logic_vector(5 downto 0);
  audio:out std_logic_vector(1 downto 0)
 );end;
architecture board_hardware_lcd of pyldin601_classic is
 signal clk,pll_locked,cpu_clk,cpu_reset,cpu_hold,cpu_irq,cpu_rw,cpu_vma:std_logic;
 signal hd6303_en:std_logic;
 signal cpu_addr:std_logic_vector(15 downto 0);signal cpu_out,cpu_in:std_logic_vector(7 downto 0);
 component classic_system is
 port(
  clk:in std_logic;
  pll_locked:in std_logic;
  btn_resetn:in std_logic;
  cpu_rw:in std_logic;
  cpu_vma:in std_logic;
  cpu_addr:in std_logic_vector(15 downto 0);
  cpu_out:in std_logic_vector(7 downto 0);
  cpu_clk:out std_logic;
  cpu_reset:out std_logic;
  cpu_hold:out std_logic;
  cpu_irq:out std_logic;
  cpu_in:out std_logic_vector(7 downto 0);
  seg_led_h:out std_logic_vector(8 downto 0);
  seg_led_l:out std_logic_vector(8 downto 0);
  led_rgb:out std_logic_vector(2 downto 0);
  rxd:in std_logic;
  txd:out std_logic;
  ps2clk:in std_logic;
  ps2dat:in std_logic;
  mss:out std_logic;
  msck:out std_logic;
  mosi:out std_logic;
  miso:in std_logic;
  SRAM_ADDR:out std_logic_vector(19 downto 0);
  SRAM_DATA:inout std_logic_vector(15 downto 0);
  SRAM_CE:out std_logic;
  SRAM_OE:out std_logic;
  SRAM_WE:out std_logic;
  SRAM_UB:out std_logic;
  SRAM_LB:out std_logic;
  tvout:out std_logic_vector(5 downto 0);
  audio:out std_logic_vector(1 downto 0);
  hd6303_en:out std_logic
 );end component;
begin
 flash_cs<='1';flash_wp<='1';flash_hold<='1';flash_si<='0';flash_sck<='0';
 pll:entity work.classic_pll port map(clk_ext,clk,open,open,pll_locked);
 cpu:entity work.cpu6800 port map(cpu_clk,cpu_reset,cpu_rw,cpu_vma,cpu_addr,cpu_in,cpu_out,cpu_hold,'0',cpu_irq,'0',open,open,hd6303_en);
 system:classic_system port map(
  clk=>clk,
  pll_locked=>pll_locked,
  btn_resetn=>btn_resetn,
  cpu_rw=>cpu_rw,
  cpu_vma=>cpu_vma,
  cpu_addr=>cpu_addr,
  cpu_out=>cpu_out,
  cpu_clk=>cpu_clk,
  cpu_reset=>cpu_reset,
  cpu_hold=>cpu_hold,
  cpu_irq=>cpu_irq,
  cpu_in=>cpu_in,
  seg_led_h=>seg_led_h,
  seg_led_l=>seg_led_l,
  led_rgb=>led_rgb,
  rxd=>rxd,
  txd=>txd,
  ps2clk=>ps2clk,
  ps2dat=>ps2dat,
  mss=>mss,
  msck=>msck,
  mosi=>mosi,
  miso=>miso,
  SRAM_ADDR=>SRAM_ADDR,
  SRAM_DATA=>SRAM_DATA,
  SRAM_CE=>SRAM_CE,
  SRAM_OE=>SRAM_OE,
  SRAM_WE=>SRAM_WE,
  SRAM_UB=>SRAM_UB,
  SRAM_LB=>SRAM_LB,
  tvout=>tvout,
  audio=>audio,hd6303_en=>hd6303_en);
end;
