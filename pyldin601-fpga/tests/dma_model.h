// Independent synchronous DMA oracle for native BIOS tests.
static unsigned char params[19];static unsigned param_index,dma_jobs,dma_failed,dma_present=1;
static uint64_t dma_until;
static uint32_t p24(unsigned p){return params[p]|params[p+1]<<8|params[p+2]<<16;}
static unsigned char physical_read(uint32_t a){return a<65536?MC6800GetCpuRam()[a]:physical[a];}
static void physical_write(uint32_t a,unsigned char b){if(a<65536)MC6800GetCpuRam()[a]=b;else physical[a]=b;}
static int dma_read(uint16_t a,unsigned char*out){
 if(a<0xe6e0||a>0xe6e3)return 0;
 if(!dma_present){*out=255;return 1;}
 switch(a&3){case 0:*out=1|(virtual_cycles<dma_until?128:0)|(dma_failed?16:0);break;
 case 1:*out='D';break;case 2:*out=param_index;break;case 3:*out=param_index<19?params[param_index]:255;break;}
 return 1;
}
static int dma_write(uint16_t a,unsigned char b){
 if(a<0xe6e0||a>0xe6e3)return 0;
 if(a==0xe6e2)param_index=b&31;
 else if(virtual_cycles>=dma_until){
  if(a==0xe6e3){if(param_index<19)params[param_index]=b;param_index=param_index==18?0:(param_index+1)&31;}
  else if(a==0xe6e1){
   unsigned src=p24(0),dst=p24(3),len=p24(6),height=params[9]+256*params[10],mode=params[17];
   require((b==1||b==2)&&height==1&&!p24(11)&&!p24(14)&&mode<=2,"INT E8 emits complete linear DMA descriptor");
   require(src<0x200000&&dst<0x200000&&len<=8192,"native DMA physical range");
   if(mode&1)require(src==0xe65e,"native palette source endpoint");
   if(mode&2)require(dst==0xe65e,"native palette destination endpoint");
   unsigned char *snapshot=malloc(len?len:1);require(snapshot!=NULL,"DMA oracle allocation");
   for(unsigned i=0;i<len;i++)snapshot[i]=b==1?params[18]:mode&1?pal[(paladdr+i)&8191]:physical_read(src+i);
   for(unsigned i=0;i<len;i++){if(mode&2)pal[(paladdr+i)&8191]=snapshot[i]&63;else physical_write(dst+i,snapshot[i]);}
   if(mode)paladdr=(paladdr+len)&8191;
   free(snapshot);dma_until=virtual_cycles+len/8+20;dma_failed=0;dma_jobs++;
  }
 }
 return 1;
}
