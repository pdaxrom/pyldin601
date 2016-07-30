all: 6803 uartboot.bin bootloader

6803: 6803.PAS
	fpc $^

uartboot.bin: UARTBOOT.ASM
	./6803 UARTBOOT.ASM UARTBOOT.LST UARTBOOT.CMD
	cat UARTBOOT.CMD empty.bin > $@

clean:
	rm -f uartboot.bin *.LST *.CMD bootloader 6803 *.o

flash: uartboot.bin
	minipro -p AT29C010A -w uartboot.bin

bootloader: bootloader.c
	$(CC) $^ -o $@ -Wall -O2 -g
