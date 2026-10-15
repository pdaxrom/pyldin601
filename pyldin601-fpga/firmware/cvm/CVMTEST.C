/* Small-C/16 regression shared by host and both ROM VMs. */
int calls;
char data[16], buf[16], pos[4];
check(ok)
int ok;
{
 if (ok == 0) {
  puts("CVM TEST FAIL"); putchar('0'+calls/10);
  putchar('0'+calls%10); putchar(10); exit(1);
 }
 calls=calls+1;
}
rec(n)
int n;
{
 if (n == 0) return 1;
 return n*rec(n-1);
}
main(argc, argv)
int argc;
char *argv[];
{
 int a,b,n,h,k;
 a=-32768; b=32767;
 check(a<b); check(b>a); check(a<=b); check(b>=a);
 check((a==b)==0); check(a!=b);
 check(a/-1 == -32768);
 a=-7; b=3;
 check(a/b == -2); check(a%b == -1);
 check(7/-3 == -2); check(7%-3 == 1);
 check(-7/-3 == 2); check(-7%-3 == -1);
 check((-32768>>1)==-16384); check((-3>>1)==-2);
 check((-1>>16)==-1); check((1>>16)==0);
 check((1<<16)==0); check((1<<32)==1);
 check((32767+1)==-32768); check((-32768-1)==32767);
 check((300*300)==24464); check(((-123)*7)==-861);
 check((0x1234^0xffff)==0xedcb);
 check((0x1234|0x0080)==0x12b4); check((0x1234&255)==0x34);
 check(rec(6)==720);
 n=0; k=0;
 while (n<30) { k=k+n; n++; }
 check(k==435);
 data[0]=-1; check(data[0]==-1);
 strcpy(data,"abcdef"); strcat(data,"gh");
 check(strlen(data)==8); check(strcmp(data,"abcdefgh")==0);
 strclr(data,0); check(data[0]=='a');
 check(isalpha('_'));
 check(isalpha('Z'));
 check(isdigit('7'));
 check(toupper('q')=='Q');
 check(tolower('X')=='x'); check(isspace(10));
 h=fopen("CVMIO.DAT","w+"); check(h!=0);
 check(fwrite(data,3,2,h)==2); check(fflush(h)==0);
 strclr(pos,4); check(fseek(h,pos,0)==0);
 k=fread(buf,3,2,h);
 check(k==2); buf[6]=0;
 check(strcmp(buf,"abcdef")==0); check(fclose(h)==0);
 check(unlink("CVMIO.DAT")==0);
 h=fopen("CVMIO.DAT","w"); check(h!=0);
 strcpy(data,"one"); data[3]=10; strcpy(data+4,"two");
 check(fputs(data,h)>=0); check(fclose(h)==0);
 h=fopen("CVMIO.DAT","r"); check(h!=0);
 check(fgets(buf,4,h)==buf); check(strcmp(buf,"one")==0);
 check(fgets(buf,4,h)==buf); check((buf[0]==10)&(buf[1]==0));
 check(fgets(buf,4,h)==buf); check(strcmp(buf,"two")==0);
 check(fgets(buf,4,h)==0); check(fclose(h)==0);
 check(unlink("CVMIO.DAT")==0);
 puts("CVM TEST PASS");
}
