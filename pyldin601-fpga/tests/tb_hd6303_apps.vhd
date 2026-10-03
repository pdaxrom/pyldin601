library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use std.env.all;
entity tb_hd6303_apps is
  generic(APP:string:="HDTEST"; HD:boolean:=true; BAD_EXPECTATION:boolean:=false;
          BAD_ADDRESS:natural:=0);
end;
architecture test of tb_hd6303_apps is
  type bytes is array(0 to 65535) of std_logic_vector(7 downto 0);
  impure function load return bytes is
    file f:text open read_mode is "build/hd6303-apps/" & APP & ".mem";
    variable data:bytes; variable l:line;
  begin
    for n in data'range loop readline(f,l);hread(l,data(n));end loop;
    if BAD_EXPECTATION then data(BAD_ADDRESS):=data(BAD_ADDRESS) xor x"01";end if;
    return data;
  end;
  signal memory:bytes:=load;
  signal clk:std_logic:='0';signal reset:std_logic:='1';
  signal rw,vma,decode:std_logic;signal address:std_logic_vector(15 downto 0);
  signal din,dout,opcode:std_logic_vector(7 downto 0);
  signal regs:std_logic_vector(71 downto 0);signal irq:std_logic:='0';signal hd_mode:std_logic;
  function starts(s,p:string) return boolean is
  begin
    if s'length<p'length then return false;end if;
    return s(s'low to s'low+p'length-1)=p;
  end;
begin
  clk<=not clk after 5 ns;reset<='0' after 45 ns;
  hd_mode<='1' when HD else '0';
  din<=x"82" when address=x"e6a0" and HD else x"80" when address=x"e6a0"
       else "10000000" when address=x"e62b" and irq='1'
       else x"00" when address=x"e62b" else memory(to_integer(unsigned(address)));
  cpu:entity work.cpu6800_lockstep port map(clk,reset,rw,vma,address,din,dout,
      '0','0',irq,'0',open,regs,opcode,decode,open,hd_mode);
  process
    variable cycles,products,sleeps,irqs,ticks:natural:=0;
    variable output:line;variable failed,passed,skipped,done:boolean:=false;
  begin
    loop
      wait until rising_edge(clk);
      cycles:=cycles+1;
      if reset='0' then
        ticks:=ticks+1;
        if ticks=50000 then ticks:=0;irq<='1';end if;
        if vma='1' then
          if rw='1' and address=x"e62b" then irq<='0';end if;
          if rw='0' then
            memory(to_integer(unsigned(address)))<=dout;
            if address=x"e62b" then irq<='0';end if;
            if address=x"eff0" then
              if dout=x"0a" then
                if output/=null then
                  report APP & ": " & output.all;
                  failed:=failed or starts(output.all,"FAIL");
                  passed:=passed or starts(output.all,"PASS");
                  skipped:=skipped or starts(output.all,"SKIP");
                  deallocate(output);
                end if;
              elsif dout/=x"0d" then write(output,character'val(to_integer(unsigned(dout))));end if;
            end if;
            if address=x"efff" and dout=x"aa" then done:=true;end if;
          end if;
        end if;
        if decode='1' then
          if opcode=x"3d" then products:=products+1;end if;
          if opcode=x"1a" then sleeps:=sleeps+1;end if;
          if regs(71 downto 56)=x"f000" then irqs:=irqs+1;end if;
          if done and regs(55 downto 40)=x"bfff" then
            assert memory(16#80#)=x"9a" and memory(16#81#)=x"bc"
              report "application leaked direct-page scratch" severity failure;
            if not HD then assert skipped and not failed and not passed
              report "MC6800 guard did not skip HD instructions" severity failure;
            elsif BAD_EXPECTATION then assert failed and not passed
              report "bad expectation was not detected" severity failure;
            else
              assert passed and not failed and not skipped report "application failed" severity failure;
              if APP="HDMUL" then assert products=65536 report "MUL sweep incomplete" severity failure;end if;
              if APP="HDSLEEP" then assert sleeps=64 and irqs>=32 report "SLP wake sweep incomplete" severity failure;end if;
            end if;
            report "PASS actual VHDL executable " & APP & " HD=" & boolean'image(HD) &
              " bad-expectation=" & boolean'image(BAD_EXPECTATION) &
              " MUL=" & natural'image(products) & " SLP=" & natural'image(sleeps) &
              " IRQ=" & natural'image(irqs);
            finish;
          end if;
        end if;
      end if;
      assert cycles<30000000 report "application did not terminate" severity failure;
    end loop;
  end process;
end;
