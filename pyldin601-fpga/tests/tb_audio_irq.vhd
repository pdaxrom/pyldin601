library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use std.env.all;
entity tb_audio_irq is generic(SPEED:integer:=0;FRAMES:integer:=80;PERIOD:integer:=240000;
 IRQ_ENTRY:integer:=0;IRQ_RTI:integer:=0;TRANSFER:integer:=0;SENT:integer:=0;
 PAL_HANDLER:integer:=0;UNDERRUNS:integer:=0);end;
architecture test of tb_audio_irq is
 type bytes is array(natural range <>) of std_logic_vector(7 downto 0);
 impure function load(path:string;count:integer)return bytes is
  file f:text open read_mode is path;variable l:line;variable data:bytes(0 to count-1);
 begin for k in data'range loop readline(f,l);hread(l,data(k));end loop;return data;end;
 constant initial:bytes(0 to 65535):=load("build/audio/irq-ram.mem",65536);
 signal ram:bytes(0 to 65535):=initial;
 constant rom:bytes(0 to 65535):=load("build/audio/irq-rom.mem",65536);
 constant banks:bytes(0 to 909311):=load("build/audio/irq-banks.mem",909312);
 constant expected:bytes(0 to FRAMES*14-1):=load("build/audio/irq-frames.mem",FRAMES*14);
 signal clk:std_logic:='0';signal reset:std_logic:='1';signal irq:std_logic;
 signal rw,vma:std_logic;signal address:std_logic_vector(15 downto 0);
 signal din,dout:std_logic_vector(7 downto 0);signal slot:integer:=7;signal grp:integer:=12;
 signal ay:bytes(0 to 13):=(others=>x"00");
 signal enabled,music_pending,pal_pending,key_pending:boolean:=false;
 signal timer_latched,key_latched:boolean:=false;
 signal timer_byte,key_byte:std_logic_vector(7 downto 0):=x"ff";
 signal counter:integer:=0;
 signal cycles,played,shapes,max_handler,max_transfer,pal_calls,pal_events,key_reads:integer:=0;
 constant tick:integer:=20000*2**SPEED;
 begin
 clk<=not clk after 5 ns;reset<='0' after 45 ns;
 irq<='1' when music_pending or pal_pending or key_pending else '0';
 cpu:entity work.cpu6800 port map(clk,reset,rw,vma,address,din,dout,'0','0',irq,'0',open,open,'1');
 process(all) variable a,b:integer;begin
  a:=to_integer(unsigned(address));din<=ram(a);
  if a>=16#f000# then din<=initial(a);
  elsif a=16#e6f0# then din<=std_logic_vector(to_unsigned(slot,8));
  elsif a=16#e6f1# then din<=std_logic_vector(to_unsigned(grp,8));
  elsif a=16#e691# then din<=x"59";
  elsif a=16#e690# then din<=x"00";if enabled then din(0)<='1';end if;if music_pending then din(7)<='1';end if;
  elsif a=16#e62b# then din<=x"37";if pal_pending then din<=x"b7";end if;if timer_latched then din<=timer_byte;end if;
  elsif a=16#e62a# then din<=x"3f";if key_pending then din<=x"bf";end if;
  elsif a=16#e628# then din<=x"ff";if key_pending then din<=x"61";end if;if key_latched then din<=key_byte;end if;
  elsif a>=16#c000# and a<16#e000# then
   if slot>=1 and slot<=6 then
    b:=(grp*6+slot-1)*8192+a-16#c000#;
    assert b<banks'length report "out-of-range foreground RAM bank" severity failure;din<=banks(b);
   elsif slot>=8 then din<=rom((slot-8)*8192+a-16#c000#);end if;
  end if;
 end process;
 process(clk)
  alias cpu_pc is <<signal .tb_audio_irq.cpu.pc:std_logic_vector(15 downto 0)>>;
  type ints is array(0 to 31)of integer;
  type bools is array(0 to 31)of boolean;
  variable starts,slots,groups:ints:=(others=>0);
  variable music:bools:=(others=>false);
  variable depth,a,r,transfer_start,elapsed,shape_count:integer:=0;
  variable regs:bytes(0 to 13);variable keyboard_sent:boolean:=false;
 begin if rising_edge(clk) then
  cycles<=cycles+1;
  if reset='0' then
   -- Match classic_system's peripheral latch: acknowledging a read cannot
   -- change the byte while the CPU is still sampling the same bus cycle.
   if address/=x"e62b" or vma='0' then timer_latched<=false;end if;
   if address/=x"e628" or vma='0' then key_latched<=false;end if;
   if enabled then
    if counter+24/2**SPEED>=PERIOD then
     assert not music_pending report "music timer overrun frames="&integer'image(played)&" PAL="&integer'image(pal_calls)&" PC="&to_hstring(cpu_pc)&" page="&integer'image(slot)&" grp="&integer'image(grp)&" elapsed="&integer'image(depth) severity failure;
     counter<=counter+24/2**SPEED-PERIOD;music_pending<=true;
    else counter<=counter+24/2**SPEED;end if;
   end if;
   if cycles>100 and cycles mod tick=0 then
    assert not pal_pending report "PAL system timer event lost" severity failure;
    pal_pending<=true;pal_events<=pal_events+1;
   end if;
   if played>=40 and not keyboard_sent then key_pending<=true;keyboard_sent:=true;end if;
   if vma='1' then
    a:=to_integer(unsigned(address));
    if rw='1' then
     if a=16#e62b# and not timer_latched then timer_byte<=din;timer_latched<=true;pal_pending<=false;
     elsif a=16#e628# and not key_latched then key_byte<=din;key_latched<=true;if key_pending then key_reads<=key_reads+1;end if;key_pending<=false;end if;
     if a=IRQ_ENTRY then
      assert depth<32 report "IRQ stack overflow" severity failure;
      starts(depth):=cycles;music(depth):=music_pending;slots(depth):=slot;groups(depth):=grp;depth:=depth+1;
     elsif a=PAL_HANDLER then pal_calls<=pal_calls+1;
     elsif a=TRANSFER then transfer_start:=cycles;
     elsif a=SENT then elapsed:=cycles-transfer_start;if elapsed>max_transfer then max_transfer<=elapsed;end if;
     elsif a=IRQ_RTI and depth>0 then
      depth:=depth-1;
      assert slot=slots(depth) and grp=groups(depth) report "native BIOS IRQ failed to restore both paging registers" severity failure;
      if music(depth) then
       elapsed:=cycles-starts(depth);if elapsed>max_handler then max_handler<=elapsed;end if;
       assert elapsed<1000 report "native music dispatch exceeds 1000 cycles" severity failure;
      end if;
      if played>=FRAMES and depth=0 then
       assert shapes=shape_count report "R13 writes/sentinel mismatch" severity failure;
       assert ram(UNDERRUNS)=x"00" report "music queue underrun" severity failure;
       assert key_reads=1 report "shared keyboard IRQ was lost" severity failure;
       assert pal_calls>=pal_events-1 and pal_calls<=pal_events report "PAL clock dispatch count calls="&integer'image(pal_calls)&" events="&integer'image(pal_events) severity failure;
       assert to_integer(unsigned(ram(16#18#)))=(to_integer(unsigned(initial(16#18#)))+2*pal_calls) mod 100 report "native system clock changed rate" severity failure;
       report "PASS HD6303 music IRQ "&integer'image(2**SPEED)&" MHz: "&integer'image(played)&" frames, native IRQ "&integer'image(max_handler)&" / transfer "&integer'image(max_transfer)&" cycles; paging/PAL/keyboard/envelope";
       finish;
      end if;
     end if;
    else
     if a=16#e6f0# then slot<=to_integer(unsigned(dout));
     elsif a=16#e6f1# then grp<=to_integer(unsigned(dout));
     elsif a=16#e690# then
      enabled<=dout(0)='1';
      if dout(1)='1' then music_pending<=false;end if;
      if dout(0)='0' or dout(2)='1' then counter<=0;music_pending<=false;end if;
     elsif a>=16#e610# and a<=16#e61d# then
      r:=a-16#e610#;regs:=ay;regs(r):=dout;ay(r)<=dout;
      if r=12 then
       assert played<FRAMES report "extra music frame" severity failure;
       for k in 0 to 12 loop
        assert regs(k)=expected(played*14+k) report "AY mismatch frame "&integer'image(played)&" reg "&integer'image(k)&" got "&to_hstring(regs(k))&" expected "&to_hstring(expected(played*14+k)) severity failure;
       end loop;
       if expected(played*14+13)/=x"ff" then shape_count:=shape_count+1;end if;
       played<=played+1;
      elsif r=13 then
       assert played>0 and dout=expected((played-1)*14+13) and dout/=x"ff" report "AY shape/sentinel" severity failure;
       shapes<=shapes+1;
      end if;
     else
      assert a<16#c000# or a>=16#e000# or slot=7 or slot=0 report "playback writes banked song data" severity failure;
      ram(a)<=dout;
     end if;
    end if;
   end if;
  end if;
 end if;end process;
 process begin wait for 200 ms;assert false report "audio IRQ timeout" severity failure;end process;
end;
