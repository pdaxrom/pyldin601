#define GAMEBIOS_MAIN unused_gamebios_main
#include "test_gamebios.c"
int main(int argc,char**argv){
 if(argc!=3)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=1;
 MC6800SetMachine(PYLDIN_MACHINE_HD6303);size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);image=load(argv[1],&image_size);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();char path[128];
 snprintf(path,sizeof path,"build/gamebios/RAM-%s.bin",argv[2]);FILE*f=fopen(path,"wb");require(f&&fwrite(MC6800GetCpuRam(),1,65536,f)==65536&&!fclose(f),"write native RAM snapshot");return 0;
}
