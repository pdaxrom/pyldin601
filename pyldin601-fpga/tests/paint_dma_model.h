// Full flat DMA oracle: snapshots each row before writing, including port
// auto-increment. RTL arbitration/timing has separate HDL coverage.
static unsigned char paint_parameters[19];
static unsigned paint_index,paint_jobs,paint_error;
static uint64_t paint_until;
static unsigned paint_u24(unsigned n){return paint_parameters[n]|paint_parameters[n+1]<<8|paint_parameters[n+2]<<16;}
static unsigned char paint_get(unsigned a){require(a<0x200000,"Paint DMA source range");return a<65536?MC6800GetCpuRam()[a]:physical[a];}
static void paint_put(unsigned a,unsigned char v){require(a<0x200000,"Paint DMA destination range");if(a<65536)MC6800GetCpuRam()[a]=v;else physical[a]=v;}
static int paint_dma_read(uint16_t a,unsigned char*out){
 if(a<0xe6e0||a>0xe6e3)return 0;
 *out=(a&3)==0?1|(paint_error?16:0)|(virtual_cycles<paint_until?128:0):(a&3)==1?'D':(a&3)==2?paint_index:paint_parameters[paint_index%19];return 1;
}
static int paint_dma_write(uint16_t a,unsigned char v){
 if(a<0xe6e0||a>0xe6e3)return 0;
 if(a==0xe6e2){paint_index=v&31;return 1;}
 require(virtual_cycles>=paint_until,"Paint programs DMA only while idle");
 if(a==0xe6e3){if(paint_index<19)paint_parameters[paint_index]=v;paint_index=(paint_index+1)%19;return 1;}
 if(a!=0xe6e1)return 1;
 unsigned source=paint_u24(0),dest=paint_u24(3),width=paint_u24(6),height=paint_parameters[9]|paint_parameters[10]<<8,mode=paint_parameters[17];
 unsigned ss=paint_u24(11),ds=paint_u24(14);
 require((v==1||v==2)&&width&&height&&width<=192000&&height<=640,"bounded Paint COPY/FILL");
 require(mode<=2,"Paint RAM or auto-increment palette endpoints");
 if(mode&1)require(source==0xe65e,"Paint palette source port");if(mode&2)require(dest==0xe65e,"Paint palette destination port");
 unsigned char*row=malloc(width);require(row!=NULL,"Paint DMA oracle row");
 for(unsigned y=0;y<height;y++){
  for(unsigned x=0;x<width;x++)row[x]=v==1?paint_parameters[18]:mode&1?pal[(paladdr+x)&8191]:paint_get(source+x);
  for(unsigned x=0;x<width;x++){if(mode&2)pal[(paladdr+x)&8191]=row[x]&63;else paint_put(dest+x,row[x]);}
  if(mode)paladdr=(paladdr+width)&8191;
  source+=ss?ss:width;dest+=ds?ds:width;
 }
 free(row);paint_jobs++;paint_error=0;paint_until=virtual_cycles+(uint64_t)width*height/8+20;return 1;
}
