 (************************************************************)
(*							    *)
(*	      ��������� �������� � �������������	    *)
(*		  ���������� ��'������ �������              *)
(*			 Version 1.02			    *)
(*		  (c) 19.VII.1989 Leonid Curak		    *)
(*							    *)
(************************************************************)

 PROGRAM LIBR;
(*
	 �������� ����� � ����������
*)

 CONST MAXD=10000;	 (*  ���������� ��������� � ������� ������� *)

 TYPE	ARBF = array[1..MAXD] OF BYTE;
	ARB  = ARRAY[1..8] OF BYTE;
	tmod = record
	    kom      : byte;
	    nam_mod  : string[40];
	    name_mod : arb;
	  end;
	tmk  = array[1..32] of tmod;

 VAR IP,I,IC,KMOD,KMODN,DLM,DLS,IND	 :INTEGER;
     IT,IM,j,jj,kmm 			 :INTEGER;
     FLPR,FLIG,FS			 :BOOLEAN;
     CH 				 :CHAR;
     BUF				 :ARBF;
     LIB_NAM,LIB_NMP,NAM_PRN,PAR 	 :STRING[80];
     STRN				 :STRING[80];
     KD,koma 				 :BYTE;
     NAME_MODT				 :ARB;
     RFILE,MFILE,WFILE			 :FILE; 	(* FILES *)
     PFILE				 :TEXT;
     DLF				 :LONGINT;
     digits				 : array[0..15] of char;
     moda				 : tmk;

(*
		   ������������
*)
  FUNCTION PRHEX(I:  BYTE) : STRING;

  BEGIN
    PRHEX := DIGITS[I DIV 16] +  DIGITS[I MOD 16];
  END; { PRHEX }


(*
     ��������� ��������� ����� ������ �� ����� �����
*)
   procedure MODNAM(nam:string; var mnmd:arb);

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
	  mnmd[j]:=ORD(UPCASE(ch));  { ������������� � ������� ����� }
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
       ��������� ������ ������

  ����:    FRD	- ���� ������
	   FWR	- ���� ������
	   FZP	- ���� ������
	   FPR	- ���� ������
*)
 PROCEDURE ZMODA(VAR FRD,FWR:FILE;NAM_T: ARB; FZP,FPR:BOOLEAN);
  VAR  KPB,KEXT,DLPB,DLEXT,DL:INTEGER;
 begin

  STRN:=' ';
  FOR I:=1 TO 8 DO
    BEGIN
      CH:=CHR(NAM_T[I]);
      STRN:=STRN+CH;
    END;
  IF FPR THEN	       (* ������ ��������� ������ *)
(*
	      ���� ������ ����� ������
*)
     WRITELN(PFILE,'   ������',STRN);

  BLOCKREAD(FRD,BUF,32);	   (*  ������ ����� ������*)
  IF (BUF[1]<>$5A) OR (BUF[2]<>$A5) THEN
    WRITELN(' LIB  ������ ',strn,' �� ���������')
   ELSE
    BEGIN
     IF FZP THEN BLOCKWRITE(FWR,BUF,32);  (*  ������ ��������� ������ *)
     KPB:=BUF[5]*256+BUF[6];	    (*	���������� ����� PUBLIC *)
     KEXT:=BUF[7]*256+BUF[8];	    (*	���������� ����� EXT	*)
     DLPB:=KPB*20;		    (*	���������� ���� � PUBLIC*)
     DLEXT:=KEXT*20;		    (*	���������� ���� � EXT	*)
     BLOCKREAD(FRD,BUF,DLPB);		 (*  ������ ������� PUBLIC   *)
     IF DLPB<>0 THEN
      BEGIN
       IF FZP THEN BLOCKWRITE(FWR,BUF,DLPB); (*  ������ ������� PUBLIC	 *)
       IF FPR THEN	    (* ������ ������� ������� ����� *)
	BEGIN
	 WRITELN(PFILE,' ');
	 WRITELN(PFILE,'      ������� ������� ����� ');
	 WRITELN(PFILE,' ');
	 IND:=0;
	 FOR I:=1 TO KPB DO
	  BEGIN
	   STRN:=' ';
	   FOR IP:=1 TO 16 DO
	    BEGIN
	     STRN:=STRN+CHR(BUF[IND+IP]);
(*	       STRN:=CONCAT(STRN,CH);*)
	    END;
	   STRN:=STRN+'  ';
	   IF BUF[IND+19]=0 THEN CH:='R' ELSE CH:='C';
	   STRN:=STRN+CH+' ';
	   STRN:=STRN+PRHEX(BUF[IND+17]);
	   STRN:=STRN+PRHEX(BUF[IND+18]);
	   WRITELN(PFILE,STRN);
	   IND:=IND+20;
	  END;
	  WRITELN(PFILE);
	END
      END;
     IF DLEXT<>0 THEN
      BEGIN
       BLOCKREAD(FRD,BUF,DLEXT);	   (*  ������ ������� EXT   *)
       IF FZP THEN BLOCKWRITE(FWR,BUF,DLEXT); (*  ������ ������� EXT   *)
       IF FPR THEN	    (* ������ ������� ������� ����� *)
	BEGIN
	 WRITELN(PFILE);
	 WRITELN(PFILE,'      ������� ������� ����� ');
	 WRITELN(PFILE);
	 IND:=0;
	 FOR I:=1 TO KEXT DO
	  BEGIN
	   STRN:=' ';
	   FOR IP:=1 TO 16 DO
	    BEGIN
	     STRN:=STRN+CHR(BUF[IND+IP]);
{	      STRN:=CONCAT(STRN,CH);}
	    END;
	    WRITELN(PFILE,STRN);
	    IND:=IND+20;
	  END;
	END;
      END;
     DLF:=DLF-DLPB-DLEXT-32;	   (* ������� ����� � ������ *)
(*
	     ��������� ���� ������
*)
     REPEAT
       IF DLF<MAXD THEN        (*  ���������� ����� ���������� ������ *)
	 DL:=DLF
	ELSE
	 DL:=MAXD;
       DLF:=DLF-DL;
       BLOCKREAD(FRD,BUF,DL);
       IF FZP THEN BLOCKWRITE(FWR,BUF,DL);
     UNTIL DLF=0
    END
  END;	      (*  END  ZMODA *)

(*
      ��������� ������ ����� ������
*)
   PROCEDURE RDDL(VAR FRD:FILE);
    BEGIN
     DLF:=0;
     BLOCKREAD(FRD,BUF,4);
     FOR IT:=1 TO 4 DO
      BEGIN
       DLF:=DLF*256+BUF[IT];
      END;
    END;

(*
     ��������� ������ ��������� ����������
*)
  PROCEDURE PRZAG;
   BEGIN
    WRITELN(PFILE,'            ���������� ',LIB_NAM);
    WRITELN(PFILE);
    WRITELN(PFILE);
    WRITELN(PFILE,'   � ���������� ',KMODN,' �������');
   END;

(*
      ��������� �������������� �����
*)
   PROCEDURE DLINA(VAR FRD:FILE);
    VAR DLF1	     :LONGINT;
    BEGIN
     DLF:=FILESIZE(FRD);
     DLF1:=DLF;
     FOR IT:=1 TO 4 DO
      BEGIN
       BUF[5-IT]:=DLF1 MOD 256;
       DLF1:=DLF1 DIV 256;
      END;
     END;


 PROCEDURE ERRPAR;
 BEGIN
 WRITELN('ERROR in Parameters');
 writeln('usage: UniLIB LibName [command] [/ListFile]');
 writeln('  command: <symbol>ModuleName, where symbol is');
 writeln('             + add ModuleName to the library');
 writeln('             - remove ModuleName from the library');
 writeln('             * extract ModuleName without removing it');
 writeln('             -+ or +- replace ModuleName in library');
 writeln('             -* or *- extract ModuleName and remove it');
 HALT;
 END;

(*
     ���� ������� ����������
*)
 BEGIN
  writeln('UniLIB Version 1.00. (c) 1989 "������".');

  digits:= '0123456789ABCDEF';
  IP:=PARAMCOUNT;	     (*    ���������� ����������  *)
  IF IP<1 THEN ERRPAR;	      (*    ������ � ����������    *)
  LIB_NAM:=PARAMSTR(1);        (* ������ �������� (��� LIB) *)
  I:=POS('.',LIB_NAM);         (*   ����� ����� � ������    *)
  IF I=0 THEN BEGIN	       (*  ��� ��� ����������	    *)
    LIB_NAM:=LIB_NAM+'.LIB';   (* ������������ ����������*)
    I:=POS('.',LIB_NAM)         (*   ����� ����� � ������    *)
  END;
(*
     �������� ����� �������������� ����� � ����� ���� BAC
*)
  LIB_NMP:=COPY(LIB_NAM,1,I);
  LIB_NMP:=LIB_NMP+'$LB';       (* ������������� ���� *)
  FLPR:=FALSE;			  (* ���� ������ *)
  j:=0;
  kmm:=0;
  koma:= 0;
(*
      ������ ��������� ����������
*)
  FOR I:=2 TO IP DO BEGIN
    PAR:=PARAMSTR(I);		   (* ��������� �������� *)
    CH:=PAR[1]; 	     (* CH=COPY(PAR,1,1) - ������ ������ *)
(*
       �������� �� ������� � �������������: 1-*, 2-+,4--.
*)
    IC:=POS(CH,'*+ -/');
    IF IC=0 THEN ERRPAR;	 (* ������ � ���������� *)
    IF IC=5 THEN BEGIN		  (* ���.�������: /P - ������*)
      NAM_PRN:= PAR;
      DELETE(NAM_PRN,1,1);
      FLPR:=TRUE
      END
     ELSE BEGIN 		   (* ������� ������ � ������� *)
      j:=j+1;			   { ����� ��������� }
      moda[j].kom:=IC;			   (* ��� ������� *)
      IT:=1;			   (* ���������� �������� � ������� *)
      CH:=PAR[2];	       (* CH=COPY(PAR,2,1) - ������ ������ *)
      IC:=POS(CH,'*+ -');      (* �������� � ������������� ������� *)
      IF IC=3 THEN ERRPAR;
      IF IC<>0 THEN BEGIN	(* ����������� ������� *)
	IT:=2;
	moda[j].kom:=moda[j].kom+IC;		(* ��� ������� *)
	IF moda[j].KOM=3 THEN ERRPAR    (* +* - ������������ ������� *)
      END;
      IF moda[j].KOM=2 THEN 		 (* ������� ������� + *)
        kmm:=kmm+1		 (* HOBOE *)
       ELSE
        IF (moda[j].KOM=4) OR (moda[j].KOM=5) THEN	 (* ������� �������� *)
          kmm:=kmm-1;		 (* HOBOE *)
      koma:=koma or moda[j].kom;
      DELETE(par,1,IT); (* �������� ������ �� ������ *)
      IF POS('.',par) = 0 THEN
      	par:=par+'.OBJ';    (* ������������ ���������� *)
      moda[j].NAM_MOD:= PAR;
(*
	�������� ��� ������ � ������� ���� - NAME_MOD
*)
      FOR IP:=1 TO 8 DO
	moda[j].NAME_MOD[IP]:=$20;
      MODNAM(par,moda[j].NAME_MOD);
    END       (*  IF *)
  END;	      (* FOR *)
  FLIG:= (koma >= 2) and (j <>0);  (* ���� �������������� ����������*)
(*
	 ���� ��������� ��������� � �������� ������
*)
  IF NOT FLPR THEN NAM_PRN:='CON';
  FLPR:=TRUE;
  ASSIGN(PFILE,NAM_PRN);		(* OPEN FILE PRINT *)
  REWRITE(PFILE);
  IF IORESULT<>0 THEN BEGIN	(*  ������ *)
    WRITELN(' ERROR DISK ',NAM_PRN);
    WRITELN(' LIB  ��������� ����������');
    HALT(1)
   END;

  ASSIGN(RFILE,LIB_NAM);
  {$I-}
  RESET(RFILE,1);	  (* ������� ���� ���������� *)
  IF IORESULT<>0 THEN BEGIN	(* ��� ���������� ��� ������ *)
    IF koma <> 2  THEN errpar;
{      WRITELN(' ERROR DISK ',LIB_NAM);
      WRITELN(' LIB  ��������� ����������');
      HALT(1)
    END; }
    ASSIGN(WFILE,LIB_NAM);
    REWRITE(WFILE,1);
    IF IORESULT<>0 THEN BEGIN	  (*  ������ *)
      WRITELN(' ERROR DISK ',LIB_NAM);
      CLOSE(PFILE);
      WRITELN(' LIB  ��������� ����������');
      HALT(1)
    END;

(*
       �������� ����� ����������
*)
    KMODN:=kmm;
    PRZAG;
    BUF[1]:=$0B;		  (* �������� ����� ���������� *)
    BUF[2]:=$B0;
    FOR I:=3 TO 32 DO  BUF[I]:=0;
    BUF[6]:=kmm;			 (* ���������� ������� *)
    BLOCKWRITE(WFILE,BUF,32);	      (* ������ ��������� ���������� *)

    for jj:=1 to j do
      begin

       ASSIGN(MFILE,moda[jj].NAM_MOD);
       RESET(MFILE,1);		  (* ������� ���� ������ *)
       IF IORESULT<>0 THEN BEGIN	  (*  ������ *)
         WRITELN(' ERROR DISK ',moda[jj].NAM_MOD);
         WRITELN(' LIB  ��������� ����������');
         CLOSE(WFILE);
         ERASE(WFILE);
         CLOSE(PFILE);
         HALT(1);
       END;
  {$I+}
       BLOCKWRITE(WFILE,moda[jj].NAME_MOD,8);      (* ��������� ������ - ��� ������ *)
(*
	�������� ����� ����� MFILE � �������� � BUF[1..4]
*)
       DLINA(MFILE);
       BLOCKWRITE(WFILE,BUF,4);	     (* ��������� ������ - ����� *)
       ZMODA(MFILE,WFILE,moda[jj].NAME_MOD,TRUE,FLPR); (* ���������� ������ *)
       CLOSE(MFILE);
      end;
    CLOSE(WFILE);
    CLOSE(PFILE);
    WRITELN(' LIB  ����� ������');
    HALT(0)		  (* HOPMA *)
  END;
(*
       ������ � �����������
*)

  BLOCKREAD(RFILE,BUF,32);		  (* ��������� ��������� ���������� *)
  IF (BUF[1]<>$0B) OR (BUF[2]<>$B0) THEN BEGIN
    WRITELN('���� - ',LIB_NAM,' �� ����������');
    CLOSE (RFILE);
    CLOSE (PFILE);
    WRITELN(' LIB  ��������� ����������');
    HALT(2)
  END;
  if flig then
   begin
    ASSIGN(WFILE,LIB_NMP);
    REWRITE(WFILE,1);
   end;
  KMOD:=BUF[5]*256+BUF[6];	 (* ���������� ������� � ���������� *)
  kmodn:=kmod+kmm;
  PRZAG;
  BUF[5]:=KMODN DIV 256;
  BUF[6]:=KMODN MOD 256;
  IF FLIG THEN BLOCKWRITE(WFILE,BUF,32);	 (* ������ ��������� ���������� *)
(*
	���� �� ������� ���������� (����� ��������� �����)
*)
  FOR IM:=1 TO KMOD DO
  BEGIN
    BLOCKREAD (RFILE,NAME_MODT,8);	(* ��� ���������� ������ *)
    if j=0 then fs:=false
     else
      begin
       jj:=0;
       repeat
	 jj:=jj+1;

	 i:=1;
	 repeat 	  (* ���� ��������� *)
	   fs:= moda[jj].NAME_MOD[I]=NAME_MODT[I];
	   i:=i+1;
	 until (i>8) or not fs;

       until (jj=j) or fs;
      end;
    IF FS THEN BEGIN		  (* ����� �������� ������ *)
      CASE moda[jj].KOM OF
       1:			 (* ������� ������ '*'   *)
	BEGIN
	 ASSIGN(MFILE,moda[jj].NAM_MOD);
	 REWRITE(MFILE,1);  (* ������� ���� ������ *)
	 IF IORESULT<>0 THEN BEGIN     (*  ������ *)
	   CLOSE (RFILE);
	   CLOSE (PFILE);
	   WRITELN(' ERROR DISK ',moda[jj].NAM_MOD);
	   WRITELN(' LIB  ��������� ����������');
	   HALT(1)
	 END;
	 RDDL(RFILE);	     (* ��������� � ������������� ����� ������ *)
	 ZMODA(RFILE,MFILE,NAME_MODT,TRUE,FLPR); (* ������ ������ *)
	 CLOSE(MFILE);
	END;
       2:			  (* ������� ������� '+'  *)
	BEGIN
	 WRITELN(' ������ ',moda[jj].nam_mod,' � ���������� ���� ');
{	  ERASE(WFILE);
	 CLOSE(WFILE);		  (* ���������� ������������� ���� *)
	 FLIG:=FALSE   }
	END;
       4:			   (* ������� �������� - *)
	BEGIN
	 RDDL(RFILE);
	 ZMODA(RFILE,WFILE,NAME_MODT,FALSE,FALSE); (* ������� ������ *)
	END;
       5:			   (* ������� �������� � ������ *-  *)
	BEGIN
	 ASSIGN(MFILE,moda[jj].NAM_MOD);
	 REWRITE(MFILE,1);	 (* ������� ���� ������ *)
	 IF IORESULT<>0 THEN BEGIN     (*  ������ *)
	   WRITELN(' ERROR DISK ',moda[jj].NAM_MOD);
	   CLOSE (PFILE);
	   CLOSE (WFILE);
	   ERASE (WFILE);
	   CLOSE (RFILE);
	   WRITELN(' LIB  ��������� ����������');
	   HALT(1)
	 END;
(*   ������ � ���������� *)
	 RDDL(RFILE);	     (* ��������� � ������������� ����� ������ *)
	 ZMODA(RFILE,MFILE,NAME_MODT,TRUE,FALSE);
	 CLOSE(MFILE)
	END;
       6:			    (* ������� ������ *)
	BEGIN
	 ASSIGN(MFILE,moda[jj].NAM_MOD);
	 RESET(MFILE,1);	       (* ������� ���� ������ *)
	 IF IORESULT<>0 THEN BEGIN     (*  ������ *)
	   WRITELN(' ERROR DISK ',moda[jj].NAM_MOD);
	   CLOSE (PFILE);
	   CLOSE (WFILE);
	   ERASE (WFILE);
	   CLOSE (RFILE);
	   WRITELN(' LIB  ��������� ����������');
	   HALT(1)
	 END;
(*	 �������� ������ �����	*)
	 DLINA(MFILE);	(*DLF:=FILESIZE(MFILE);*)
	 BLOCKWRITE(WFILE,NAME_MODT,8);     (* ������ ����� ������ *)
	 BLOCKWRITE(WFILE,BUF,4);	    (* ������ ����� ������ *)
	 ZMODA(MFILE,WFILE,NAME_MODT,TRUE,FLPR); (* ������ ������ *)
	 CLOSE(MFILE);
(*
    ���������� ������ �� ���������� � ����
*)
	 RDDL(RFILE);	(* ��������� � ������������� ����� ������ *)
	 ZMODA(RFILE,MFILE,NAME_MODT,FALSE,FALSE); (* ������� ������ *)
	END
       END   (* CASE *)
      END
(*
	    �� ��������� ����� �������
*)
     ELSE  BEGIN
      RDDL(RFILE);		(*  ������ ����� *)
      IF FLIG THEN BEGIN	   (* ������ �������? *)
	BLOCKWRITE(WFILE,NAME_MODT,8);	   (* ������ ����� ������ *)
	BLOCKWRITE(WFILE,BUF,4) 	  (* ������ ����� ������ *)
      END;
      ZMODA(RFILE,WFILE,NAME_MODT,FLIG,FLPR)  (* ������ ������ *)
    END     (* IF *)
  END;	    (* FOR ��� ������ ����������� *)
  if j<>0 then
    for jj:=1 to j do
     begin

      IF moda[jj].KOM=2 THEN BEGIN		 (*  ������� ������� *)
	ASSIGN(MFILE,moda[jj].NAM_MOD);
	RESET(MFILE,1);       (* ������� ���� ������ *)
	IF IORESULT<>0 THEN BEGIN     (*  ������ *)
	  WRITELN(' ERROR DISK ',moda[jj].NAM_MOD);
	  CLOSE (PFILE);
	  CLOSE (WFILE);
	  ERASE (WFILE);
	  CLOSE (RFILE);
	  WRITELN(' LIB  ��������� ����������');
	  HALT(1)
	END;
(*	 �������� ������ �����	*)
	DLINA(MFILE);
	BLOCKWRITE(WFILE,moda[jj].NAME_MOD,8);	     (* ������ ����� ������ *)
	BLOCKWRITE(WFILE,BUF,4);	   (* ������ ����� ������ *)
	ZMODA(MFILE,WFILE,moda[jj].NAME_MOD,TRUE,FLPR); (* ������ ������ *)
	CLOSE(MFILE)
      end;
     END;
  IF FLIG THEN BEGIN
(*    ������������� ���� RFILE B .BLI  *)
    CLOSE(RFILE);
    ERASE(RFILE);
    CLOSE(WFILE);
    RENAME(WFILE, LIB_NAM);

(*    ������������� ���� WFILE B .LIB  *)
    END
   ELSE
    CLOSE(RFILE);
    CLOSE(PFILE);
(*
     ����� ������
*)
  WRITELN (' LIB  ����� ������ ');
 END.
