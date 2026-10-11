library ieee;use ieee.std_logic_1164.all;
entity tb_game_perf is generic(SPEED:integer:=0;FRAMES:integer:=12;MUSIC:integer:=1;STRESS:integer:=0);end;
architecture test of tb_game_perf is
 component game_perf_fixture is
 generic(SPEED:integer:=0;FRAMES:integer:=12;MUSIC:integer:=1;STRESS:integer:=0);
 port(cpu_rw,cpu_vma:in std_logic;cpu_addr:in std_logic_vector(15 downto 0);cpu_out:in std_logic_vector(7 downto 0);
 debug_state:in std_logic_vector(71 downto 0);debug_opcode:in std_logic_vector(7 downto 0);debug_decode:in std_logic;
 cpu_clk,cpu_reset,cpu_hold,cpu_irq,hd:out std_logic;cpu_in:out std_logic_vector(7 downto 0));end component;
 signal rw,vma,clk,reset,hold,irq,hd,decode:std_logic;signal address:std_logic_vector(15 downto 0);
 signal din,dout,opcode:std_logic_vector(7 downto 0);signal registers:std_logic_vector(71 downto 0);
begin
 fixture:game_perf_fixture generic map(SPEED,FRAMES,MUSIC,STRESS) port map(rw,vma,address,dout,registers,opcode,decode,clk,reset,hold,irq,hd,din);
 cpu:entity work.cpu6800_lockstep port map(clk,reset,rw,vma,address,din,dout,hold,'0',irq,'0',open,registers,opcode,decode,open,hd);
end;
