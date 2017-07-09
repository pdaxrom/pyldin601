#asm
    org		$100
    jmp		QZMAIN
    include	../DEVEL/CLIB.INC
    include	../DEVEL/LIBROM.INC
#endasm

char *framebuf;
int fb_size;

main()
{
    puts("Hello, World!\n\r");

    framebuf = 0xa000;

    fb_size = 0;

    while (fb_size++ < 8000) {
	*framebuf++ = 0;
    }

    puts("Bye!\n\r");

    return 0;
}
