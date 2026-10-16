library ieee;use ieee.std_logic_1164.all;
entity tb_mouse_driver is generic(SPEED:integer:=0;MODEL_A:integer:=0;HD:integer:=0;FAILURE:integer:=0);end;
architecture test of tb_mouse_driver is
 component mouse_driver_fixture is
 generic(SPEED:integer:=0;MODEL_A:integer:=0;HD:integer:=0;FAILURE:integer:=0);
 port(cpu_rw,cpu_vma:in std_logic;cpu_addr:in std_logic_vector(15 downto 0);cpu_out:in std_logic_vector(7 downto 0);
 cpu_clk,cpu_reset,cpu_hold,cpu_irq:out std_logic;cpu_in:out std_logic_vector(7 downto 0);hd6303_en:out std_logic);end component;
 signal rw,vma,clk,reset,hold,irq,hd_mode:std_logic;signal address:std_logic_vector(15 downto 0);signal din,dout:std_logic_vector(7 downto 0);
begin
 fixture:mouse_driver_fixture generic map(SPEED,MODEL_A,HD,FAILURE) port map(rw,vma,address,dout,clk,reset,hold,irq,din,hd_mode);
 cpu:entity work.cpu6800 port map(clk,reset,rw,vma,address,din,dout,hold,'0',irq,'0',open,open,hd_mode);
end;
