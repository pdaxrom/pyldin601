library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use std.env.all;
entity tb_gamebios is generic(MODEL:string:="601";HD:boolean:=true;SPEED:natural:=0);end;
architecture test of tb_gamebios is
 type bytes is array(natural range <>)of std_logic_vector(7 downto 0);
 impure function load(path:string;n:natural)return bytes is
  file f:text open read_mode is path;variable l:line;variable d:bytes(0 to n-1);variable b:std_logic_vector(7 downto 0);
 begin for a in d'range loop readline(f,l);hread(l,b);d(a):=b;end loop;return d;end;
 signal ram:bytes(0 to 65535):=load("build/gamebios/RAM-"&MODEL&".mem",65536);
 constant rom:bytes:=load("build/gamebios/ROM-"&MODEL&".mem",71680);
 signal framebuffer:bytes(0 to 63999):=(others=>x"00");
 signal palette:bytes(0 to 8191):=(others=>x"09");
 signal ay:bytes(0 to 13):=(others=>x"00");
 signal gfx:bytes(0 to 15):=(others=>x"00");
 signal gfx_failed:std_logic:='1';
 signal clk:std_logic:='0';signal reset:std_logic:='1';signal rw,vma,irq,hd_mode:std_logic;
 signal address:std_logic_vector(15 downto 0);signal din,dout,page:std_logic_vector(7 downto 0):=x"00";
 signal group_number,paladdr:natural:=0;signal readback:boolean:=false;
 signal period,period_shadow:natural:=960000;signal divider,divider_shadow:unsigned(31 downto 0):=x"03000000";
 signal music_counter:natural:=0;signal enabled,pending:boolean:=false;signal audio_ticks:natural:=0;
 signal old_irq:std_logic_vector(15 downto 0);signal old_irq_page:std_logic_vector(3 downto 0);
begin
 clk<=not clk after 5 ns;reset<='0' after 45 ns;
 hd_mode<='1' when HD else '0';irq<='1' when pending else '0';
 old_irq<=ram(16#efc8#)&ram(16#efc9#);old_irq_page<=ram(16#edf2#)(7 downto 4);
 cpu:entity work.cpu6800 port map(clk,reset,rw,vma,address,din,dout,'0','0',irq,'0',open,open,hd_mode);
 process(all)variable a,p,k:natural;variable q:unsigned(31 downto 0);begin
  a:=to_integer(unsigned(address));p:=to_integer(unsigned(page(2 downto 0)));din<=ram(a);
  if a>=16#f000# then din<=rom(65536+a-16#f000#);
  elsif a>=16#c000# and a<16#e000# and page(3)='1' then din<=rom(p*8192+a-16#c000#);
  elsif a=16#e6f0# then din<=page;
  elsif a=16#e6f1# then din<=std_logic_vector(to_unsigned(group_number,8));
  elsif a=16#e6a0# then din<=x"82";if not HD then din<=x"80";end if;
  elsif a=16#e691# then din<=x"59";
  elsif a=16#e690# then din<=x"00";if enabled then din(0)<='1';end if;if pending then din(7)<='1';end if;
  elsif a>=16#e692# and a<=16#e695# then
   q:=to_unsigned(period,32);k:=8*(16#e695#-a);din<=std_logic_vector(q(k+7 downto k));
  elsif a>=16#e69b# and a<=16#e69e# then k:=8*(16#e69e#-a);din<=std_logic_vector(divider(k+7 downto k));
  elsif a>=16#e610# and a<=16#e61d# then din<=ay(a-16#e610#);
  elsif a>=16#e650# and a<=16#e65f# then
   din<=gfx(a-16#e650#);
   if a=16#e650# then din(4)<=gfx_failed;
   elsif a=16#e65e# then din<=x"47";if readback then din<=palette(paladdr);end if;
   elsif a=16#e65f# then din<=x"05";end if;
  elsif a>=16#e600# and a<=16#e6ff# then din<=x"00";
  end if;
 end process;
 process
  variable a,p,k,w,h,src,dst:natural;variable q:unsigned(31 downto 0);variable original_irq:std_logic_vector(15 downto 0);variable original_page:std_logic_vector(3 downto 0);
 begin
  wait until rising_edge(clk);
  if reset='1' then original_irq:=old_irq;original_page:=old_irq_page;
  else
   if enabled then
    if music_counter+24/(2**SPEED)>=period then music_counter<=0;pending<=true;audio_ticks<=audio_ticks+1;
    else music_counter<=music_counter+24/(2**SPEED);end if;
   end if;
   if vma='1' and rw='0' then
    a:=to_integer(unsigned(address));p:=to_integer(unsigned(dout));
    if a=16#e6f0# then page<=dout;
    elsif a=16#e6f1# then group_number<=p;
    elsif a>=16#e610# and a<=16#e61d# then ay(a-16#e610#)<=dout;
    elsif a=16#e690# then enabled<=dout(0)='1';if dout(1)='1' then pending<=false;end if;if dout(0)='0' or dout(2)='1' then music_counter<=0;pending<=false;end if;
    elsif a>=16#e692# and a<=16#e695# then q:=to_unsigned(period_shadow,32);k:=8*(16#e695#-a);q(k+7 downto k):=unsigned(dout);period_shadow<=to_integer(q);
    elsif a=16#e696# then period<=period_shadow;music_counter<=0;
    elsif a>=16#e69b# and a<=16#e69e# then k:=8*(16#e69e#-a);divider_shadow(k+7 downto k)<=unsigned(dout);
    elsif a=16#e69f# then divider<=divider_shadow;
    elsif a>=16#e650# and a<=16#e65f# then
     k:=a-16#e650#;
     if k=2 then paladdr<=(paladdr/256)*256+p;
     elsif k=13 then paladdr<=(p mod 32)*256+paladdr mod 256;
     elsif k=14 then palette(paladdr)<="00"&dout(5 downto 0);paladdr<=(paladdr+1)mod 8192;
     elsif k=15 then readback<=dout(0)='1';if dout(1)='1' then paladdr<=(paladdr+1)mod 8192;end if;
     else
      gfx(k)<=dout;
      if k=1 then
       gfx_failed<='0';
       src:=256*to_integer(unsigned(gfx(7)))+to_integer(unsigned(gfx(6)));dst:=256*to_integer(unsigned(gfx(9)))+to_integer(unsigned(gfx(8)));w:=256*to_integer(unsigned(gfx(11)))+to_integer(unsigned(gfx(10)));h:=to_integer(unsigned(gfx(12)));
       if p=1 then assert w>0 and h>0 and dst+(h-1)*320+w<=64000 report "bad rectangle" severity failure;
        for y in 0 to h-1 loop for x in 0 to w-1 loop framebuffer(dst+y*320+x)<=gfx(3);end loop;end loop;
       elsif p=4 then framebuffer(dst)<=gfx(3);
       elsif p=5 then gfx(13)<=framebuffer(src);
       elsif p=2 then
        assert w>0 and h>0 and src+(h-1)*320+w<=64000 and dst+(h-1)*320+w<=64000 report "bad copy" severity failure;
        for y in 0 to h-1 loop for x in 0 to w-1 loop framebuffer(dst+y*320+x)<=framebuffer(src+y*320+x);end loop;end loop;
       elsif p=3 then gfx(2)<=gfx(5);
       else gfx_failed<='1';end if;
      end if;
     end if;
    else ram(a)<=dout;
    end if;
    if a=16#070f# then
     assert dout=x"a5" report "GAMEBIOS CPU test failed" severity failure;
     assert page=x"a3" and group_number=18 report "page context lost" severity failure;
     assert old_irq=original_irq and old_irq_page=original_page report "IRQ vector lost" severity failure;
     assert not enabled and not pending and period=960000 and divider=x"03000000" report "audio context lost" severity failure;
     assert gfx(0)=x"00" and not readback report "graphics context lost" severity failure;
     if HD then assert gfx_failed='0' report "sticky graphics error not recovered" severity failure;end if;
     for n in palette'range loop assert palette(n)=x"09" report "palette not restored" severity failure;end loop;
     if HD then assert audio_ticks>=6 report "music IRQ not exercised" severity failure;end if;
     report "PASS actual VHDL CPU/native GAMEBIOS "&MODEL&" HD="&boolean'image(HD)&" SPEED="&natural'image(SPEED)&": palette/text/HAM8, AY frames/notes/IRQ, registers/pages and cleanup";
     finish;
    end if;
   end if;
  end if;
 end process;
 process begin wait for 40 ms;assert false report "GAMEBIOS timeout at "&to_hstring(address) severity failure;end process;
end;
