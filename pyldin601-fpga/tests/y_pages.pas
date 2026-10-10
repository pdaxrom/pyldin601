program Ypages;
var j, sum: integer;
    f: text;

procedure tally(n: integer);
var k: integer;
begin
  for k := 1 to n do sum := sum + k
end;

begin
  sum := 0;
  for j := 1 to 10 do tally(j);
  rewrite(f, 'B:YRESULT.TXT');
  writeln(f, 'Y PAGE SUM ', sum);
  close(f);
  writeln('Y PAGE PASS ', sum);
  halt(0)
end.
