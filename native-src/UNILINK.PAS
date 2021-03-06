(******************************************************
*						      *
*	        '»         *
*		       UniLINK			      *
*						      *
*	       18.07.1989 £.   17.10	V.1.1	      *
*	       (c) 1989 Leonid Curak		      *
*******************************************************)

(*
	     ¯¨± ­¨¥ ²¨¯®¢
*)
   CONST  maxd=2000;		       { ¤«¨­  ¬ ±±¨¢  BUF }
	  maxt=15000;		       { ¤«¨­  ­ ±±¨¢  TABT }

   TYPE   name	 = array[1..16] of byte;

	  tmods  = record	       { ±²°³ª²³°  ² ¡«¨¶» ¬®¤³«¥© TMOD }
	       hand  :byte;	       { ­®¬¥° ´ ©«  }
	       nmod  :longint;	       { ¯®§¨¶¨¿ ¢ ´ ©«¥ }
	       sizec :integer;	       { ° §¬¥° ª®¤  }
	       ykpb  :integer;	       { ³ª § ²¥«¼ ² ¡«¨¶» PUBL }
	       ykext :integer;	       { ³ª § ²¥«¼ ² ¡«¨¶» EXT }
	       namem :array[1..8] of char; { ¨¬¿ ¬®¤³«¿ }
	   end;

	  tvmods = record	       { ±²°³ª²³°  ² ¡«¨¶» ¨±¯®«¼§³¥¬»µ ¬®¤³«¥©}
	       nom   :integer;	       { ±±»«ª  ­  ² ¡«¨¶³ TMOD }
	       bas   :integer;	       { ¡ §  ¬®¤³«¿ }
	   end;

	  texs	 = record	       { ±²°³ª²³°  ² ¡«¨¶» EXT }
	       namext:name;	       { ¨¬¿ ²®·ª¨  }
	       adr   :integer;	       { §­ ·¥­¨¥ ²®·ª¨ }
	       tip   :byte;	       { ²¨¯ ²®·ª¨ }
	   end;

	  tmodt  = array[1..256] of tmods;
	  tvmodt = array[1..256] of tvmods;
	  textt  = array[1..1000] of texs;

(*
	    ¯¨± ­¨¥ ¯¥°¥¬¥­­»µ
*)
   VAR	  tabt			  : array[1..maxt] of byte; { ¡³´¥° ²®·¥ª  ¨ PUBL }
	  buf			  : array[1..maxd] of byte; { ¡³´¥° ·²¥­¨¿/§ ¯¨±¨ }
	  rfile 		  : array[1..32] of file;   { ³ª § ²¥«¨ ´ ©«®¢ ·²¥­¨¿ }
	  nam_mod		  : array[1..32] of string[40]; { ¨¬¥­  ´ ©«®¢ ·²¥­¨¿ }
	  mnm			  : name;
	  digits		  : array[1..16] of char;   { ¯¥°¥ª®¤¨°®¢ª  }

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
	   »
*)

(*
      °®¶¥¤³°  ¯°®¯³±ª  ´ ©« 
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
	     °®¶¥¤³°  ®¡° ¡®²ª¨ ¬®¤³«¿ ­  1 ¯°®µ®¤¥
*)
  procedure MODUL;

   var j  :integer;

   begin
    kpb:=buf[5]*256+buf[6];	     { ª®«¨·. (.) PUBL }
    kext:=buf[7]*256+buf[8];	     { ª®«¨·. (.) EXT }
    dlpb:=kpb*20;
    dlext:=kext*20;
    sizect:=buf[9]*256+buf[10];      { ° §¬¥° ª®¤  }
(*
	 ¯®«­¥­¨¥ ½«¥¬¥­²  ² ¡«¨¶» TMOD
*)
    tmod[indm].hand:=i; 	     { ­®¬¥° ´ ©«  }
    tmod[indm].nmod:=pozf;	     { ¯®§¨¶¨¿ ¬®¤³«¿ ¢ ´ ©«¥ }
    tmod[indm].ykpb:=indt;
    tmod[indm].sizec:=sizect;	     { ° §¬¥° ¬®¤³«¿ }
    for j:=1 to 8 do		     { ¨¬¿ ¬®¤³«¿ }
      tmod[indm].namem[j]:=chr(mnm[j]);

(*
	 ¯¨±¼ ² ¡«¨¶» PUBL
*)
    tabt[indt]:=buf[5];
    tabt[indt+1]:=buf[6];	      { ª®«¨·¥±²¢® (.) PUBL }
    indt:=indt+2;
    if dlpb<>0 then
      begin
       BLOCKREAD(rfile[i],buf,dlpb);   { ·²¥­¨¥ PUBL }
       for j:=1 to dlpb do
	begin
	 tabt[indt]:=buf[j];
	 indt:=indt+1;
	end;
      end
     else			       {­¥² PUBL ¯®¬¥±²¨¬ ²®·ª³ § ¯³±ª  }
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
	  ¯¨±¼ ² ¡«¨¶» EXT
*)
    tmod[indm].ykext:=indt;
    tabt[indt]:=HI(kext);
    tabt[indt+1]:=LO(kext);	  { ª®«¨·¥±²¢® (.) EXT }
    indt:=indt+2;
    if dlext<>0 then
      begin
       BLOCKREAD(rfile[i],buf,dlext);	{ ·²¥­¨¥ EXT }
       for j:=1 to dlext do
	begin
	 tabt[indt]:=buf[j];
	 indt:=indt+1;
	end;
      end;

(*
    °®¯³±ª ¤® ª®­¶  ¬®¤³«¿
*)
    FCON(sizect);		     { ¯°®¯³±²¨²¼ ª®¤ }
    BLOCKREAD(rfile[i],buf,2);	     { ª®«¨·¥±²¢® (.) REL }
    j:=(buf[1]*256+buf[2])*5+1;      { ¤«¨­  REL + ¯°¨§­ ª ª®­¶  REL }
    FCON(j);			     { ¯°®¯³±²¨²¼ REL }
    indm:=indm+1;		     { ³¢¥«¨·¨²¼ ª®«¨·¥±²¢® ¬®¤³«¥© }
   end; 	 { PROC MODUL }


(*
     °®¶¥¤³°  ¢»¤¥«¥­¨¿ ¨¬¥­¨ ¬®¤³«¿ ¨§ ¨¬¥­¨ ´ ©« 
*)
   procedure MODNAM(nam:string; var mnmd:name);

    var j,ii,k,kk : integer;
	ch	  : char;

    begin

     ii:=1;
     k:=LENGTH(nam);		{ ¤«¨­  ±²°®ª¨ }
     j:=1;

     repeat
       ch:=nam[ii];
       ii:=ii+1;
       kk:=POS(ch,':\.');       { ®¤¨­ ¨§ ±¯¥¶. ±¨¬¢®«®¢? }
       if kk=0 then
	 begin
	  mnmd[j]:=ORD(UPCASE(ch));
	  j:=j+1;
	 end
	else
	 if kk<>3 then j:=1;
     until (kk=3) or (ii>k);
     if j<16 then		 { ¤®¯®«­¥­¨¥ ¯°®¡¥« ¬¨ }
       for k:=j to 16 do
	 mnmd[k]:=$20
   end; 	       { PROC MODNAM }

(*
	 °®¶¥¤³°  ¯¥°¢®¤  ¢ ¸¥±²­ ¤¶ ²¨°¨·­®¥ ±¨¬¢®«¼­®¥ ¯°¥¤±² ¢«¥­¨¥
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
	      °®¶¥¤³°  § ¯¨±¨ ² ¡«¨¶»  ¬®¤³«¿ ¢ ®¡¹³¾ ² ¡«¨¶³ 
*)
  procedure ZEXT;

   var kex,jp,je,jk,jt :integer;
       fle	       :boolean;

   begin
    jp:=tmod[indm].ykext;	   { ³ª § ²¥«¼ ² ¡«¨¶» ¬®¤³«¿ }
    kex:=tabt[jp]*256+tabt[jp+1];  { ª®«¨·¥±²¢® (.) EXT }
    jp:=jp+1;
    if kex<>0 then
     begin
      for it:=1 to kex do	   { ¯®¨±ª ³¦¥ § ¯¨± ­®© ²®·ª¨ }
       begin
	fle:=false;
	if kext<>0 then
	 begin
	  jk:=1;

	  repeat
	    je:=1;

	    repeat
	      fle:=tabt[ip+je-1]=tex[jk].namext[je]; { ±° ¢­¥­¨¥ ¨¬¥­ }
	      je:=je+1;
	    until (je>16) or not fle;

	    jk:=jk+1;
	  until (jk>kext) or fle;
	 end;
	if not fle then 	    { ² ª®© ²®·ª¨ ­¥², ¯®¬¥±²¨¬ ¢ ² ¡«¨¶³ }
	 begin
	  kext:=kext+1; 	    { ³¢¥«¨·¨²¼ ª®«¨·¥±²¢® ²®·¥ª }
	  for je:=1 to 16 do
	    tex[kext].namext[je]:=tabt[jp+je];
	  tex[kext].tip:=$ff;	    { ¯°¨§­ ª ­¥®¯°¥¤¥«¥­­®© ²®·ª¨ }
	 end;
	jp:=jp+20;		    { ¯¥°¥µ®¤ ª ­®¢®© ²®·ª¥ }
       end
     end;
   end; 	{ PROC	ZEXT }

(*
	  °®¶¥¤³°  ®²ª°»²¨¿ ´ ©«  ·²¥­¨¿
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
	 for jf:=1 to ii-1 do	     { § ª°»²¨¥ ®²ª°»²»µ ´ ©«®¡ ·²¥­¨¿ }
	   CLOSE(rfile[jf]);
       HALT(2);
     end;
    end;	{ PROC	OPENR }
{$i+}

(*
       °®¶¥¤³°  ®¸¨¡ª¨ ¢ ¬®¤³«¥
*)
  procedure ERRMOD;
   var jf : integer;

   begin
    WRITELN('LINK   ©« ',namf,' ­¥ ®¡º¥ª²­»© ¬®¤³«¼ ');
    for jf:=1 to i do	     { § ª°»²¨¥ ®²ª°»²»µ ´ ©«®¢ ·²¥­¨¿ }
      CLOSE(rfile[jf]);
    HALT(2);
   end; 	 { PROC ERRMOD }

(*
       °®¶¥¤³°  ®¸¨¡ª¨ ¢ ´ ©«¥
*)
  procedure ERRDISK(j : integer; nf : string);
   var jf : integer;

   begin
     WRITELN(' LINK  ERROR FILE ',nf);
     for jf:=1 to kfm do	{ § ª°»²¨¥ ®²ª°»²»µ ´ ©«®¢ ·²¥­¨¿ }
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
	 ¸¨¡ª  ¢ ¯ ° ¬¥²° µ
*)
  procedure ERRPAR;

   begin
    WRITELN(' LINK ®¸¨¡ª  ¢ ¯ ° ¬¥²° µ ');

    writeln('usage: UniLink MainModule [Modules] [/L<ListFile>] [/P]');
    WRITELN('       /P - ¯ ° ¬¥²° ¢»° ¢­¨¢ ­¨¿ ­  £° ­¨¶³ $100 ¡ ©².');
    HALT(4);
   end; 	   { PROC ERRPAR }

(*
    ¥®¯°¥¤¥«¥­­»© ¨¤¥­²¨´¨ª ²®°
*)
  procedure ERRNI;

   var stp : string[17];
       ji  : integer;

   begin
    stp:=' ';
    for ji:=1 to 16 do
      stp:=stp + char(tex[inex].namext[ji]);
    WRITELN(' ¤¥­²¨´¨ª ²®° ',stp,' ­¥®¯°¥¤¥«¥­.');
    flni:=true;
   end;

(*
	  

	  «®ª ° §¡®°  ¯ ° ¬¥²°®¢
*)

begin
  writeln('UniLINK. Version 1.01. (c) 1989 "".');
  digits:='0123456789ABCDEF';      { ¨­¨¶¨ «¨§ ¶¨¿ ¯¥°¥ª®¤¨°®¢ª¨ }
  nfprin:=' ';
  ip:=PARAMCOUNT;		   { ª®«¨·¥±²¢® ¯ ° ¬¥²°®¢ }
  if ip<1 then ERRPAR;
  kfm:=0;
  flv:=false;			   { ­¥ ¢»° ¢­¨¢ ²¼ }
  for i:=1 to ip do		   { ¶¨ª« ° §¡®°  ¯ ° ¬¥²°®¢ }
   begin
    par:=PARAMSTR(i);		   { ®·¥°¥¤­®© ¯ ° ¬¥²° }
    if par[1] = '/' then
(*	§ ¤ ­¨¥ ´ ©«  ¯¥· ²¨	     *)
       if UPCASE(par[2])='P' then
	 flv:=true		   { ³±² ­ ¢¨²¼ ¢»° ¢­¨¢ ­¨¥ }
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
       kfm:=kfm+1;		   { ­®¢»© ¬®¤³«¼ }
       it:=POS('.',par);           { ec²¼ ° c¸¨°¥­¨¥? }
       if it=0 then		   { ­¥² }
	 par:=par+'.OBJ';
       nam_mod[kfm]:=par;
      end;
   end;
  if nfprin=' ' then
    nfprin:='CON';
  if kfm=0 then ERRPAR;

(*
      ¥°¢»© ¯°®µ®¤  LINK
*)
  indm:=1;				  { ¨­¤¥ª± ¬ ±±¨¢  ²®·¥ª TABT }
  indt:=1;				  { ¨­¤¥ª± ² ¡«¨¶» ¬®¤³«¥© TMOD }

  for i:=1 to kfm do			  { ¶¨ª« ¯® ´ ©« ¬ }
   begin
    namf:=nam_mod[i];			  { ¨¬¿ ®·¥°¥¤­®£® ´ ©«  }
    OPENR(namf,i);			  { ®²ª°»²¼ ´ ©« }
(*    nmodt:=0; 			{ ²¥ª³¹¨© ­®¬¥° ¬®¤³«¿ ¢ ¡¨¡«¨®²¥ª¥}*)
    pozf:=0;				  { ¯®§¨¶¨¿ ­ · «  ´ ©«  }
    BLOCKREAD(rfile[i],buf,32); 	  { ·²¥­¨¥ § £®«®¢ª  }

    MODNAM(namf,mnm);			  { ¢»¤¥«¨²¼ ¨¬¿ ¬®¤³«¿ ¨§ ¨¬¥­¨ ´ ©«  }
    if (buf[1]=$0b) and (buf[2]=$b0) then
      begin
(*
     ¡° ¡®²ª  ¡¨¡«¨®²¥ª¨
*)
       kmodl:=buf[5]*256+buf[6];	   { ª®«¨·¥±²¢® ¬®¤³«¥© ¢ ¡¨¡«¨®²¥ª¥ }
       for i1:=1 to kmodl do		   { ¶¨ª« ¯® ¬®¤³«¿¬ }
	begin
	 BLOCKREAD(rfile[i],mnm,12);	   { ¨¬¿ ¬®¤³«¿ ¨ ¤«¨­  }
	 for i2:=9 to 16 do
	   mnm[i2]:=$20;		   { ¤®¯®«­¨²¼ ¨¬¿ ¯°®¡¥« ¬¨ }
	 pozf:=FILEPOS(rfile[i]);	   { ¯®§¨¶¨¿ ¬®¤³«¿ ¢ ´ ©«¥ }
	 BLOCKREAD(rfile[i],buf,32);	   { § £®«®¢®ª ¬®¤³«¿ }
	 nmodt:=nmodt+1;		   { ­®¬¥° ¬®¤³«¿ }
	 MODUL; 			   { ®¡° ¡®² ²¼ ¬®¤³«¼ }
	end;
      end

     else				   { ¯°®±²®© ¬®¤³«¼ }
      if (buf[1]=$5a) and (buf[2]=$a5) then
	MODUL
       else
	ERRMOD;
   end; 	{ Ko­¥¶ 1 ¯°®µ®¤  }
   kmoda:=indm; 			   { ®¡¹¥¥ ª®«¨·¥±²¢® ¬®¤³«¥© }

(*
	    A«£®°¨²¬ ³±² ­®¢ª¨ ±¢¿§®ª
*)
  kmod:=1;			  {  ¢²®¬ ²¨·¥±ª®¥ ¢ª«¾·¥­¨¥ 1 ¬®¤³«¿ }
  flni:=false;			  { ´« £ ­¥®¯°¥¤¥«¥­­®£® ¨¤¥­²¨´¨ª ²®°  }
  tvmod[1].nom:=1;
  tvmod[1].bas:=0;		  { ¡ §  ¬®¤³«¿ }
  kext:=0;			  { ko«¨·¥±²¢® (.) EXT }
  tbas:=tmod[1].sizec;
  if flv then
    tbas:=((tbas + $ff) div $100) * $100;  { ¢»° ¢­¨¢ ­¨¥ ­  £° ­¨¶³ ±²° ­¨¶» }
  indm:=1;
  ZEXT; 			  { ¯®¬¥±²¨²¼ ¡«®ª EXT ¢ ² ¡«¨¶³ TEX }

(*
   ¯°¥¤¥«¥­¨¥ EXT
*)
  if kext<>0 then	      { IF0 }
   begin
    inex:=1;			  { ¨­¤¥ª± EXT }

    repeat		     {REP 1 }
      indm:=0;			  { ¨­¤¥ª± ¬®¤³«¿ ¢ TMOD }
      flt:=false;		  { ´« £ ­ ©¤¥­®© ²®·ª¨ }

      repeat		      {REP 2 }
	indm:=indm+1;
	ip:=tmod[indm].ykpb;	  { ³ª § ²¥«¼ PUBL }
	kpb:=tabt[ip]*256+tabt[ip+1];
	ip:=ip+1;
	if kpb <> 0 then
	 begin
	  i1:=1;

	  repeat		{ REP 3 }
	    i2:=1;

	    repeat		   { REP 4 }
	      flt:=tex[inex].namext[i2] = tabt[ip+i2];	 { ±° ¢­¥­¨¥ ¨¬¥­ }
	      i2:=i2+1;
	    until (i2>16) or not flt;	     {END REP 4 }

	    i1:=i1+1;
	    ip:=ip+20;		     {  ¤°¥± ±«¥¤³¾¹¥£® EXT }
	  until (i1>kpb) or flt;  { END REP 3 }
	 end;
      until (indm>kmoda) or flt; {END REP 2 }

      if not flt then ERRNI	    { ­¥®¯°¥¤¥«¥­ EXT }
       else
	begin	      {  IF2}
(*
	  ¸«¨ ±®®²¢¥²±²¢¨¥ EXT - PUBL
	  INDM - ­®¬¥° ¬®¤³«¿ ¡ TMOD
	 ¯°®¢¥°¿¥¬ ¯®¿¢«¿«±¿ «¨ ¬®¤³«¼ ° ­¥¥
*)
	 ip:=ip-3;		    { ¨­¤¥ª± (.) PUBL ¥¥  ¤°¥±  ¨ ²¨¯  }
	 i1:=0;
	 repeat
	   i1:=i1+1;
	   flt:=tvmod[i1].nom=indm;   { ¥±²¼ «¨ ¬®¤³«¼ ¢ TVMOD }
	 until (i1=kmod) or flt;

	 if not flt then
	  begin
(*
	 ®¢»© ¬®¤³«¼ ¯®¬¥¹ ¥¬ ¥£® ¢ TMOD
	  ¨ ¯®¤±®¥¤¨­¿¥¬ ¥£® 
*)
	   kmod:=kmod+1;
	   tvmod[kmod].nom:=indm;
	   tvmod[kmod].bas:=tbas;	{ ¡ §  ¬®¤³«¿ }
	   tbas:=tbas+tmod[indm].sizec;
	   if flv then			 { ¢»°®¢­¿²¼? }
	     tbas:=((tbas + $ff) div $100) * $100;  { ¢»° ¢­¨¢ ­¨¥ ­  £° ­¨¶³ ±²° ­¨¶» }
	   ZEXT;			{ ¯®¤±®¥¤¨­¨²¼ EXT }
	   i1:=kmod;
	  end;

	 if tabt[ip+2] <> 0 then	{ ¯°®¢¥°ª  ²¨¯  }
	   tex[inex].adr:=tabt[ip]*256+tabt[ip+1]   { CONST }
	  else
	   tex[inex].adr:=tabt[ip]*256+tabt[ip+1]+tvmod[i1].bas;  { ADRES }

	 tex[inex].tip:=tabt[ip+2];	 { ²¨¯ }
	end; {	 IF2 }
      inex:=inex+1;
    until inex > kext;	  { END REP 1 }
   end; 	    { END IF 0 }

(*
      °®¢¥°ª  ´« £  ­¥®¯°¥¤¥«¥­­®±²¨
*)
  if flni then			   { ¡»«¨ ­¥®¯°¥¤¥«¥­­»¥ ¨¤¥­²¨´¨ª ²®°» }
    begin			   { § ¢¥°¸ ¥¬ °¯ ¡®²³ }
     for i:=1 to kfm do
       CLOSE(rfile[i]);
     WRITELN('  LINK  ¢ °¨©­®¥ § ¢¥°¸¥­¨¥ ');
     HALT(1);
    end;
(*
      ²®°®© ¯°®µ®¤  LINK
*)
  namfw:=nam_mod[1];	       { ¯®«³· ¥¬ ¨¬¿ °¥§. ´ ©« }
  i:=POS('.',namfw);           { ­®¬¥° ²®·ª¨ }
  if i<>0 then DELETE(namfw,i,4); { ³¤ «¨²¼ ¯ ±¸¥°¥­¨¥ }
  namfp:=namfw + '.$pg';         { ¨¬¿ ¯°®¬.´ ©«  }
  namfw:=namfw + '.pgm';
(*
	²ª°»²¨¥ °¥§³«¼² ²  ¨ ¯°®¬.´ ©« .
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

  WRITELN(fprin,'            £°³§®·­»© ¬®¤³«¼ ',namfw);
  WRITELN;
  {$i+}
  for i:=1 to 16 do		    { ¶¨ª« ®¡­³«¥­¨¿ BUF }
    buf[i]:=0;
  BLOCKWRITE(wfile,buf,16);	    { § ¡¨²¼ § £®«®¢®ª }
(*
       ¨ª« ¯® ² ¡«¨¶¥ ¢ª«. ¬®¤³«¥© TVMOD
*)
  klrel:=0;			    { ª®«¨·¥¶²¢® ²®·¥ª REL }

  for i:=1 to kmod do		    { FOR1 ®c­®¢­®© ¶¨ª« }
   begin
    i1:=tvmod[i].nom;		     { ­®¬¥° ¢ TMOD }
    i2:=tmod[i1].hand;		     { ­®¬¥° ´ ©«  }

    if FILEPOS(rfile[i2])<>tmod[i1].nmod then
      SEEK(rfile[i2],tmod[i1].nmod);  { ³c² ­®¢ª  ´ ©«  ­  ­ · «® ¬®¤³«¿ }

    BLOCKREAD(rfile[i2],buf,32);     { § £®«®¢®ª ¬®¤³«¿ }

    if i=1 then
     begin			   { § ¯®¬­¨²¼  ¤°¥± § ¯³±ª  ¯°®£° ¬¬» }
      adrzs:=buf[15];
      adrzm:=buf[16];
     end;

    kpb:=buf[5]*256+buf[6];	     { ª®«¨·. (.) PUBL }
    kext:=buf[7]*256+buf[8];	     { ª®«¨·. (.) EXT }
    dlpb:=kpb*20;
    dlext:=kext*20;
    sizect:=buf[9]*256+buf[10];      { ° §¬¥° ª®¤  }

    if dlpb<>0 then
      BLOCKREAD(rfile[i2],buf,dlpb);	    { ¯°®¯³±²¨²¼ PUBL }

    if dlext<>0 then
      BLOCKREAD(rfile[i2],buf,dlext);
    BLOCKREAD(rfile[i2],tabt,sizect);  { ¯°®·¨² «¨ ª®¤ }

    sizev:=sizect;
    if flv then
      sizev:=((sizect+$ff) div $100)* $100; { ¢»°®¢­¥­»© ª®¤ }
      if sizev<>sizect then
	for it:=sizect+1 to sizev do
	  tabt[it]:=0;			  { ¤®¯®«­¨²¼ ª®¤ ­³«¿¬¨ }

(*
       »¢®¤ ­  ¯¥· ²¼ ¨¬¥­¨ ¬®¤³«¿ ¨ ¥£® ¡ §»
*)
    WRITELN(fprin,'   ',tmod[i1].namem);
    par:='            ';
    SHEST(tvmod[i].bas,1);
    ir:=tvmod[i].bas+sizect-1;
    SHEST(ir,7);
    WRITELN(fprin,'          ',par);

(*
     ¨ª« ¯® ²®·ª ¬ REL ± ¨±¯° ¢«¥­¨¥¬ ª®¤ 
*)
    BLOCKREAD(rfile[i2],mnm,2); 	{ ·²¥­¨¥ ª®«¨·¥±²¢  ²®·¥ª }
    ktrel:=mnm[1]*256+mnm[2];

    if ktrel<>0 then
      for ir:=1 to ktrel do
       begin
	fltp:=true;			  { ´« £ ²¨¯  (.) - REL }
	BLOCKREAD(rfile[i2],mnm,5);	  { ½«¥¬¥­² REL }
	znt:=mnm[2]*256+mnm[3]; 	  { §­ ·¥­¨¥ }

	if mnm[1] < $80 then		  { ¯°®±² ¿ ²®·ª  }
	  znt:=znt+tvmod[i1].bas	  { ¡ §¨°®¢ ­¨¥ ²®·ª¨ }

	 else				  { ¢­¥¸­¿¿ ²®·ª  }
	  begin
	   znt:=znt*20; 	      { ±¬¥¹¥­¨¥ ¡ ² ¡«¨¶¥ EXT ± ­³«¿ }
	   inex:=0;			  { ¨­¤¥ª± TEX }
(*
	 ¯®¨±ª ¢­¥¸­¥© ²®·ª¨ ¢ TEX
*)
	   repeat
	     inex:=inex+1;
	     it:=1;
	     repeat
	       flt := tex[inex].namext[it] = buf[znt+it]; { ¯°¨§­ ª ±° ¢­¥­¨¿ }
	       it:=it+1;
	     until (it > 16) or not flt;     { ¶¨ª« ¤® ª®­¶  ¨«¨ ­¥ ° ¢­® }
	   until (inex = kext) or flt;	{ ¶¨ª« ¤® ª®­¶  ¨«¨  ° ¢­® }

	   if not flt then		   { ²®·ª  ­¥ ­ ©¤¥­  }
	     begin
	      fltp:=false;		    { ²¨¯ CONST }
	      znt:=0;			    { §­ ·¥­¨¥ ­¥®¯°¥¤¥«¥­® }
	     end
	    else			    { ²®·ª   ­ ©¤¥­  }
	     begin
	      fltp:=tex[inex].tip=0;
	      znt:=tex[inex].adr;
	     end;
	  end;	    {IF}

(*
	 ±¯° ¢«¥­¨¥ ª®¤ 
*)
	  it:=mnm[4]*256+mnm[5]+1;	    { ±¬¥¹¥­¨¥ ¢ ª®¤¥ ¤«¿ ¨±¯° ¢«¥­¨¿ }
	  fls:=mnm[1] and 2 = 2;		   { ´« £ ±² °¸¥£® ¡ ©²  }
	  if ODD(mnm[1]) then		     { ´« £ ¬« ¤¸¥£® ¡ ©²  ·¥²­®±²¼ }
	    tabt[it+1]:=LO(znt);	{ ¨±¯° ¢¨²¼ ¬« ¤¸¨© ¡ ©² }
	  if fls then
	   begin
	    tabt[it]:=HI(znt);	{ ¨±¯° ¢¨²¼ ±² °¸¨© ¡ ©² }

	    if fltp then		    { ²®·ª  REL }
	     begin
	      it:=it+tvmod[i].bas-1;	    { ±¬¥¹¥­¨¥ ¢ § £°³§®·­®¬ ¬®¤³«¥ }
	      mnm[1]:=HI(it);
	      mnm[2]:=LO(it);
	      klrel:=klrel+1;
	      BLOCKWRITE(wfile,mnm,2);	   { ¢»¢¥±²¨ ®·¥°¥¤­³¾ ²®·ª³ }
	     end;
	   end;
       end;	 {FOR ¯® ²®·ª ¬ REL }

    BLOCKWRITE(pfile,tabt,sizev);	    { ¢»¢¥±²¨ ¨±¯° ¢«¥­­»© ª®¤ }
   end;       {FOR ¯® ¬®¤³«¿¬ }

(*
      ¥°¥¯¨± ²¼ ª®¤ ¨§ ¯°®¬¥¦³²®·­®£® ´ ©«  ¢ °¥§³«¼²¨°³¾¹¨©
*)
  pozf:=0;
  SEEK(pfile,pozf);			    { ³±² ­®¢¨²¼ ´ ©« ¢ ­ · «® }
  dlpb:=tbas;				    { ¤«¨­  ª®¤  }
  pozf:=FILEPOS(wfile); 		    { § ¯®¬­¨²¼ ¯®§¨¶¨¾ °¥§.´ ©«  }
  repeat
    if dlpb < maxd then it:=dlpb else it:=maxd;
    dlpb:=dlpb-it;
    BLOCKREAD(pfile,tabt,it);
    BLOCKWRITE(wfile,tabt,it);
  until dlpb = 0;
(*
	®°¬¨°®¢ ­¨¥ ¨ § ¯¨±¼ § £®«®¢ª 
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
  SEEK(wfile,pozf);			    { ³±² ­®¢¨²¼ ´ ©« ¢ ­ · «® }
  BLOCKWRITE(wfile,buf,10);
(*
        ª°»²¨¥ ¢±¥µ ´ ©«®¢ ¨ § ¢¥°¸¥­¨¥ ° ¡®²»
*)
  for i:=1 to kfm do
    CLOSE(rfile[i]);
  CLOSE(wfile);
  ERASE(pfile);
  CLOSE(pfile);
  CLOSE(fprin);
  WRITELN('   LINK  K®­¥¶ ° ¡®²» ');
  HALT(0);
 end.
