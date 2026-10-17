// Independent flat-memory oracle for NC's screen-row cache. HDL separately
// checks the DMA bus, arbitration, clocks and CPU/video contention.
static unsigned char row_dma_parameters[19];
static unsigned row_dma_index,row_dma_jobs,row_dma_error;
static unsigned row_dma_fault,row_dma_fault_seen;
static uint64_t row_dma_until;
static unsigned row_dma_u24(unsigned n){
 return row_dma_parameters[n]|row_dma_parameters[n+1]<<8|row_dma_parameters[n+2]<<16;
}
static int row_dma_read(unsigned short a,unsigned char*out){
 if(a<0xe6e0||a>0xe6e3)return 0;
 *out=(a&3)==0?1|(virtual_cycles<row_dma_until?128:0)|(row_dma_error?16:0):
      (a&3)==1?'D':(a&3)==2?row_dma_index:row_dma_parameters[row_dma_index%19];
 return 1;
}
static int row_dma_write(unsigned short a,unsigned char v){
 if(a<0xe6e0||a>0xe6e3)return 0;
 if(a==0xe6e2){row_dma_index=v&31;return 1;}
 require(virtual_cycles>=row_dma_until,"NC waits for DMA before configuring its next job");
 if(a==0xe6e3){
  if(row_dma_index<19)row_dma_parameters[row_dma_index]=v;
  row_dma_index=(row_dma_index+1)%19;return 1;
 }
 if(a!=0xe6e1)return 1;
 unsigned source=row_dma_u24(0),dest=row_dma_u24(3),width=row_dma_u24(6);
 if(v!=2||(width!=40&&width!=80)||row_dma_parameters[9]!=1||row_dma_parameters[10]||row_dma_u24(11)||row_dma_u24(14)||row_dma_parameters[17]||row_dma_parameters[18])
  fprintf(stderr,"NC DMA command=%u src=%06x dst=%06x width=%u height=%u mode=%u value=%u PC=%04x columns=%u\n",v,source,dest,width,row_dma_parameters[9]|row_dma_parameters[10]<<8,row_dma_parameters[17],row_dma_parameters[18],PC,MC6800GetCpuRam()[editor_base+NCEDIT_COLUMNS]);
 require(v==2&&(width==40||width==80)&&row_dma_parameters[9]==1&&!row_dma_parameters[10]&&
         !row_dma_u24(11)&&!row_dma_u24(14)&&!row_dma_parameters[17]&&!row_dma_parameters[18],
         "NC emits a complete bounded screen-row COPY descriptor");
 unsigned gpu=source>=65536?source:dest,ram=source>=65536?dest:source;
 require(gpu>=0x1fe000&&gpu<0x1ff800&&!(gpu&255)&&ram==loader_base+512,
         "screen cache DMA stays in its private GPU rows and dead-prefix row buffer");
 if(row_dma_fault){row_dma_fault=0;row_dma_fault_seen++;row_dma_error=1;row_dma_until=virtual_cycles+20;return 1;}
 for(unsigned k=0;k<width;k++){
  unsigned char b=source>=65536?physical[source+k]:MC6800GetCpuRam()[source+k];
  if(dest>=65536)physical[dest+k]=b;else MC6800GetCpuRam()[dest+k]=b;
 }
 row_dma_error=0;row_dma_jobs++;row_dma_until=virtual_cycles+width/8+20;
 return 1;
}
