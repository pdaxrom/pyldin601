// Native UniDOS integration: real PGM + YPLAY, independent graphics/HAM oracle.
#include <stdint.h>
static int gfxmusic_gfx_read(uint16_t a,unsigned char*out);
static int gfxmusic_gfx_write(uint16_t a,unsigned char d);
static void gfxmusic_reset(void),gfxmusic_observe(void),gfxmusic_finish_check(const char *cmd);
static unsigned gfxmusic_frames(void);
#define GFXMUSIC_FIXTURE 1
#include "test_audio_app.c"

static unsigned char gfx[16],palette[8192],old_palette[8192];
static unsigned palette_address,palette_readback,animation_frames,blit_jobs,edge_mask,outside,overlaps;
static unsigned opaque,keyed,valid[2],old_visible[2];
static int balls[3][4]={{-16,-16,4,1},{304,184,-4,-2},{140,85,-4,3}};
static uint64_t gfx_ready;
static unsigned snapshot_checked;
static unsigned gfx_version=5,gfx_initial;
static unsigned gfxmusic_frames(void){return animation_frames;}
static unsigned char background(unsigned x,unsigned y){
 unsigned col=x/4,row=y/4,r=col<64?col:127-col,g=row+14,b=(col+2*row)&63;
 unsigned q[3]={(r+10)/21,(g+10)/21,(b+10)/21};
 switch(x&3){case 0:return(q[0]<<4)|(q[1]<<2)|q[2];case 1:return 64|b;case 2:return 128|r;default:return 192|g;}
}
static unsigned char sprite(unsigned x,unsigned y,unsigned ball){
 unsigned inset=y<2||y>=30?12:y<4||y>=28?8:y<8||y>=24?4:0;
 if(x<inset||x>=32-inset)return 0;
 return x>=8&&x<12&&y>=8&&y<12?63:(unsigned[]){48,12,3}[ball];
}
static void ham_step(unsigned code,unsigned rgb[3]){
 if(code<64){rgb[0]=(code>>4)*21;rgb[1]=((code>>2)&3)*21;rgb[2]=(code&3)*21;}
 else rgb[(unsigned[]){0,2,0,1}[code>>6]]=code&63;
}
static void check_frame(unsigned page){
 require(app_base,"music IRQ installed before graphics starts");
 require(gfx[0]==7,"HAM8 stays enabled");
 unsigned visible=0;
 for(unsigned n=0;n<3;n++){
  int x=balls[n][0],y=balls[n][1];
  if(x<320&&x+32>0&&y<200&&y+32>0){visible++;if(x<0)edge_mask|=1;if(x>288)edge_mask|=2;if(y<0)edge_mask|=4;if(y>168)edge_mask|=8;}else outside++;
 }
 require(opaque==(valid[page]?old_visible[page]:0)&&keyed==visible,"dirty rectangles restore before transparent draws");
 unsigned char*buf=physical+0x100000+page*65536;
 for(unsigned y=0;y<200;y++){
  unsigned bg_rgb[3]={0},actual_rgb[3]={0};
  for(unsigned x=0;x<320;x++){
   unsigned expected=background(x,y),cover=0;
   ham_step(expected,bg_rgb);
   for(unsigned n=0;n<3;n++){
    int sx=x-balls[n][0],sy=y-balls[n][1];
    if(sx>=0&&sx<32&&sy>=0&&sy<32){unsigned c=sprite(sx,sy,n);if(c){expected=c;cover++;}}
   }
   if(cover>1)overlaps++;
   if(buf[y*320+x]!=expected){fprintf(stderr,"GFXMUSIC frame %u page %u x%u y%u got %02x expected %02x\n",animation_frames,page,x,y,buf[y*320+x],expected);require(0,"full frame matches independent overlay");}
   ham_step(buf[y*320+x],actual_rgb);
   if(!cover)require(!memcmp(bg_rgb,actual_rgb,sizeof bg_rgb),"HAM hold does not leak past a sprite or transparent gap");
   require(physical[0x130000+y*320+x]==background(x,y),"static HAM background unchanged");
  }
 }
 for(unsigned n=0;n<3;n++)for(unsigned y=0;y<32;y++)for(unsigned x=0;x<32;x++)
  require(physical[0x120000+y*320+n*32+x]==sprite(x,y,n),"sprite atlas unchanged");
 valid[page]=1;old_visible[page]=visible;opaque=keyed=0;animation_frames++;
 for(unsigned n=0;n<3;n++)for(unsigned axis=0;axis<2;axis++){
  int p=balls[n][axis]+balls[n][axis+2],max=axis?200:320;
  if(p< -32){p=-32;balls[n][axis+2]=-balls[n][axis+2];}
  if(p>max){p=max;balls[n][axis+2]=-balls[n][axis+2];}
  balls[n][axis]=p;
 }
}
static int gfxmusic_gfx_read(uint16_t a,unsigned char*out){
 if(a<0xe650||a>0xe65f)return 0;
 unsigned p=a&15;
 *out=p==14?(palette_readback?palette[palette_address]:getenv("GFX_FAULT")&&!strcmp(getenv("GFX_FAULT"),"missing")?'?':'G'):p==15?gfx_version:p==0?gfx[0]|(virtual_cycles<gfx_ready?128:0):gfx[p];return 1;
}
static int gfxmusic_gfx_write(uint16_t a,unsigned char d){
 if(a<0xe650||a>0xe65f)return 0;unsigned p=a&15;
 if(p==0){gfx[0]=d&7;return 1;}
 if(p==2){palette_address=(palette_address&0x1f00)|d;return 1;}
 if(p==13){palette_address=((d&31)<<8)|(palette_address&255);return 1;}
 if(p==14){palette[palette_address]=d&63;palette_address=(palette_address+1)&8191;return 1;}
 if(p==15){palette_readback=d&1;if(d&2)palette_address=(palette_address+1)&8191;return 1;}
 require(virtual_cycles>=gfx_ready,"no graphics command/parameter write while busy");
 gfx[p]=d;if(p!=1)return 1;blit_jobs++;
 unsigned sp=gfx[4],dp=gfx[5],so=gfx[6]+256*gfx[7],dest=gfx[8]+256*gfx[9],w=gfx[10]+256*gfx[11],h=gfx[12];
 if(d==3){if(gfx[0])check_frame(dp);gfx[2]=dp;gfx_ready=(virtual_cycles/20000+1)*20000;return 1;}
 require(w&&w<=320&&h&&h<=200&&sp<16&&dp<16&&dest+320*(h-1)+w<=64000,"valid blit range");
 unsigned char*dst=physical+0x100000+dp*65536;
 if(d==1){for(unsigned y=0;y<h;y++)memset(dst+dest+y*320,gfx[3],w);}
 else if(d==2||d==6){
  require(so+320*(h-1)+w<=64000,"valid source range");
  unsigned char*src=physical+0x100000+sp*65536;
  for(unsigned y=0;y<h;y++)for(unsigned x=0;x<w;x++)if(d==2||src[so+y*320+x]!=gfx[3])dst[dest+y*320+x]=src[so+y*320+x];
  if(gfx[0]){if(d==2)opaque++;else keyed++;require(dp!=gfx[2]&&w<=32&&h<=32,"animation touches only hidden dirty rectangles");}
 }else require(0,"known blitter command");
 gfx_ready=virtual_cycles+w*h/4+10;return 1;
}
static void gfxmusic_reset(void){
 for(unsigned n=0;n<8192;n++)old_palette[n]=palette[n]=(n*17+n/32+5)&63;
 const char *fault=getenv("GFX_FAULT");
 if(fault){if(!strcmp(fault,"version"))gfx_version=4;else if(!strcmp(fault,"busy"))gfx[0]=gfx_initial=1;else require(!strcmp(fault,"missing"),"known graphics fault");}
}
static void gfxmusic_observe(void){
 if(app_base&&!snapshot_checked){
  unsigned char*r=MC6800GetCpuRam();
  require(!memcmp(r+app_base+YP_LG_BACKUP,old_palette,8192),"full original PAL palette backed up");
  snapshot_checked=1;
  const char *path=getenv("GFXMUSIC_SNAPSHOT");
  if(path){
   memcpy(physical,r,0xf000);
   FILE *f=fopen(path,"wb");require(f!=NULL,"open GFXMUSIC SRAM snapshot");
   require(fwrite(physical,1,sizeof physical,f)==sizeof physical&&!fclose(f),"write full SRAM snapshot");
   char json[1024];snprintf(json,sizeof json,"%s.json",path);f=fopen(json,"w");require(f!=NULL,"open GFXMUSIC context");
   fprintf(f,"{\"model_a\":%u,\"pc\":%u,\"sp\":%u,\"a\":%u,\"b\":%u,\"x\":%u,\"cc\":%u,\"page\":%u,\"group\":%u,\"mode\":%u,\"app\":%u,\"original_irq\":%u,\"saved_page\":%u,\"saved_group\":%u,\"crtc\":[",model_a,PC,SP,A,B,X,0xc0|h*32|i*16|n*8|z*4|v*2|c,page,ram_group,r[0xe629],app_base,original_irq,saved_page,saved_group);
   for(unsigned k=0;k<16;k++)fprintf(f,"%s%u",k?",":"",crtc[k]);fprintf(f,"],\"period\":%u,\"divider\":%u,\"config\":[",music_period,chip_divider);
   for(unsigned k=0;k<96;k++)fprintf(f,"%s%u",k?",":"",config[k]);fprintf(f,"]}\n");fclose(f);
   puts("Prepared native GFXMUSIC context after loading, before music/graphics start");exit(0);
  }
 }
}
static void gfxmusic_finish_check(const char *cmd){
 require(gfx[0]==gfx_initial&&!palette_readback&&!memcmp(palette,old_palette,8192),"palette, graphics and console restored on exit");
 if(frames_played){require(animation_frames>=30&&valid[0]&&valid[1],"both frame histories and simultaneous music exercised");
  if(loop_mode)require(edge_mask==15&&outside&&overlaps,"all edges, fully outside, overlap and return exercised");}
 printf("PASS GFXMUSIC %s: %u animation frames / %u AY frames, %u jobs, HAM RGB without trails, clipping/overlap, palette/context cleanup\n",model_a?"601A":"601",animation_frames,frames_played,blit_jobs);
 if(frames_played){
  unsigned char *r=MC6800GetCpuRam();unsigned initial_sp=SP;
  // Run a second time in the same DOS session, with no emulator reset.
  app_base=restored=frames_played=envelope_writes=animation_frames=blit_jobs=opaque=keyed=snapshot_checked=0;
  memset(valid,0,sizeof valid);memset(old_visible,0,sizeof old_visible);
  const int initial[3][4]={{-16,-16,4,1},{304,184,-4,-2},{140,85,-4,3}};
  memcpy(balls,initial,sizeof balls);type_run(cmd);
  uint64_t deadline=virtual_cycles+1500000000ULL;
  while(frames_played<20&&virtual_cycles<deadline)until(virtual_cycles+1000);
  require(frames_played==20,"second invocation starts music and graphics");key(1);prompt_wait();
  require(restored==1&&SP==initial_sp&&!gfx[0]&&!palette_readback&&!memcmp(palette,old_palette,8192),"second exit preserves palette, stack and console");
  require((r[0xefc8]<<8|r[0xefc9])==original_irq&&!music_enabled&&!music_overrun&&!r[app_base+YP_UNDERRUNS],"second exit restores IRQ and timer without underruns");
  command("dir c:");
  printf("PASS GFXMUSIC %s: second invocation and DIR without reset\n",model_a?"601A":"601");
 }
}
