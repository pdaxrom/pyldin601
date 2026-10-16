library ieee;use ieee.std_logic_1164.all;
entity tb_dma_bios is generic(SPEED:integer:=0;MODEL_A:integer:=0;HD:integer:=1);end;
architecture test of tb_dma_bios is
 component dma_bios_fixture is
 generic(SPEED:integer:=0;MODEL_A:integer:=0;HD:integer:=1);
 port(cpu_rw,cpu_vma:in std_logic;cpu_addr:in std_logic_vector(15 downto 0);cpu_out,cpu_cc:in std_logic_vector(7 downto 0);
 cpu_clk,cpu_reset,cpu_hold,cpu_irq:out std_logic;cpu_in:out std_logic_vector(7 downto 0);hd6303_en:out std_logic);end component;
 signal rw,vma,clk,reset,hold,irq,hd_mode:std_logic;signal address:std_logic_vector(15 downto 0);signal din,dout,cc:std_logic_vector(7 downto 0);
begin
 fixture:dma_bios_fixture generic map(SPEED,MODEL_A,HD) port map(rw,vma,address,dout,cc,clk,reset,hold,irq,din,hd_mode);
 cpu:entity work.cpu6800 port map(clk,reset,rw,vma,address,din,dout,hold,'0',irq,'0',open,cc,hd_mode);
end;
