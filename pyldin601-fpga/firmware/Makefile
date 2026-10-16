# Run from the project root: make -f firmware/Makefile firmware UNIAS=/path/to/unias
# Every instruction is assembled from checked-in firmware by UniAS.
CVM_TOOLCHAIN ?= $(abspath ../../../FPGA/hd6303-toolchain)
UNIAS ?= $(CVM_TOOLCHAIN)/unias
FAT_RAMMAN ?= 0
FAT_FLAGS := $(if $(filter 1,$(FAT_RAMMAN)),-D FAT_RAMMAN,)
UNILD ?= $(dir $(UNIAS_PATH))unild
UNIAR ?= $(dir $(UNIAS_PATH))uniar
CC ?= cc
BUILD := build
UNIAS_PATH := $(if $(filter /%,$(UNIAS)),$(UNIAS),$(shell command -v "$(UNIAS)"))
RUN := $(abspath tools/run-unias.sh)
DATA := $(abspath $(BUILD)/firmware-data)

.PHONY: firmware roms bootstrap tables storage game audio gfx hg memory extension sram all nc ramloader input paint
all: firmware game audio gfx hg memory nc ramloader input paint
firmware: roms bootstrap tables storage
$(BUILD)/firmware-data: tools/firmware_data.c
	mkdir -p $(BUILD)
	$(CC) -std=c99 -O2 -Wall -Wextra -Wpedantic $< -o $@ -lm

roms: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/partitions
	cp firmware/bios/*.ASM firmware/bios/*.INC $(BUILD)/partitions/
	cp firmware/partitions/* firmware/memory/* firmware/game/* $(BUILD)/partitions/
	cp firmware/keyboard/* firmware/gfx/GFXCLIP.ASM firmware/gfx/PALCOEF.ASM $(BUILD)/partitions/
	$(DATA) ps2 firmware/ps2_set2.csv $(BUILD)/partitions/keyset2.mem $(BUILD)/partitions/KEYSET2.INC
	cp firmware/extension/DIRECTSD.ASM firmware/extension/RAWSD.ASM firmware/extension/SERVICES.ASM firmware/extension/INDICATOR.ASM $(BUILD)/partitions/
	cp firmware/bios/UNIDOS.ASM $(BUILD)/partitions/SHELL.ASM
	cp firmware/bios/UNISHELL.ASM $(BUILD)/partitions/SHELLROM.ASM
	cd $(BUILD)/partitions && sh $(RUN) KERNEL.ROM.log "$(UNIAS_PATH)" -l KERNEL.ROM.LST -o KERNEL.ROM U.ASM
	cd $(BUILD)/partitions && sh $(RUN) SHELL.CMD.log "$(UNIAS_PATH)" -l SHELL.CMD.LST -o SHELL.CMD SHELL.ASM
	$(DATA) shell $(BUILD)/partitions/SHELL.CMD $(BUILD)/partitions/SHELL.PACKED $(BUILD)/partitions/SHELLPACK.INC $(BUILD)/partitions/shell-pack.json
	cd $(BUILD)/partitions && sh $(RUN) UNIBIOS.ROM.log "$(UNIAS_PATH)" -l UNIBIOS.ROM.LST -o UNIBIOS.ROM UNIBIOS.ASM
	cd $(BUILD)/partitions && sh $(RUN) SHELL.ROM.log "$(UNIAS_PATH)" -l SHELL.ROM.LST -o SHELL.ROM SHELLROM.ASM
	cd $(BUILD)/partitions && sh $(RUN) SD.ROM.log "$(UNIAS_PATH)" -D GFXCLIP_ROM $(FAT_FLAGS) -l SD.ROM.LST -o SD.ROM DIRECTSD.ASM
	cd $(BUILD)/partitions && sh $(RUN) PARTS.ROM.log "$(UNIAS_PATH)" -l PARTS.ROM.LST -o PARTS.ROM PARTS.ASM
	cd $(BUILD)/partitions && sh $(RUN) RAMMAN.ROM.log "$(UNIAS_PATH)" -D WITH_GAMEBIOS -l RAMMAN.ROM.LST -o RAMMAN.ROM RAMMAN.ASM
	cd $(BUILD)/partitions && sh $(RUN) BIOS.ROM.log "$(UNIAS_PATH)" -l BIOS.ROM.LST -o BIOS.ROM BIOS.ASM
	cd $(BUILD)/partitions && sh $(RUN) BIOS_A.ROM.log "$(UNIAS_PATH)" -l BIOS_A.ROM.LST -o BIOS_A.ROM BIOS_A.ASM
	$(DATA) rom-index $(BUILD)/partitions $(BUILD)/partitions/manifest.json
	$(DATA) labels $(BUILD)/partitions/UNIBIOS.ROM.LST $(BUILD)/partitions/unibios_labels.h UB
	$(DATA) labels $(BUILD)/partitions/SHELL.ROM.LST $(BUILD)/partitions/shell_labels.h SH
	$(DATA) labels $(BUILD)/partitions/KERNEL.ROM.LST $(BUILD)/partitions/kernel_labels.h UK
	rm -f $(BUILD)/partitions/SHELLHEAD.INC $(BUILD)/partitions/SHELLTAIL.INC

bootstrap: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/bootstrap
	cp firmware/boot.asm firmware/setup.asm firmware/loader.asm firmware/keyboard/BOOTKEY.ASM $(BUILD)/bootstrap/
	cp firmware/setup.asm $(BUILD)/bootstrap/SETUP.ASM
	cd $(BUILD)/bootstrap && sh $(RUN) boot.bin.log "$(UNIAS_PATH)" -l boot.bin.LST -o boot.bin boot.asm
	cd $(BUILD)/bootstrap && sh $(RUN) loader.bin.log "$(UNIAS_PATH)" -l loader.bin.LST -o loader.bin loader.asm
	cp $(BUILD)/bootstrap/boot.bin $(BUILD)/boot.bin
	cp $(BUILD)/bootstrap/loader.bin $(BUILD)/loader.bin
	$(DATA) labels $(BUILD)/bootstrap/boot.bin.LST $(BUILD)/boot-labels.json
	$(DATA) labels $(BUILD)/bootstrap/loader.bin.LST $(BUILD)/bootstrap/loader-labels.json
	$(DATA) mem $(BUILD)/boot.bin $(BUILD)/boot.mem
	@test "$$(wc -c < $(BUILD)/boot.bin)" -eq 8192

tables: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/font
	cp firmware/bios/VIDEO.ASM firmware/bios/FONT.INC $(BUILD)/font/
	cd $(BUILD)/font && sh $(RUN) VIDEO.log "$(UNIAS_PATH)" -o VIDEO.BIN VIDEO.ASM
	$(DATA) font-boot $(BUILD)/font/VIDEO.BIN rtl/font_boot.mem
	$(DATA) ps2 firmware/ps2_set2.csv rtl/ps2_set2.mem
	$(DATA) pal rtl/pal_waveform.mem rtl/pal_rgb332.mem
	$(DATA) ay rtl/ay8910.mem rtl/ay8910_init.vh

storage: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/storage
	cp firmware/storage/* $(BUILD)/storage/
	cd $(BUILD)/storage && sh $(RUN) MOUNT.PGM.log "$(UNIAS_PATH)" -l MOUNT.PGM.LST -o MOUNT.PGM MOUNT.ASM
	cd $(BUILD)/storage && sh $(RUN) FORMAT.PGM.log "$(UNIAS_PATH)" -D FORMAT_TOOL -l FORMAT.PGM.LST -o FORMAT.PGM MOUNT.ASM
	cd $(BUILD)/storage && sh $(RUN) UMOUNT.PGM.log "$(UNIAS_PATH)" -l UMOUNT.PGM.LST -o UMOUNT.PGM UMOUNT.ASM
	cd $(BUILD)/storage && sh $(RUN) FDISK.PGM.log "$(UNIAS_PATH)" -l FDISK.PGM.LST -o FDISK.PGM FDISK.ASM
	@set -e; for app in MOUNT FORMAT UMOUNT FDISK; do $(DATA) pgm-info $(BUILD)/storage/$$app.PGM $(BUILD)/storage/$$app.json; done
	$(DATA) index $(BUILD)/storage/manifest.json $(addprefix $(BUILD)/storage/,MOUNT.json FORMAT.json UMOUNT.json FDISK.json)

game: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/game
	cp firmware/game/* $(BUILD)/game/
	cd $(BUILD)/game && sh $(RUN) ARKANOID.PGM.log "$(UNIAS_PATH)" -D GAME_MUSIC -l ARKANOID.PGM.LST -o ARKANOID.PGM ARKANOID.ASM
	cd $(BUILD)/game && sh $(RUN) XONIX.PGM.log "$(UNIAS_PATH)" -D GAME_MUSIC -l XONIX.PGM.LST -o XONIX.PGM XONIX.ASM
	cd $(BUILD)/game && sh $(RUN) SDKTEST.PGM.log "$(UNIAS_PATH)" -l SDKTEST.PGM.LST -o SDKTEST.PGM SDKTEST.ASM
	$(DATA) pgm-info $(BUILD)/game/SDKTEST.PGM $(BUILD)/game/SDKTEST.json
	@set -e; for app in ARKANOID XONIX; do $(DATA) pgm-info $(BUILD)/game/$$app.PGM $(BUILD)/game/$$app.json; done
	$(DATA) labels $(BUILD)/game/ARKANOID.PGM.LST $(BUILD)/game/arkanoid_labels.h GAME
	$(DATA) labels $(BUILD)/game/XONIX.PGM.LST $(BUILD)/game/xonix_labels.h XO
	$(DATA) labels $(BUILD)/game/SDKTEST.PGM.LST $(BUILD)/game/sdktest_labels.h SDK
	$(DATA) index $(BUILD)/game/manifest.json $(addprefix $(BUILD)/game/,ARKANOID.json SDKTEST.json XONIX.json)

audio: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/audio
	cp firmware/audio/* firmware/gfx/DEMOGFX.INC firmware/gfx/PALCOEF.ASM firmware/gfx/GFXCLIP.ASM $(BUILD)/audio/
	cd $(BUILD)/audio && sh $(RUN) DEMO.YM.log "$(UNIAS_PATH)" -l DEMO.YM.LST -o DEMO.YM DEMO.ASM
	cd $(BUILD)/audio && sh $(RUN) YPLAY.PGM.log "$(UNIAS_PATH)" -l YPLAY.PGM.LST -o YPLAY.PGM YPLAY.ASM
	cd $(BUILD)/audio && sh $(RUN) GFXMUSIC.PGM.log "$(UNIAS_PATH)" -D GFXMUSIC_DEMO -l GFXMUSIC.PGM.LST -o GFXMUSIC.PGM GFXMUSIC.ASM
	$(DATA) pgm-info $(BUILD)/audio/YPLAY.PGM $(BUILD)/audio/manifest.json
	$(DATA) pgm-info $(BUILD)/audio/GFXMUSIC.PGM $(BUILD)/audio/gfxmusic.json
	$(DATA) labels $(BUILD)/audio/YPLAY.PGM.LST $(BUILD)/audio/yplay_labels.h YP
	$(DATA) labels $(BUILD)/audio/GFXMUSIC.PGM.LST $(BUILD)/audio/gfxmusic_labels.h YP

gfx: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/gfx
	cp firmware/gfx/* firmware/audio/AY.ASM firmware/audio/AYHOWTO.TXT $(BUILD)/gfx/
	@set -e; for app in GFX VIEW SPRITES HAM CLIPSPR AY HVIEW; do \
	(cd $(BUILD)/gfx && sh $(RUN) $$app.log "$(UNIAS_PATH)" -l $$app.LST -o $$app.PGM $$app.ASM); \
	$(DATA) pgm-info $(BUILD)/gfx/$$app.PGM $(BUILD)/gfx/$$app.json; done

hg: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/hg
	cp firmware/hg/* $(BUILD)/hg/
	cd $(BUILD)/hg && sh $(RUN) HG.log "$(UNIAS_PATH)" -l HG.LST -o HG.PGM HG.ASM
	cd $(BUILD)/hg && sh $(RUN) HGTIME.log "$(UNIAS_PATH)" -D TIME_ONLY -l HGTIME.LST -o HGTIME.PGM HG.ASM
	@set -e; for app in HG HGTIME; do $(DATA) pgm-info $(BUILD)/hg/$$app.PGM $(BUILD)/hg/$$app.json; done
	$(DATA) index $(BUILD)/hg/manifest.json $(BUILD)/hg/HG.json $(BUILD)/hg/HGTIME.json

memory: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/memory-test
	cp firmware/memory/RAMPAGE.ASM firmware/memory/RAMHOW.TXT $(BUILD)/memory-test/
	cd $(BUILD)/memory-test && sh $(RUN) RAMPAGE.PGM.log "$(UNIAS_PATH)" -l RAMPAGE.PGM.LST -o RAMPAGE.PGM RAMPAGE.ASM
	cd $(BUILD)/memory-test && sh $(RUN) RAMALLOC.PGM.log "$(UNIAS_PATH)" -D ALLOCATED_TEST -l RAMALLOC.PGM.LST -o RAMALLOC.PGM RAMPAGE.ASM
	$(DATA) pgm-info $(BUILD)/memory-test/RAMPAGE.PGM $(BUILD)/memory-test/manifest.json
	$(DATA) pgm-info $(BUILD)/memory-test/RAMALLOC.PGM $(BUILD)/memory-test/ramalloc.json
	$(DATA) labels $(BUILD)/memory-test/RAMPAGE.PGM.LST $(BUILD)/memory-test/rampage_labels.h RP
	cp firmware/memory/DMATEST.ASM firmware/memory/DMA.INC $(BUILD)/memory-test/
	cd $(BUILD)/memory-test && sh $(RUN) DMATEST.PGM.log "$(UNIAS_PATH)" -l DMATEST.PGM.LST -o DMATEST.PGM DMATEST.ASM
	$(DATA) pgm-info $(BUILD)/memory-test/DMATEST.PGM $(BUILD)/memory-test/dmatest.json

extension: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/extension
	cp firmware/extension/* firmware/gfx/GFXCLIP.ASM $(BUILD)/extension/
	cd $(BUILD)/extension && sh $(RUN) unias.log "$(UNIAS_PATH)" -D GFXCLIP_ROM -l FPGA.LST -o FPGA.ROM extension.asm
	$(DATA) labels $(BUILD)/extension/FPGA.LST $(BUILD)/extension/labels.json

sram: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/sram-diagnostic
	cp firmware/sram_test.asm $(BUILD)/sram-diagnostic/
	cd $(BUILD)/sram-diagnostic && sh $(RUN) sram.log "$(UNIAS_PATH)" -l sram.LST -o sram.bin sram_test.asm
	cp $(BUILD)/sram-diagnostic/sram.bin $(BUILD)/sram-test.bin
	$(DATA) mem $(BUILD)/sram-test.bin $(BUILD)/sram-test.mem

nc: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/nc
	cp firmware/nc/* firmware/input/MOUSE.ASM $(BUILD)/nc/
	@set -e; for app in NC NCELOAD; do \
	(cd $(BUILD)/nc && sh $(RUN) $$app.log "$(UNIAS_PATH)" -l $$app.LST -o $$app.PGM $$app.ASM); \
	$(DATA) pgm-info $(BUILD)/nc/$$app.PGM $(BUILD)/nc/$$app.json; \
	$(DATA) labels $(BUILD)/nc/$$app.LST $(BUILD)/nc/$$app.h $$app; done
	@set -e; for app in NCMAIN NCMCAT NCMUI NCMFILE NCMOUSE NCEMOUSE NCKEY NCCOM NCMSTR NCMV1 NCMV2 NCMV3 NCEND NCEDIT NCEFILE NCEUI NCENAV NCEBLOCK NCESTR NCEV1 NCEV2 NCEV3; do \
	(cd $(BUILD)/nc && sh $(RUN) $$app.log "$(UNIAS_PATH)" -c -l $$app.LST -o $$app.OBJ $$app.ASM); done
	cd $(BUILD)/nc && sh $(RUN) MOUSE.log "$(UNIAS_PATH)" -D MOUSE_OBJECT -c -l MOUSE.LST -o MOUSE.OBJ MOUSE.ASM
	cd $(BUILD)/nc && "$(UNIAR)" r NCUI.LIB NCCOM.OBJ NCKEY.OBJ MOUSE.OBJ
	@set -e; for app in NCMAIN NCEDIT; do \
	(cd $(BUILD)/nc && "$(UNILD)" -m $$app.MAP -o $$app.PGM @$$app.LNK); \
	$(DATA) linked-labels $(BUILD)/nc/$$app.MAP $(BUILD)/nc/$$app.h $$app; \
	$(DATA) pgm-info $(BUILD)/nc/$$app.PGM $(BUILD)/nc/$$app.json; done
	cp $(BUILD)/nc/NCEDIT.PGM $(BUILD)/nc/NCECORE.PGM
	cp $(BUILD)/nc/NCECORE.PGM $(BUILD)/nc/NCEDIT.core.PGM
	cd $(BUILD)/nc && "$(UNILD)" -b -o NCEDIT.PGM NCELOAD.PGM NCECORE.PGM
	$(DATA) pgm-bundle-info nc $(BUILD)/nc
	$(DATA) index $(BUILD)/nc/manifest.json $(BUILD)/nc/NC.json $(BUILD)/nc/NCMAIN.json $(BUILD)/nc/NCEDIT.json

ramloader: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/ramloader
	cp firmware/ramloader/* $(BUILD)/ramloader/
	@set -e; for app in RAMLOAD RAMCORE RAMCHECK; do \
	(cd $(BUILD)/ramloader && sh $(RUN) $$app.log "$(UNIAS_PATH)" -l $$app.LST -o $$app.PGM $$app.ASM); \
	$(DATA) pgm-info $(BUILD)/ramloader/$$app.PGM $(BUILD)/ramloader/$$app.json; \
	$(DATA) labels $(BUILD)/ramloader/$$app.LST $(BUILD)/ramloader/$$app.h $$app; done
	cp $(BUILD)/ramloader/RAMLOAD.PGM $(BUILD)/ramloader/RAMPREF.PGM
	cp $(BUILD)/ramloader/RAMPREF.PGM $(BUILD)/ramloader/RAMLOAD.prefix.PGM
	cd $(BUILD)/ramloader && sh $(RUN) CRC16.log "$(UNIAS_PATH)" -l CRC16.LST -o CRC16.ROM CRC16.ASM
	cd $(BUILD)/ramloader && sh $(RUN) CRCALT.log "$(UNIAS_PATH)" -D SECOND_MODULE -l CRCALT.LST -o CRCALT.ROM CRC16.ASM
	cd $(BUILD)/ramloader && "$(UNILD)" -b -o RAMLOAD.PGM RAMPREF.PGM RAMCORE.PGM
	$(DATA) pgm-bundle-info ramloader $(BUILD)/ramloader
	$(DATA) index $(BUILD)/ramloader/manifest.json $(BUILD)/ramloader/RAMLOAD.json $(BUILD)/ramloader/RAMCORE.json $(BUILD)/ramloader/RAMCHECK.json

# A real two-module XONIX build, also linked through a UniLIB archive.
.PHONY: game-objects
game-objects:
	mkdir -p $(BUILD)/game-objects
	cp firmware/game/*.ASM firmware/game/*.INC $(BUILD)/game-objects/
	cd $(BUILD)/game-objects && sh $(RUN) XOMAIN.log "$(UNIAS_PATH)" -c -D GAME_MUSIC -l XOMAIN.LST -o XOMAIN.OBJ XOMAIN.ASM
	cd $(BUILD)/game-objects && sh $(RUN) XOCFG.log "$(UNIAS_PATH)" -c -D GAME_MUSIC -o XOCFG.OBJ XOCFG.ASM
	cd $(BUILD)/game-objects && "$(UNILD)" -o XOOBJ.PGM XOMAIN.OBJ XOCFG.OBJ
	cd $(BUILD)/game-objects && "$(UNIAR)" r XCFG.LIB XOCFG.OBJ
	cd $(BUILD)/game-objects && "$(UNILD)" -o XOLIB.PGM XOMAIN.OBJ XCFG.LIB
	cmp $(BUILD)/game-objects/XOOBJ.PGM $(BUILD)/game-objects/XOLIB.PGM

input: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/input
	cp firmware/input/* $(BUILD)/input/
	cd $(BUILD)/input && sh $(RUN) UART.log "$(UNIAS_PATH)" -l UART.LST -o UART.PGM UART.ASM
	$(DATA) pgm-info $(BUILD)/input/UART.PGM $(BUILD)/input/UART.json
	$(DATA) labels $(BUILD)/input/UART.LST $(BUILD)/input/UART.h UART

paint: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/paint
	cp firmware/paint/* firmware/memory/DMA.INC firmware/gfx/PALCOEF.ASM firmware/input/MOUSE.ASM $(BUILD)/paint/
	cp firmware/nc/NCCOM.ASM firmware/nc/NCKEY.ASM firmware/nc/NCABI.INC firmware/nc/NCBOX.INC $(BUILD)/paint/
	@set -e; for app in PNTNAT PNTRGB PNTHAM; do \
	(cd $(BUILD)/paint && sh $(RUN) $$app.log "$(UNIAS_PATH)" -l $$app.LST -o $$app.PGM $$app.ASM); \
	$(DATA) pgm-info $(BUILD)/paint/$$app.PGM $(BUILD)/paint/$$app.json; done
	@set -e; for app in PNTMAIN PNTUI PNTCANV PNTDRAW PNTPART PNTPAL PNTDMA PNTLOAD PNTMOD PNTIO PNTPCX PNTIFF PNTFILE PNTDATA PNTSTATE PNTSTR PNTEND PNTCOM NCKEY; do \
	(cd $(BUILD)/paint && sh $(RUN) $$app.log "$(UNIAS_PATH)" -c -l $$app.LST -o $$app.OBJ $$app.ASM); done
	cd $(BUILD)/paint && sh $(RUN) MOUSE.log "$(UNIAS_PATH)" -c -D MOUSE_OBJECT -l MOUSE.LST -o MOUSE.OBJ MOUSE.ASM
	rm -f $(BUILD)/paint/PNTCOM.LIB
	cd $(BUILD)/paint && "$(UNIAR)" r PNTCOM.LIB PNTCOM.OBJ NCKEY.OBJ MOUSE.OBJ
	cd $(BUILD)/paint && sh $(RUN) PNTBOOT.log "$(UNIAS_PATH)" -l PNTBOOT.LST -o PNTBOOT.PGM PNTBOOT.ASM
	cd $(BUILD)/paint && "$(UNILD)" -m PAINT.MAP -o PNTCORE.PGM @PAINT.LNK
	cd $(BUILD)/paint && "$(UNILD)" -b -o PAINT.PGM PNTBOOT.PGM PNTCORE.PGM
	$(DATA) public-labels $(BUILD)/paint/PAINT.MAP $(BUILD)/paint/PAINT.h PNT
	$(DATA) pgm-bundle-info paint $(BUILD)/paint
