/* Produce RGB/progressive/grey/CMYK JPEGs using the installed codec, and an
 * independently decompressed RGB reference for the Exif rotation test. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <jpeglib.h>
int main(int argc,char **argv){
 if(argc!=4)return 2;
 int mode=atoi(argv[3]),channels=mode==2?1:mode==3?4:3;
 FILE *f=fopen(argv[1],"wb");if(!f)return 1;
 struct jpeg_compress_struct c;struct jpeg_error_mgr e;c.err=jpeg_std_error(&e);
 jpeg_create_compress(&c);jpeg_stdio_dest(&c,f);c.image_width=80;c.image_height=50;
 c.input_components=channels;c.in_color_space=channels==1?JCS_GRAYSCALE:channels==4?JCS_CMYK:JCS_RGB;
 jpeg_set_defaults(&c);jpeg_set_quality(&c,93,TRUE);if(mode==1)jpeg_simple_progression(&c);
 jpeg_start_compress(&c,TRUE);unsigned char row[80*4];
 while(c.next_scanline<c.image_height){unsigned y=c.next_scanline;
  for(unsigned x=0;x<80;x++)for(int k=0;k<channels;k++)row[x*channels+k]=(x*3+y*5+k*67)&255;
  JSAMPROW p=row;jpeg_write_scanlines(&c,&p,1);
 }
 jpeg_finish_compress(&c);jpeg_destroy_compress(&c);fclose(f);
 if(channels!=3)return 0;
 f=fopen(argv[1],"rb");struct jpeg_decompress_struct d;d.err=jpeg_std_error(&e);
 jpeg_create_decompress(&d);jpeg_stdio_src(&d,f);jpeg_read_header(&d,TRUE);d.out_color_space=JCS_RGB;
 jpeg_start_decompress(&d);FILE *out=fopen(argv[2],"wb");if(!out)return 1;
 while(d.output_scanline<d.output_height){JSAMPROW p=row;jpeg_read_scanlines(&d,&p,1);if(fwrite(row,1,240,out)!=240)return 1;}
 jpeg_finish_decompress(&d);jpeg_destroy_decompress(&d);fclose(f);fclose(out);return 0;
}
