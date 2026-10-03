library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use std.env.all;
entity tb_boot_lockstep is end;
architecture test of tb_boot_lockstep is
 type bytes is array(0 to 399359)of std_logic_vector(7 downto 0);
 type base_bytes is array(0 to 65535)of std_logic_vector(7 downto 0);
 impure function expected_ram return base_bytes is
  file f:text open read_mode is "build/boot-lockstep-base.mem";
  variable l:line;variable data:base_bytes;variable v:std_logic_vector(7 downto 0);
 begin
  for a in data'range loop readline(f,l);hread(l,v);data(a):=v;end loop;
  return data;
 end;
 constant final_ram:base_bytes:=expected_ram;
 impure function rom_image return bytes is
  file f:text open read_mode is "build/rom.reference.mem";
  variable l:line;variable data:bytes:=(others=>x"00");variable v:std_logic_vector(7 downto 0);
 begin
  for a in 65536 to 399359 loop readline(f,l);hread(l,v);data(a):=v;end loop;
  return data;
 end;
 signal memory:bytes:=rom_image;
 signal clk:std_logic:='0';signal reset:std_logic:='1';signal rw,vma,decode:std_logic;
 signal address:std_logic_vector(15 downto 0);signal din,dout:std_logic_vector(7 downto 0);
 signal registers:std_logic_vector(71 downto 0);signal page:std_logic_vector(7 downto 0):=x"00";
 signal opcode:std_logic_vector(7 downto 0);
 signal io_value:std_logic_vector(7 downto 0):=x"00";
 signal physical:natural range 0 to 399359;
 signal count:natural:=0;
begin
 clk<=not clk after 5 ns;reset<='0' after 45 ns;
 process(all)variable a:natural;begin
  a:=to_integer(unsigned(address));physical<=a;
  if rw='1' then
   if a>=16#f000# then physical<=16#60000#+a-16#f000#;
   elsif a>=16#c000# and a<16#e000# and page(3)='1' then
    physical<=16#10000#+(to_integer(unsigned(page(7 downto 4))) mod 5)*65536+
      to_integer(unsigned(page(2 downto 0)))*8192+a-16#c000#;
   end if;
  end if;
 end process;
 din<=io_value when address(15 downto 8)=x"e6" else memory(physical);
 dut:entity work.cpu6800_lockstep port map(clk,reset,rw,vma,address,din,dout,
  '0','0','0','0',open,registers,opcode,decode,open);
 process
  file io:text open read_mode is "build/boot-lockstep-io.mem";
  file expected:text open read_mode is "build/boot-lockstep-registers.mem";
  variable l:line;variable state:std_logic_vector(71 downto 0);
  variable read_record:std_logic_vector(23 downto 0);variable steps:natural:=0;
 begin
  wait until rising_edge(clk);
  if reset='0' then
   if decode='1' then
    assert not endfile(expected) report "unexpected instruction past reference" severity failure;
    readline(expected,l);hread(l,state);
    assert registers=state report "instruction "&natural'image(steps)&" actual="&to_hstring(registers)&
      " expected="&to_hstring(state) severity failure;
    steps:=steps+1;count<=steps;
    if endfile(expected) then
     for a in 0 to 65535 loop
      if a<16#e600# or a>16#e6ff# then
       assert memory(a)=final_ram(a) report "Final RAM mismatch "&to_hstring(to_unsigned(a,16))&
         " actual="&to_hstring(memory(a))&" expected="&to_hstring(final_ram(a)) severity failure;
      end if;
     end loop;
     report "PASS 500000 consecutive native BIOS/ROM instructions, all PC/SP/X/A/B/CC states and final RAM";
     finish;
    end if;
   end if;
   if vma='1' then
    if rw='0' then
     memory(to_integer(unsigned(address)))<=dout;
     if address=x"e6f0" then page<=dout;end if;
    elsif address(15 downto 8)=x"e6" and (opcode=x"6f" or opcode=x"7f") then
     -- The hardware performs an RMW read before CLR. The instruction-level
     -- emulator only writes zero; this discarded read has no golden event.
     io_value<=memory(to_integer(unsigned(address)));
    elsif address(15 downto 8)=x"e6" then
     assert not endfile(io) report "extra IO read "&to_hstring(address) severity failure;
     readline(io,l);hread(l,read_record);
     assert read_record(23 downto 8)=address report "IO read order: actual="&to_hstring(address)&
       " expected="&to_hstring(read_record) severity failure;
     io_value<=read_record(7 downto 0);
    end if;
   end if;
  end if;
 end process;
 process begin wait for 100 ms;assert false report "lockstep timeout "&natural'image(count) severity failure;end process;
end;
