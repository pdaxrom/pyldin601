// Independent byte-level mouse fixture for application hit/focus tests.
// Electrical/software-command timing is tested separately on the actual HDL CPU.
static unsigned mouse_ui_enabled,mouse_ui_head,mouse_ui_count,mouse_ui_overflow;
static unsigned mouse_ui_lines,mouse_ui_index,mouse_ui_timer;
static uint64_t mouse_ui_deadline;
static unsigned char mouse_ui_registers[128],mouse_ui_bytes[16];
static int mouse_ui_read_byte(unsigned short a,unsigned char*out){
 if(a<0xe6b8||a>0xe6bf)return 0;
 *out=255;
 switch(a&7){
 case 0:*out=mouse_ui_enabled?'M':0;break;
 case 1:*out=(mouse_ui_count!=0)|(mouse_ui_overflow<<7)|((mouse_ui_lines&4)!=0?4:0);break;
 case 2:if(mouse_ui_count){*out=mouse_ui_bytes[mouse_ui_head++&15];mouse_ui_count--;}break;
 case 3:*out=mouse_ui_count;break;
 case 4:*out=((mouse_ui_lines&1)?0:1)|((mouse_ui_lines&2)?0:2)|(mouse_ui_lines&4)|((mouse_ui_timer&&virtual_cycles>=mouse_ui_deadline)?128:0);break;
 case 5:*out=virtual_cycles&255;break;
 case 6:*out=mouse_ui_index;break;
 case 7:*out=mouse_ui_registers[mouse_ui_index&127];break;
 }
 return 1;
}
static int mouse_ui_write_byte(unsigned short a,unsigned char d){
 if(a<0xe6b8||a>0xe6bf)return 0;
 switch(a&7){
 case 3:if(d&1)mouse_ui_head=mouse_ui_count=0;if(d&2)mouse_ui_overflow=0;break;
 case 4:mouse_ui_lines=d&7;break;
 case 5:mouse_ui_timer=d;mouse_ui_deadline=virtual_cycles+d*256;break;
 case 6:mouse_ui_index=d;break;
 case 7:mouse_ui_registers[mouse_ui_index&127]=d;mouse_ui_index=(mouse_ui_index&128)|((mouse_ui_index+1)&127);break;
 }
 return 1;
}
static void mouse_ui_push(unsigned b){
 if(mouse_ui_count<16)mouse_ui_bytes[(mouse_ui_head+mouse_ui_count++)&15]=b;else mouse_ui_overflow=1;
}
static void mouse_ui_place(unsigned base,unsigned present,unsigned x_label,unsigned y_label,unsigned col,unsigned row,unsigned cols,unsigned buttons){
 unsigned char*r=MC6800GetCpuRam();unsigned x=col*(cols==80?8:16)+3,y=row*8+3;
 require(x<640&&y<232,"mouse application target is on screen");
 mouse_ui_enabled=1;r[base+present]=1;
 // Real signed-packet arithmetic is covered by the HDL test. Give this UI
 // event a one-count move so hover/focus handling is exercised as well.
 word_at(base+x_label,x-1);word_at(base+y_label,y);
 mouse_ui_push(8|buttons);mouse_ui_push(1);mouse_ui_push(0);
}
