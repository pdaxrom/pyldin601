library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use std.env.all;
entity tb_cpu is end;
architecture test of tb_cpu is
 type bytes is array(0 to 65535)of std_logic_vector(7 downto 0);
 impure function load(path:string)return bytes is
  file f:text open read_mode is path;variable l:line;variable data:bytes;variable v:std_logic_vector(7 downto 0);
 begin for n in data'range loop readline(f,l);hread(l,v);data(n):=v;end loop;return data;end;
 signal memory:bytes:=load("build/cpu.mem");
 constant expected:bytes:=load("build/cpu.expected.mem");
 signal clk:std_logic:='0';signal reset:std_logic:='1';signal rw,vma:std_logic;
 signal address:std_logic_vector(15 downto 0);signal din,dout:std_logic_vector(7 downto 0);
 signal irq:std_logic:='0';
 signal hold:std_logic:='0';signal alu:std_logic_vector(15 downto 0);signal cc:std_logic_vector(7 downto 0);
 signal cycles:integer:=0;
 begin
 clk<=not clk after 5 ns;
 reset<='0' after 45 ns;
 din<=memory(to_integer(unsigned(address)));
 dut:entity work.cpu6800 port map(clk,reset,rw,vma,address,din,dout,hold,'0',irq,'0',alu,cc);
 process(clk)begin if rising_edge(clk)then
  cycles<=cycles+1;
  if reset='0' and vma='1' and rw='0' then memory(to_integer(unsigned(address)))<=dout;end if;
  -- Insert hold intervals while memory remains stable, exercising the core hold input.
  if cycles mod 97=0 then hold<='1';elsif cycles mod 97=3 then hold<='0';end if;
 end if;end process;
 process begin wait until memory(16#effe#)=x"01";wait for 500 ns;irq<='1';wait until memory(16#effe#)=x"00";irq<='0';wait;end process;
 process begin
 wait until memory(16#efff#)=x"aa";wait for 20 ns;
 for n in 16#a000# to 16#abff# loop
  assert memory(n)=expected(n) report "CPU mismatch at "&integer'image(n)&" actual="&to_hstring(memory(n))&" expected="&to_hstring(expected(n)) severity failure;
 end loop;
 report "PASS actual VHDL MC6800 differential ALU, flags, addressing, CPX, JSR/BSR/RTS, SWI/IRQ/RTI and hold";
 finish;
 end process;
 process begin wait for 5 ms;assert false report "CPU timeout" severity failure;end process;
end;
