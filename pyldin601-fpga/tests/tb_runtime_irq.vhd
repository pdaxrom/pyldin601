library ieee;use ieee.std_logic_1164.all;
entity tb_runtime_irq is end;
architecture test of tb_runtime_irq is
 component runtime_irq_fixture is
 port(cpu_rw,cpu_vma:in std_logic;cpu_addr:in std_logic_vector(15 downto 0);cpu_out:in std_logic_vector(7 downto 0);
 cpu_clk,cpu_reset,cpu_hold,cpu_irq:out std_logic;cpu_in:out std_logic_vector(7 downto 0));end component;
 signal rw,vma,clk,reset,hold,irq:std_logic;signal address:std_logic_vector(15 downto 0);signal din,dout:std_logic_vector(7 downto 0);
begin
 fixture:runtime_irq_fixture port map(rw,vma,address,dout,clk,reset,hold,irq,din);
 cpu:entity work.cpu6800 port map(clk,reset,rw,vma,address,din,dout,hold,'0',irq,'0',open,open);
end;
