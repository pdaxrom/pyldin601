library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use std.env.all;
use work.cpu_interrupt_labels.all;

entity tb_cpu_interrupts is
 generic(SCENARIO:natural:=0;IRQ_DELAY:natural:=0;HD:boolean:=false);
end;
architecture test of tb_cpu_interrupts is
 type bytes is array(0 to 65535)of std_logic_vector(7 downto 0);
 impure function load return bytes is
  file f:text open read_mode is "build/cpu-interrupts.mem";
  variable l:line;variable data:bytes;variable v:std_logic_vector(7 downto 0);
 begin
  for n in data'range loop readline(f,l);hread(l,v);data(n):=v;end loop;
  -- Scenario 3 accepts IRQ while fetching a WAI that has not been executed.
  if SCENARIO=3 then data(to_integer(unsigned(service_pc))):=x"3e";end if;
  if SCENARIO=5 or SCENARIO=6 then
   data(to_integer(unsigned(service_pc))):=x"3e";
   data(to_integer(unsigned(service_pc))+1):=x"01";
   if SCENARIO=5 then data(to_integer(unsigned(service_pc))-2):=x"31";end if;
  end if;
  return data;
 end;
 signal memory:bytes:=load;
 signal clk:std_logic:='0';signal reset:std_logic:='1';signal rw,vma:std_logic;
 signal address:std_logic_vector(15 downto 0);signal din,dout:std_logic_vector(7 downto 0);
 signal irq:std_logic:='0';signal registers:std_logic_vector(71 downto 0);
 signal nmi:std_logic:='0';
 signal opcode:std_logic_vector(7 downto 0);signal decode:std_logic;
 signal injected:boolean:=false;signal hd_mode:std_logic;
begin
 hd_mode<='1' when HD else '0';
 clk<=not clk after 5 ns;reset<='0' after 45 ns;
 din<=memory(to_integer(unsigned(address)));
 cpu:entity work.cpu6800_lockstep port map(clk,reset,rw,vma,address,din,dout,
  '0','0',irq,nmi,open,registers,opcode,decode,open,hd_mode);
 process
  variable armed:boolean:=false;variable remaining:natural:=0;
  variable swi_seen,irq_seen:boolean:=false;
  variable wait_cycles:natural:=0;
 begin
  wait until rising_edge(clk);
  if reset='0' then
   if decode='1' and registers(71 downto 56)=x"1000" then
    assert registers(4)='1' report "Reset did not mask IRQ" severity failure;
   end if;
   if not injected and (SCENARIO=0 or SCENARIO=5 or SCENARIO=6) then
    if not armed and decode='1' and registers(71 downto 56)=service_pc then
     armed:=true;remaining:=IRQ_DELAY;
    end if;
    if armed then
     if remaining=0 then irq<='1';injected<=true;
     else remaining:=remaining-1;end if;
    end if;
   elsif not injected and SCENARIO>=1 and SCENARIO<=3 then
    if vma='1' and rw='1' and address=service_pc then irq<='1';injected<=true;end if;
   end if;
   if SCENARIO=5 and injected and not irq_seen then
    wait_cycles:=wait_cycles+1;
    if wait_cycles=50 then
     assert registers(4)='1' report "WAI cleared the caller's IRQ mask" severity failure;
     nmi<='1';
    end if;
   end if;
   if vma='1' and rw='0' then
    memory(to_integer(unsigned(address)))<=dout;
    -- Scenario 2 removes the IRQ pin after acceptance, during the first push.
    if SCENARIO=2 and injected and address=x"9000" then irq<='0';end if;
    if address=x"e000" then
     assert not swi_seen report "SWI executed more than once" severity failure;
     assert SCENARIO/=3 report "Unexecuted WAI redirected accepted IRQ to SWI" severity failure;
     if SCENARIO=0 then assert not irq_seen report "IRQ stole the SWI frame" severity failure;
     elsif SCENARIO=1 or SCENARIO=2 then
      assert irq_seen report "Unexecuted SWI redirected accepted IRQ" severity failure;
     end if;
     assert memory(16#e010#)(4)='1' report "SWI handler entered with I=0" severity failure;
     assert memory(16#e011#)=x"e1" report "SWI did not save pre-interrupt CCR" severity failure;
     assert memory(16#e012#)&memory(16#e013#)=std_logic_vector(unsigned(service_pc)+1)
      report "SWI saved an incorrect PC" severity failure;
     swi_seen:=true;
    elsif address=x"e001" then
     assert not irq_seen report "IRQ executed more than once" severity failure;
     if SCENARIO=0 then assert swi_seen report "IRQ stole the SWI frame" severity failure;end if;
     assert memory(16#e020#)(4)='1' report "IRQ handler entered with I=0" severity failure;
     if SCENARIO=5 then
      assert wait_cycles>=50 report "Masked IRQ woke WAI before NMI" severity failure;
      assert memory(16#e021#)=x"f1" report "WAI lost saved I=1" severity failure;
     else
      assert memory(16#e021#)=x"e1" report "IRQ did not save pre-interrupt CCR" severity failure;
     end if;
     if SCENARIO=0 then
      assert memory(16#e022#)&memory(16#e023#)=return_pc report "IRQ returned inside SWI service" severity failure;
     elsif SCENARIO=5 or SCENARIO=6 then
      assert not swi_seen report "WAI executed SWI handler" severity failure;
      assert memory(16#e022#)&memory(16#e023#)=std_logic_vector(unsigned(service_pc)+1)
       report "WAI saved an incorrect PC" severity failure;
     else
      assert not swi_seen report "Fetched opcode replaced IRQ vector" severity failure;
      assert memory(16#e022#)&memory(16#e023#)=service_pc report "Accepted IRQ lost instruction PC" severity failure;
     end if;
     irq_seen:=true;irq<='0';nmi<='0';
     if SCENARIO=3 then report "PASS interrupt boundary scenario 3: fetched WAI preserved IRQ vector";finish;end if;
    elsif address=x"e0ff" then
     if SCENARIO/=5 and SCENARIO/=6 then assert swi_seen report "SWI handler missing" severity failure;end if;
     if SCENARIO/=4 then assert irq_seen report "IRQ handler missing" severity failure;end if;
     if SCENARIO=5 then assert memory(16#e030#)=x"31" report "WAI/NMI failed to restore A" severity failure;
     else assert memory(16#e030#)=x"21" report "RTI failed to restore A" severity failure;end if;
     assert memory(16#e031#)=x"34" and
      memory(16#e032#)=x"56" and memory(16#e033#)=x"78" and
      memory(16#e034#)=x"90" and memory(16#e035#)=x"00"
      report "RTI failed to restore A/B/X/SP" severity failure;
     report "PASS interrupt boundary scenario "&natural'image(SCENARIO)&" delay "&natural'image(IRQ_DELAY);
     finish;
    end if;
   end if;
  end if;
 end process;
 process begin wait for 30 us;assert false report "interrupt boundary timeout" severity failure;end process;
end;
