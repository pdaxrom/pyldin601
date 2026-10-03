library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;
use std.textio.all;use ieee.std_logic_textio.all;use std.env.all;
use work.hd_edge_labels.all;
entity tb_hd6303_edges is generic(SCENARIO:natural:=0);end;
architecture test of tb_hd6303_edges is
 type bytes is array(0 to 65535)of std_logic_vector(7 downto 0);
 type words is array(0 to trap_count-1)of std_logic_vector(15 downto 0);
 impure function load return bytes is
  variable data:bytes;variable l:line;variable v:std_logic_vector(7 downto 0);
  file f:text;
 begin
  if SCENARIO=0 or SCENARIO=5 then file_open(f,"build/hd-trap.mem",read_mode);
  elsif SCENARIO=4 then file_open(f,"build/hd-switch.mem",read_mode);
  else file_open(f,"build/hd-sleep-"&integer'image(SCENARIO-1)&".mem",read_mode);end if;
  for n in data'range loop readline(f,l);hread(l,v);data(n):=v;end loop;file_close(f);return data;
 end;
 impure function load_traps return words is
  variable data:words;variable l:line;file f:text open read_mode is "build/hd-trap-addresses.mem";
 begin for n in data'range loop readline(f,l);hread(l,data(n));end loop;return data;end;
 signal memory:bytes:=load;constant traps:words:=load_traps;
 signal clk:std_logic:='0';signal reset:std_logic:='1';signal rw,vma:std_logic;
 signal addr:std_logic_vector(15 downto 0);signal din,dout,opcode:std_logic_vector(7 downto 0);
 signal irq,nmi:std_logic:='0';signal hd:std_logic:='1';signal decode:std_logic;
 signal regs:std_logic_vector(71 downto 0);signal hold:std_logic:='0';
begin
 clk<=not clk after 5 ns;reset<='0' after 45 ns;
 din<=memory(to_integer(unsigned(addr)));
 cpu:entity work.cpu6800_lockstep port map(clk,reset,rw,vma,addr,din,dout,hold,'0',irq,nmi,open,regs,opcode,decode,open,hd);
 process
  variable count,cycles,asleep:natural:=0;variable waiting,awoken:boolean:=false;
  variable old_sp:std_logic_vector(15 downto 0);variable mode_switches:natural:=0;variable trap_vector_seen:boolean:=false;
 begin
  if SCENARIO=4 then hd<='0';end if;
  loop
   wait until rising_edge(clk);cycles:=cycles+1;
   -- Regular HOLD stretches operand and vector reads as well as execution.
   if cycles mod 97=0 then hold<='1';elsif cycles mod 97=3 then hold<='0';end if;
   if reset='0' and hold='0' then
    if vma='1' and rw='0' then
     memory(to_integer(unsigned(addr)))<=dout;
     if addr=x"effd" then hd<=dout(0);mode_switches:=mode_switches+1;end if;
    end if;
    if SCENARIO=5 and vma='1' and rw='1' and addr=x"ffee" then trap_vector_seen:=true;end if;
    if SCENARIO=5 and vma='1' and rw='1' and addr=traps(0) then irq<='1';nmi<='1';end if;
    if decode='1' then
     if SCENARIO=5 and regs(71 downto 56)=x"2100" then
      assert trap_vector_seen report "NMI/IRQ stole TRAP priority" severity failure;
      irq<='0';nmi<='0';
     end if;
     if (SCENARIO=0 or SCENARIO=5) and regs(71 downto 56)=x"2000" then
      assert count<trap_count report "too many TRAP frames" severity failure;
      assert regs(55 downto 40)=x"8ff9" and regs(4)='1' report "TRAP SP/I" severity failure;
      assert memory(16#9000#)=traps(count)(7 downto 0) and memory(16#8fff#)=traps(count)(15 downto 8)
       report "TRAP did not save the offending opcode PC" severity failure;
      assert memory(16#8ffe#)=x"78" and memory(16#8ffd#)=x"56" and memory(16#8ffc#)=x"21" and memory(16#8ffb#)=x"34" and memory(16#8ffa#)=x"e1"
       report "TRAP frame/order or original CCR corrupted" severity failure;
      count:=count+1;
     elsif SCENARIO>=1 and SCENARIO<=3 then
      if regs(71 downto 56)=sleep_pc then waiting:=true;old_sp:=regs(55 downto 40);end if;
      if regs(71 downto 56)=x"2100" then
       assert asleep>=30 and not awoken report "SLP handler premature/duplicate" severity failure;
       assert SCENARIO/=1 and regs(55 downto 40)=x"8ff9" and regs(4)='1' report "SLP interrupt SP/I" severity failure;
       assert memory(16#9000#)=sleep_next(7 downto 0) and memory(16#8fff#)=sleep_next(15 downto 8) report "SLP return PC" severity failure;
       assert memory(16#8ffa#)(4)='0' or SCENARIO=3 report "SLP saved CCR" severity failure;
       irq<='0';nmi<='0';count:=count+1;awoken:=true;
      end if;
     elsif SCENARIO=4 then
      if regs(71 downto 56)=check_disabled then
       assert regs(55 downto 40)=x"9000" and regs(39 downto 0)=x"56782134e1" report "extended opcode executed in MC6800 mode" severity failure;
      elsif regs(71 downto 56)=check_enabled then
       assert regs(39 downto 8)=x"12345678" report "external HD6303 enable did not activate XGDX" severity failure;
      elsif regs(71 downto 56)=latch_mask then
       hd<='0'; -- Change external signal after opcode fetch, before operands.
      elsif regs(71 downto 56)=check_latched then
       assert memory(16#80#)=x"50" report "mid-instruction mode change cancelled AIM" severity failure;
      elsif regs(71 downto 56)=check_back then
       assert regs(39 downto 8)=x"12341234" report "external disable did not stop XGDX" severity failure;
      end if;
     end if;
    end if;
    if waiting and not awoken and SCENARIO>=1 and SCENARIO<=3 and vma='0' then
     asleep:=asleep+1;
     if asleep<30 then
      assert regs(55 downto 40)=old_sp report "SLP stacked before interrupt" severity failure;
     elsif asleep=30 then
      if SCENARIO=3 then nmi<='1';else irq<='1';end if;
      if SCENARIO=1 then awoken:=true;end if;
     end if;
    end if;
    if memory(16#efff#)=x"aa" then
     if SCENARIO=0 or SCENARIO=5 then assert count=trap_count and to_integer(unsigned(memory(16#effc#)))=trap_count report "TRAP sweep incomplete" severity failure;
     elsif SCENARIO<=3 then
      assert awoken and count=(boolean'pos(SCENARIO/=1)) report "SLP wake/handler count" severity failure;
      assert memory(16#e034#)=x"90" and memory(16#e035#)=x"00" report "SLP/RTI lost SP" severity failure;
     else assert mode_switches=2 report "ISA switch sequence incomplete" severity failure;end if;
     report "PASS HD6303 edge scenario "&integer'image(SCENARIO);finish;
    end if;
   end if;
   assert cycles<100000 report "HD6303 edge timeout" severity failure;
  end loop;
 end process;
end;
