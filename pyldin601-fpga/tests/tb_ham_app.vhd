library ieee;use ieee.std_logic_1164.all;
entity tb_ham_app is generic(SPEED:integer:=0;MODEL_A:integer:=0);end;
architecture test of tb_ham_app is
 component ham_app_fixture is
 generic(SPEED:integer:=0;MODEL_A:integer:=0);
 port(cpu_rw,cpu_vma:in std_logic;cpu_addr:in std_logic_vector(15 downto 0);cpu_out:in std_logic_vector(7 downto 0);
 cpu_clk,cpu_reset,cpu_hold,cpu_irq,cpu_hd:out std_logic;cpu_in:out std_logic_vector(7 downto 0));end component;
 signal rw,vma,clk,reset,hold,irq,hd:std_logic;signal address:std_logic_vector(15 downto 0);signal din,dout:std_logic_vector(7 downto 0);
begin
 fixture:ham_app_fixture generic map(SPEED,MODEL_A) port map(rw,vma,address,dout,clk,reset,hold,irq,hd,din);
 cpu:entity work.cpu6800 port map(clk,reset,rw,vma,address,din,dout,hold,'0',irq,'0',open,open,hd);
end;
