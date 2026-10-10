/* Offline FAT12 image packing shares the tested HG directory implementation. */
#include "../host/hg/hg.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned char *read_file(const char *name,size_t *size){
 FILE *f=fopen(name,"rb");if(!f)return NULL;
 if(fseek(f,0,SEEK_END)){fclose(f);return NULL;}long n=ftell(f);
 if(n<0||fseek(f,0,SEEK_SET)){fclose(f);return NULL;}
 unsigned char *p=malloc(n?n:1);if(!p||fread(p,1,n,f)!=(size_t)n){free(p);fclose(f);return NULL;}
 fclose(f);*size=n;return p;
}
int main(int argc,char **argv){
 if(argc<3)return 2;size_t size;unsigned char *image=read_file(argv[1],&size);if(!image)return 1;
 HgFiles files={0};
 for(int i=3;i<argc;i++){
  char *sep=strchr(argv[i],'=');if(!sep||sep-argv[i]>=HG_PATH_MAX)return 2;
  HgFile item={0};memcpy(item.name,argv[i],sep-argv[i]);item.date=0x5d41;
  item.attr=sep[1]?0x20:16;size_t length=0;
  if(sep[1]){item.data=read_file(sep+1,&length);if(!item.data||length>UINT32_MAX)return 1;}
  item.size=(uint32_t)length;int rc=hg_file_copy(&files,&item);free(item.data);if(rc)return 1;
 }
 if(hg_fat_update(image,size,&files))return 1;
 HgFiles check={0};if(hg_fat_files(image,size,&check)||check.n!=files.n)return 1;
 for(unsigned i=0;i<files.n;i++){HgFile *x=hg_find(&check,files.v[i].name);if(!x||!hg_same(x,&files.v[i]))return 1;}
 FILE *f=fopen(argv[2],"wb");if(!f||fwrite(image,1,size,f)!=size||fclose(f))return 1;
 hg_files_free(&check);hg_files_free(&files);free(image);return 0;
}
