(******************************************************
*						      *
*	      �������� ����� ��'������ �������        *
*		       UniLINK			      *
*						      *
*	       18.07.1989 �.   17.10	V.1.1	      *
*	       (c) 1989 Leonid Curak		      *
*******************************************************)

(*
	     �������� �����
*)
   CONST  maxd=2000;		       { ����� ������� BUF }
	  maxt=15000;		       { ����� ������� TABT }

   TYPE   name	 = array[1..16] of byte;

	  tmods  = record	       { ��������� ������� ������� TMOD }
	       hand  :byte;	       { ����� ����� }
	       nmod  :longint;	       { ������� � ����� }
	       sizec :integer;	       { ������ ���� }
	       ykpb  :integer;	       { ��������� ������� PUBL }
	       ykext :integer;	       { ��������� ������� EXT }
	       namem :array[1..8] of char; { ��� ������ }
	   end;

	  tvmods = record	       { ��������� ������� ������������ �������}
	       nom   :integer;	       { ������ �� ������� TMOD }
	       bas   :integer;	       { ���� ������ }
	   end;

	  texs	 = record	       { ��������� ������� EXT }
	       namext:name;	       { ��� ����� ��� }
	       adr   :integer;	       { �������� ����� }
	       tip   :byte;	       { ��� ����� }
	   end;

	  tmodt  = array[1..256] of tmods;
	  tvmodt = array[1..256] of tvmods;
	  textt  = array[1..1000] of texs;

(*
	    �������� ����������
*)
   VAR	  tabt			  : array[1..maxt] of byte; { ����� ����� ��� � PUBL }
	  buf			  : array[1..maxd] of byte; { ����� ������/������ }
	  rfile 		  : array[1..32] of file;   { ��������� ������ ������ }
	  nam_mod		  : array[1..32] of string[40]; { ����� ������ ������ }
	  mnm			  : name;
	  digits		  : array[1..16] of char;   { ������������� }

	  tmod			  : tmodt;
	  tvmod 		  : tvmodt;
	  tex			  : textt;

	  adrzs,adrzm		  : byte;
	  flt,fls,fltp,flni,flv   : boolean;
	  wfile,pfile		  : file;
	  fprin 		  : text;
	  namfr,namfw,namfp,par   : string[40];
	  nfprin,namf		  : string;
	  pozf			  : longint;

	  kmodl,kmod,dlpb,dlext   : integer;
	  ktrel,sizect,sizev,kfm  : integer;
	  indm,indt,nmodt,kmoda   : integer;
	  i,i1,i2,it,ip,ir,znt	  : integer;
	  inex,kpb,kext,tbas,klrel: integer;

(*
	   ���������
*)

(*
      ��������� �������� �����
*)
  procedure FCON( var kps:integer);
   var jj :integer;
   begin
    repeat
     if kps<maxd then
       jj:=kps
      else
       jj:=maxd;
     kps:=kps-jj;
     BLOCKREAD(rfile[i],buf,jj);
    until kps=0;
   end;

(*
	     ��������� ��������� ������ �� 1 �������
*)
  procedure MODUL;

   var j  :integer;

   begin
    kpb:=buf[5]*256+buf[6];	     { �����. (.) PUBL }
    kext:=buf[7]*256+buf[8];	     { �����. (.) EXT }
    dlpb:=kpb*20;
    dlext:=kext*20;
    sizect:=buf[9]*256+buf[10];      { ������ ���� }
(*
	���������� �������� ������� TMOD
*)
    tmod[indm].hand:=i; 	     { ����� ����� }
    tmod[indm].nmod:=pozf;	     { ������� ������ � ����� }
    tmod[indm].ykpb:=indt;
    tmod[indm].sizec:=sizect;	     { ������ ������ }
    for j:=1 to 8 do		     { ��� ������ }
      tmod[indm].namem[j]:=chr(mnm[j]);

(*
	������ ������� PUBL
*)
    tabt[indt]:=buf[5];
    tabt[indt+1]:=buf[6];	      { ���������� (.) PUBL }
    indt:=indt+2;
    if dlpb<>0 then
      begin
       BLOCKREAD(rfile[i],buf,dlpb);   { ������ PUBL }
       for j:=1 to dlpb do
	begin
	 tabt[indt]:=buf[j];
	 indt:=indt+1;
	end;
      end
     else			       {��� PUBL �������� ����� ������� }
      if buf[15]*256+buf[16]<>0 then
       begin
	tabt[indt-1]:=1;
	for j:=1 to 16 do
	 begin
	  tabt[indt]:=mnm[j];
	  indt:=indt+1;
	 end;
	tabt[indt]:=buf[15];
	tabt[indt+1]:=buf[16];
	tabt[indt+2]:=0;
	tabt[indt+3]:=0;
	indt:=indt+4;
       end;

(*
	 ������ ������� EXT
*)
    tmod[indm].ykext:=indt;
    tabt[indt]:=HI(kext);
    tabt[indt+1]:=LO(kext);	  { ���������� (.) EXT }
    indt:=indt+2;
    if dlext<>0 then
      begin
       BLOCKREAD(rfile[i],buf,dlext);	{ ������ EXT }
       for j:=1 to dlext do
	begin
	 tabt[indt]:=buf[j];
	 indt:=indt+1;
	end;
      end;

(*
    ������� �� ����� ������
*)
    FCON(sizect);		     { ���������� ��� }
    BLOCKREAD(rfile[i],buf,2);	     { ���������� (.) REL }
    j:=(buf[1]*256+buf[2])*5+1;      { ����� REL + ������� ����� REL }
    FCON(j);			     { ���������� REL }
    indm:=indm+1;		     { ��������� ���������� ������� }
   end; 	 { PROC MODUL }


(*
     ��������� ��������� ����� ������ �� ����� �����
*)
   procedure MODNAM(nam:string; var mnmd:name);

    var j,ii,k,kk : integer;
	ch	  : char;

    begin

     ii:=1;
     k:=LENGTH(nam);		{ ����� ������ }
     j:=1;

     repeat
       ch:=nam[ii];
       ii:=ii+1;
       kk:=POS(ch,':\.');       { ���� �� ����. ��������? }
       if kk=0 then
	 begin
	  mnmd[j]:=ORD(UPCASE(ch));
	  j:=j+1;
	 end
	else
	 if kk<>3 then j:=1;
     until (kk=3) or (ii>k);
     if j<16 then		 { ���������� ��������� }
       for k:=j to 16 do
	 mnmd[k]:=$20
   end; 	       { PROC MODNAM }

(*
	 ��������� ������� � ����������������� ���������� �������������
*)
  procedure SHEST( kod,nm:integer);
   var j,kk : integer;

   begin
    kk:=kod;
    for j:=0 to 3 do
     begin
      par[nm+4-j]:=digits[kk mod 16+1];
      kk:=kk div 16;
     end;
   end; 	  { PROC SHEST }

(*
	      ��������� ������ ������� ��� ������ � ����� ������� ���
*)
  procedure ZEXT;

   var kex,jp,je,jk,jt :integer;
       fle	       :boolean;

   begin
    jp:=tmod[indm].ykext;	   { ��������� ������� ������ }
    kex:=tabt[jp]*256+tabt[jp+1];  { ���������� (.) EXT }
    jp:=jp+1;
    if kex<>0 then
     begin
      for it:=1 to kex do	   { ����� ��� ��������� ����� }
       begin
	fle:=false;
	if kext<>0 then
	 begin
	  jk:=1;

	  repeat
	    je:=1;

	    repeat
	      fle:=tabt[ip+je-1]=tex[jk].namext[je]; { ��������� ���� }
	      je:=je+1;
	    until (je>16) or not fle;

	    jk:=jk+1;
	  until (jk>kext) or fle;
	 end;
	if not fle then 	    { ����� ����� ���, �������� � ������� }
	 begin
	  kext:=kext+1; 	    { ��������� ���������� ����� }
	  for je:=1 to 16 do
	    tex[kext].namext[je]:=tabt[jp+je];
	  tex[kext].tip:=$ff;	    { ������� �������������� ����� }
	 end;
	jp:=jp+20;		    { ������� � ����� ����� }
       end
     end;
   end; 	{ PROC	ZEXT }

(*
	  ��������� �������� ����� ������
*)
  procedure OPENR(var nf:string; ii:integer);

   var jf : integer;
{$i-}
    begin
     ASSIGN(rfile[ii],nf);
     RESET(rfile[ii],1);
     if ioresult <> 0 then
      begin
       WRITELN(' LINK  ERROR FILE ',nf);
       if ii<>1 then
	 for jf:=1 to ii-1 do	     { �������� �������� ������ ������ }
	   CLOSE(rfile[jf]);
       HALT(2);
     end;
    end;	{ PROC	OPENR }
{$i+}

(*
       ��������� ������ � ������
*)
  procedure ERRMOD;
   var jf : integer;

   begin
    WRITELN('LINK  ���� ',namf,' �� ��������� ������ ');
    for jf:=1 to i do	     { �������� �������� ������ ������ }
      CLOSE(rfile[jf]);
    HALT(2);
   end; 	 { PROC ERRMOD }

(*
       ��������� ������ � �����
*)
  procedure ERRDISK(j : integer; nf : string);
   var jf : integer;

   begin
     WRITELN(' LINK  ERROR FILE ',nf);
     for jf:=1 to kfm do	{ �������� �������� ������ ������ }
       CLOSE(rfile[jf]);
     if j>1 then
      begin
       ERASE(wfile);
       CLOSE(wfile);
      end;
      ERASE(fprin);
      CLOSE(fprin);
      HALT(2);
   end; 	   { PROC  ERRDISK }

(*
	 ������ � ����������
*)
  procedure ERRPAR;

   begin
    WRITELN(' LINK ������ � ���������� ');

    writeln('usage: UniLink MainModule [Modules] [/L<ListFile>] [/P]');
    WRITELN('       /P - �������� ������������ �� ������� $100 ����.');
    HALT(4);
   end; 	   { PROC ERRPAR }

(*
    �������������� �������������
*)
  procedure ERRNI;

   var stp : string[17];
       ji  : integer;

   begin
    stp:=' ';
    for ji:=1 to 16 do
      stp:=stp + char(tex[inex].namext[ji]);
    WRITELN(' ������������� ',stp,' �����������.');
    flni:=true;
   end;

(*
	 ������ �����

	  ���� ������� ����������
*)

begin
  writeln('UniLINK. Version 1.01. (c) 1989 "������".');
  digits:='0123456789ABCDEF';      { ������������� ������������� }
  nfprin:=' ';
  ip:=PARAMCOUNT;		   { ���������� ���������� }
  if ip<1 then ERRPAR;
  kfm:=0;
  flv:=false;			   { �� ����������� }
  for i:=1 to ip do		   { ���� ������� ���������� }
   begin
    par:=PARAMSTR(i);		   { ��������� �������� }
    if par[1] = '/' then
(*	������� ����� ������	     *)
       if UPCASE(par[2])='P' then
	 flv:=true		   { ���������� ������������ }
	else
	 if UPCASE(par[2])='L' then
	   begin
	    nfprin:=par;
	    DELETE(nfprin,1,2);
	   end
	  else
	   ERRPAR
     else
      begin
       kfm:=kfm+1;		   { ����� ������ }
       it:=POS('.',par);           { ec�� ��c�������? }
       if it=0 then		   { ��� }
	 par:=par+'.OBJ';
       nam_mod[kfm]:=par;
      end;
   end;
  if nfprin=' ' then
    nfprin:='CON';
  if kfm=0 then ERRPAR;

(*
      ������ ������  LINK
*)
  indm:=1;				  { ������ ������� ����� TABT }
  indt:=1;				  { ������ ������� ������� TMOD }

  for i:=1 to kfm do			  { ���� �� ������ }
   begin
    namf:=nam_mod[i];			  { ��� ���������� ����� }
    OPENR(namf,i);			  { ������� ���� }
(*    nmodt:=0; 			{ ������� ����� ������ � ����������}*)
    pozf:=0;				  { ������� ������ ����� }
    BLOCKREAD(rfile[i],buf,32); 	  { ������ ��������� }

    MODNAM(namf,mnm);			  { �������� ��� ������ �� ����� ����� }
    if (buf[1]=$0b) and (buf[2]=$b0) then
      begin
(*
     ��������� ����������
*)
       kmodl:=buf[5]*256+buf[6];	   { ���������� ������� � ���������� }
       for i1:=1 to kmodl do		   { ���� �� ������� }
	begin
	 BLOCKREAD(rfile[i],mnm,12);	   { ��� ������ � ����� }
	 for i2:=9 to 16 do
	   mnm[i2]:=$20;		   { ��������� ��� ��������� }
	 pozf:=FILEPOS(rfile[i]);	   { ������� ������ � ����� }
	 BLOCKREAD(rfile[i],buf,32);	   { ��������� ������ }
	 nmodt:=nmodt+1;		   { ����� ������ }
	 MODUL; 			   { ���������� ������ }
	end;
      end

     else				   { ������� ������ }
      if (buf[1]=$5a) and (buf[2]=$a5) then
	MODUL
       else
	ERRMOD;
   end; 	{ Ko��� 1 ������� }
   kmoda:=indm; 			   { ����� ���������� ������� }

(*
	    A������� ��������� ������
*)
  kmod:=1;			  { �������������� ��������� 1 ������ }
  flni:=false;			  { ���� ��������������� �������������� }
  tvmod[1].nom:=1;
  tvmod[1].bas:=0;		  { ���� ������ }
  kext:=0;			  { ko�������� (.) EXT }
  tbas:=tmod[1].sizec;
  if flv then
    tbas:=((tbas + $ff) div $100) * $100;  { ������������ �� ������� �������� }
  indm:=1;
  ZEXT; 			  { ��������� ���� EXT � ������� TEX }

(*
   ����������� EXT
*)
  if kext<>0 then	      { IF0 }
   begin
    inex:=1;			  { ������ EXT }

    repeat		     {REP 1 }
      indm:=0;			  { ������ ������ � TMOD }
      flt:=false;		  { ���� �������� ����� }

      repeat		      {REP 2 }
	indm:=indm+1;
	ip:=tmod[indm].ykpb;	  { ��������� PUBL }
	kpb:=tabt[ip]*256+tabt[ip+1];
	ip:=ip+1;
	if kpb <> 0 then
	 begin
	  i1:=1;

	  repeat		{ REP 3 }
	    i2:=1;

	    repeat		   { REP 4 }
	      flt:=tex[inex].namext[i2] = tabt[ip+i2];	 { ��������� ���� }
	      i2:=i2+1;
	    until (i2>16) or not flt;	     {END REP 4 }

	    i1:=i1+1;
	    ip:=ip+20;		     { ����� ���������� EXT }
	  until (i1>kpb) or flt;  { END REP 3 }
	 end;
      until (indm>kmoda) or flt; {END REP 2 }

      if not flt then ERRNI	    { ����������� EXT }
       else
	begin	      {  IF2}
(*
	 ����� ������������ EXT - PUBL
	  INDM - ����� ������ � TMOD
	 ��������� ��������� �� ������ �����
*)
	 ip:=ip-3;		    { ������ (.) PUBL �� ������ � ���� }
	 i1:=0;
	 repeat
	   i1:=i1+1;
	   flt:=tvmod[i1].nom=indm;   { ���� �� ������ � TVMOD }
	 until (i1=kmod) or flt;

	 if not flt then
	  begin
(*
	 ����� ������ �������� ��� � TMOD
	  � ������������ ��� ���
*)
	   kmod:=kmod+1;
	   tvmod[kmod].nom:=indm;
	   tvmod[kmod].bas:=tbas;	{ ���� ������ }
	   tbas:=tbas+tmod[indm].sizec;
	   if flv then			 { ���������? }
	     tbas:=((tbas + $ff) div $100) * $100;  { ������������ �� ������� �������� }
	   ZEXT;			{ ������������ EXT }
	   i1:=kmod;
	  end;

	 if tabt[ip+2] <> 0 then	{ �������� ���� }
	   tex[inex].adr:=tabt[ip]*256+tabt[ip+1]   { CONST }
	  else
	   tex[inex].adr:=tabt[ip]*256+tabt[ip+1]+tvmod[i1].bas;  { ADRES }

	 tex[inex].tip:=tabt[ip+2];	 { ��� }
	end; {	 IF2 }
      inex:=inex+1;
    until inex > kext;	  { END REP 1 }
   end; 	    { END IF 0 }

(*
      �������� ����� ����������������
*)
  if flni then			   { ���� �������������� �������������� }
    begin			   { ��������� ������� }
     for i:=1 to kfm do
       CLOSE(rfile[i]);
     WRITELN('  LINK  ��������� ���������� ');
     HALT(1);
    end;
(*
      ������ ������  LINK
*)
  namfw:=nam_mod[1];	       { �������� ��� ���. �����}
  i:=POS('.',namfw);           { ����� ����� }
  if i<>0 then DELETE(namfw,i,4); { ������� ���������� }
  namfp:=namfw + '.$pg';         { ��� ����.����� }
  namfw:=namfw + '.pgm';
(*
	�������� ���������� � ����.�����.
*)
  ASSIGN(fprin,nfprin);
  REWRITE(fprin);
  if ioresult<>0 then ERRDISK(0,nfprin);
  {$i-}
  ASSIGN(wfile,namfw);
  REWRITE(wfile,1);
  if ioresult<>0 then ERRDISK(1,namfw);

  ASSIGN(pfile,namfp);
  REWRITE(pfile,1);
  if ioresult<>0 then ERRDISK(2,namfp);

  WRITELN(fprin,'           ����������� ������ ',namfw);
  WRITELN;
  {$i+}
  for i:=1 to 16 do		    { ���� ��������� BUF }
    buf[i]:=0;
  BLOCKWRITE(wfile,buf,16);	    { ������ ��������� }
(*
       ���� �� ������� ���. ������� TVMOD
*)
  klrel:=0;			    { ���������� ����� REL }

  for i:=1 to kmod do		    { FOR1 �c������ ���� }
   begin
    i1:=tvmod[i].nom;		     { ����� � TMOD }
    i2:=tmod[i1].hand;		     { ����� ����� }

    if FILEPOS(rfile[i2])<>tmod[i1].nmod then
      SEEK(rfile[i2],tmod[i1].nmod);  { �c������� ����� �� ������ ������ }

    BLOCKREAD(rfile[i2],buf,32);     { ��������� ������ }

    if i=1 then
     begin			   { ��������� ����� ������� ��������� }
      adrzs:=buf[15];
      adrzm:=buf[16];
     end;

    kpb:=buf[5]*256+buf[6];	     { �����. (.) PUBL }
    kext:=buf[7]*256+buf[8];	     { �����. (.) EXT }
    dlpb:=kpb*20;
    dlext:=kext*20;
    sizect:=buf[9]*256+buf[10];      { ������ ���� }

    if dlpb<>0 then
      BLOCKREAD(rfile[i2],buf,dlpb);	    { ���������� PUBL }

    if dlext<>0 then
      BLOCKREAD(rfile[i2],buf,dlext);
    BLOCKREAD(rfile[i2],tabt,sizect);  { ��������� ��� }

    sizev:=sizect;
    if flv then
      sizev:=((sizect+$ff) div $100)* $100; { ���������� ��� }
      if sizev<>sizect then
	for it:=sizect+1 to sizev do
	  tabt[it]:=0;			  { ��������� ��� ������ }

(*
       ����� �� ������ ����� ������ � ��� ����
*)
    WRITELN(fprin,'   ',tmod[i1].namem);
    par:='            ';
    SHEST(tvmod[i].bas,1);
    ir:=tvmod[i].bas+sizect-1;
    SHEST(ir,7);
    WRITELN(fprin,'          ',par);

(*
     ���� �� ������ REL � ������������ ����
*)
    BLOCKREAD(rfile[i2],mnm,2); 	{ ������ ���������� ����� }
    ktrel:=mnm[1]*256+mnm[2];

    if ktrel<>0 then
      for ir:=1 to ktrel do
       begin
	fltp:=true;			  { ���� ���� (.) - REL }
	BLOCKREAD(rfile[i2],mnm,5);	  { ������� REL }
	znt:=mnm[2]*256+mnm[3]; 	  { �������� }

	if mnm[1] < $80 then		  { ������� ����� }
	  znt:=znt+tvmod[i1].bas	  { ����������� ����� }

	 else				  { ������� ����� }
	  begin
	   znt:=znt*20; 	      { �������� � ������� EXT � ���� }
	   inex:=0;			  { ������ TEX }
(*
	 ����� ������� ����� � TEX
*)
	   repeat
	     inex:=inex+1;
	     it:=1;
	     repeat
	       flt := tex[inex].namext[it] = buf[znt+it]; { ������� ��������� }
	       it:=it+1;
	     until (it > 16) or not flt;     { ���� �� ����� ��� �� ����� }
	   until (inex = kext) or flt;	{ ���� �� ����� ���  ����� }

	   if not flt then		   { ����� �� ������� }
	     begin
	      fltp:=false;		    { ��� CONST }
	      znt:=0;			    { �������� ������������ }
	     end
	    else			    { �����  ������� }
	     begin
	      fltp:=tex[inex].tip=0;
	      znt:=tex[inex].adr;
	     end;
	  end;	    {IF}

(*
	 ����������� ����
*)
	  it:=mnm[4]*256+mnm[5]+1;	    { �������� � ���� ��� ����������� }
	  fls:=mnm[1] and 2 = 2;		   { ���� �������� ����� }
	  if ODD(mnm[1]) then		     { ���� �������� ����� �������� }
	    tabt[it+1]:=LO(znt);	{ ��������� ������� ���� }
	  if fls then
	   begin
	    tabt[it]:=HI(znt);	{ ��������� ������� ���� }

	    if fltp then		    { ����� REL }
	     begin
	      it:=it+tvmod[i].bas-1;	    { �������� � ����������� ������ }
	      mnm[1]:=HI(it);
	      mnm[2]:=LO(it);
	      klrel:=klrel+1;
	      BLOCKWRITE(wfile,mnm,2);	   { ������� ��������� ����� }
	     end;
	   end;
       end;	 {FOR �� ������ REL }

    BLOCKWRITE(pfile,tabt,sizev);	    { ������� ������������ ��� }
   end;       {FOR �� ������� }

(*
      ���������� ��� �� �������������� ����� � ��������������
*)
  pozf:=0;
  SEEK(pfile,pozf);			    { ���������� ���� � ������ }
  dlpb:=tbas;				    { ����� ���� }
  pozf:=FILEPOS(wfile); 		    { ��������� ������� ���.����� }
  repeat
    if dlpb < maxd then it:=dlpb else it:=maxd;
    dlpb:=dlpb-it;
    BLOCKREAD(pfile,tabt,it);
    BLOCKWRITE(wfile,tabt,it);
  until dlpb = 0;
(*
	������������ � ������ ���������
*)
  buf[1]:=$a5;
  buf[2]:=$5a;
  buf[3]:=HI(klrel);
  buf[4]:=LO(klrel);
  buf[5]:=(pozf div 256) mod 256;
  buf[6]:=pozf mod 256;
  buf[7]:=HI(tbas);
  buf[8]:=LO(tbas);
  buf[9]:=adrzs;
  buf[10]:=adrzm;

  pozf:=0;
  SEEK(wfile,pozf);			    { ���������� ���� � ������ }
  BLOCKWRITE(wfile,buf,10);
(*
       �������� ���� ������ � ���������� ������
*)
  for i:=1 to kfm do
    CLOSE(rfile[i]);
  CLOSE(wfile);
  ERASE(pfile);
  CLOSE(pfile);
  CLOSE(fprin);
  WRITELN('   LINK  K���� ������ ');
  HALT(0);
 end.
