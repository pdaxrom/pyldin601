// Native UniDOS + actual assembled INT E8 accelerator, independent DMA model.
// Cycle/pad arbitration and asynchronous PAL crossings are tested by tb_dma.
#define GAMEBIOS_MAIN gamebios_suite
#include "test_gamebios.c"
int main(int argc,char**argv){
 dma_mmio_read=dma_read;dma_mmio_write=dma_write;
 int result=gamebios_suite(argc,argv);
 require(dma_jobs>(cpu_hd?12:7),"native BIOS uses shared DMA on both CPU ISAs");
 printf("PASS native INT E8 DMA accelerator %s/%s: %u jobs, ABI/ranges/stack/bank selectors/IRQ and GAMEBIOS palette lifecycle\n",argv[2],argv[3],dma_jobs);
 unsigned available=free_banks(),saved_sp=SP,saved_page=page,saved_group=ram_group;
 unsigned char original[8192];memcpy(original,pal,sizeof original);
 command("b:dmatest");
 require(contains("PASS: DMA 8K copy/fill, PAL restored."),"real DMATEST.PGM passes on native UniDOS");
 require(free_banks()==available&&SP==saved_sp&&page==saved_page&&ram_group==saved_group&&!memcmp(original,pal,sizeof original),"DMATEST releases banks, restores palette/selectors and DOS stack");
 require(service_invoke(0xe5,1,available,0x9000)==0,"reserve banks for DMATEST failure check");
 command("b:dmatest");require(contains("DMATEST: cannot allocate two banks."),"DMATEST handles no free banks");
 require(service_invoke(0xe5,2,0,0x9000)==0&&free_banks()==available,"DMATEST preserves foreign lease");
 dma_present=0;command("b:dmatest");require(contains("DMATEST: DMA FPGA + RAMMAN required."),"DMATEST diagnoses unavailable DMA");dma_present=1;
 require(SP==saved_sp&&free_banks()==available&&!memcmp(original,pal,sizeof original),"DMATEST error exits preserve resources");
 printf("PASS native DMATEST.PGM %s/%s: actual relocatable PGM, owned banks, PAL restore, exhaustion/unavailable DMA, clean exit\n",argv[2],argv[3]);
 return result;
}
