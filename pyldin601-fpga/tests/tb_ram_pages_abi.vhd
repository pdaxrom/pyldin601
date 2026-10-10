library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use std.env.all;
entity tb_ram_pages_abi is
 generic(MODEL:string:="BIOS";HD:boolean:=false);
end;
architecture test of tb_ram_pages_abi is
 type bytes is array(natural range <>)of std_logic_vector(7 downto 0);
 impure function load(name:string;n:natural)return bytes is
  file f:text open read_mode is name;
  variable l:line;variable data:bytes(0 to n-1);variable b:std_logic_vector(7 downto 0);
 begin
  for a in data'range loop readline(f,l);hread(l,b);data(a):=b;end loop;
  return data;
 end;
 signal ram:bytes(0 to 65535):=load("build/ram-pages/RAM-"&MODEL&".mem",65536);
 constant bios:bytes(0 to 4095):=load("build/ram-pages/"&MODEL&".mem",4096);
 constant rom:bytes(0 to 8191):=load("build/ram-pages/ROM.mem",8192);
 signal clk:std_logic:='0';signal reset:std_logic:='1';signal rw,vma:std_logic;
 signal address:std_logic_vector(15 downto 0);signal din,dout:std_logic_vector(7 downto 0);
 signal group_number:natural range 0 to 18:=0;
 signal irq,nmi,hd_mode:std_logic:='0';signal nmi_cycles:natural:=0;
 signal page_reg:std_logic_vector(7 downto 0):=x"00";
begin
 clk<=not clk after 5 ns;reset<='0' after 45 ns;
 hd_mode<='1' when HD else '0';
 irq<='1' when ram(16#700#)=x"01" and ram(16#701#)=x"00" else '0';
 nmi<='1' when nmi_cycles>0 else '0';
 cpu:entity work.cpu6800 port map(clk,reset,rw,vma,address,din,dout,
   '0','0',irq,nmi,open,open,hd_mode);
 process(all)variable a,p:natural;begin
  a:=to_integer(unsigned(address));p:=to_integer(unsigned(page_reg(3 downto 0)));
  din<=ram(a);
  if a=16#e6f0# then din<=page_reg;
  elsif a=16#e6f1# then din<=std_logic_vector(to_unsigned(group_number,8));
  elsif a=16#e62a# then din<=x"80";
  elsif a>=16#f000# then din<=bios(a-16#f000#);
  elsif a>=16#c000# and a<16#e000# then
   if p>=8 then din<=rom(a-16#c000#);
   elsif p>=1 and p<=6 then
    din<=std_logic_vector(to_unsigned((16#41#+group_number*6+p-1)mod 256,8));
   end if;
  end if;
 end process;
 process begin
  wait until rising_edge(clk);
  if reset='0' then
   if nmi_cycles>0 then nmi_cycles<=nmi_cycles-1;end if;
   if vma='1' and rw='0' then
    if address=x"e6f0" then page_reg<=dout;
    elsif address=x"e6f1" then
     if unsigned(dout)<=18 then group_number<=to_integer(unsigned(dout));end if;
    else
     ram(to_integer(unsigned(address)))<=dout;
     if address=x"0702" then nmi_cycles<=8;end if;
    end if;
    if address=x"070f" then
     assert dout=x"a5" report "paging ABI failed: BIOS="&MODEL&" PC="&to_hstring(address)&
      " page="&to_hstring(page_reg)&" group="&natural'image(group_number) severity failure;
     assert page_reg=x"a3" and group_number=18 report "outer context lost" severity failure;
     assert ram(0)=x"00" report "nested SWI inDOS counter lost" severity failure;
     assert ram(16#708#)=x"01" report "native INT37 chain not exercised" severity failure;
     report "PASS actual CPU/native "&MODEL&" E6F0/E6F1: nested SWI/IRQ/NMI, native INT37 chain, page-zero no switch, group-zero RAM/ROM vectors, registers and stack";
     finish;
    end if;
   end if;
  end if;
 end process;
 process begin wait for 1 ms;assert false report "paging ABI timeout PC="&to_hstring(address) severity failure;end process;
end;
