# Run from the project root: make -f firmware/Makefile firmware UNIAS=/path/to/unias
# Every instruction is assembled from checked-in firmware by UniAS.
UNIAS ?= unias
FAT_RAMMAN ?= 0
FAT_FLAGS := $(if $(filter 1,$(FAT_RAMMAN)),-D FAT_RAMMAN,)
UNILD ?= $(dir $(UNIAS_PATH))unild
UNIAR ?= $(dir $(UNIAS_PATH))uniar
CC ?= cc
BUILD := build
UNIAS_PATH := $(if $(filter /%,$(UNIAS)),$(UNIAS),$(shell command -v "$(UNIAS)"))
RUN := $(abspath tools/run-unias.sh)
DATA := $(abspath $(BUILD)/firmware-data)

.PHONY: firmware roms bootstrap tables storage game audio gfx hg memory extension sram all nc ramloader
all: firmware game audio gfx hg memory nc ramloader
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
	cd $(BUILD)/storage && sh $(RUN) MOUNT.PGM.log "$(UNIAS_PATH)" -l MOUNT.PGM.LST -o MOUNT.raw.PGM MOUNT.ASM
	cd $(BUILD)/storage && sh $(RUN) FORMAT.PGM.log "$(UNIAS_PATH)" -D FORMAT_TOOL -l FORMAT.PGM.LST -o FORMAT.raw.PGM MOUNT.ASM
	cd $(BUILD)/storage && sh $(RUN) UMOUNT.PGM.log "$(UNIAS_PATH)" -l UMOUNT.PGM.LST -o UMOUNT.raw.PGM UMOUNT.ASM
	cd $(BUILD)/storage && sh $(RUN) FDISK.PGM.log "$(UNIAS_PATH)" -l FDISK.PGM.LST -o FDISK.raw.PGM FDISK.ASM
	@set -e; for app in MOUNT FORMAT UMOUNT FDISK; do $(DATA) pgm $(BUILD)/storage/$$app.raw.PGM $(BUILD)/storage/$$app.PGM $(BUILD)/storage/$$app.PGM.LST $(BUILD)/storage/$$app.json 0; done
	$(DATA) index $(BUILD)/storage/manifest.json $(addprefix $(BUILD)/storage/,MOUNT.json FORMAT.json UMOUNT.json FDISK.json)
	rm -f $(BUILD)/storage/*.raw.PGM

game: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/game
	cp firmware/game/* $(BUILD)/game/
	cd $(BUILD)/game && sh $(RUN) ARKANOID.PGM.log "$(UNIAS_PATH)" -D GAME_MUSIC -l ARKANOID.PGM.LST -o ARKANOID.raw.PGM ARKANOID.ASM
	cd $(BUILD)/game && sh $(RUN) XONIX.PGM.log "$(UNIAS_PATH)" -D GAME_MUSIC -l XONIX.PGM.LST -o XONIX.PGM XONIX.ASM
	cd $(BUILD)/game && sh $(RUN) SDKTEST.PGM.log "$(UNIAS_PATH)" -l SDKTEST.PGM.LST -o SDKTEST.raw.PGM SDKTEST.ASM
	@set -e; for app in ARKANOID SDKTEST; do $(DATA) pgm $(BUILD)/game/$$app.raw.PGM $(BUILD)/game/$$app.PGM $(BUILD)/game/$$app.PGM.LST $(BUILD)/game/$$app.json auto; done
	$(DATA) pgm-info $(BUILD)/game/XONIX.PGM $(BUILD)/game/XONIX.json
	$(DATA) labels $(BUILD)/game/ARKANOID.PGM.LST $(BUILD)/game/arkanoid_labels.h GAME
	$(DATA) labels $(BUILD)/game/XONIX.PGM.LST $(BUILD)/game/xonix_labels.h XO
	$(DATA) labels $(BUILD)/game/SDKTEST.PGM.LST $(BUILD)/game/sdktest_labels.h SDK
	$(DATA) index $(BUILD)/game/manifest.json $(addprefix $(BUILD)/game/,ARKANOID.json SDKTEST.json XONIX.json)
	rm -f $(BUILD)/game/*.raw.PGM

audio: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/audio
	cp firmware/audio/* firmware/gfx/DEMOGFX.INC firmware/gfx/PALCOEF.ASM firmware/gfx/GFXCLIP.ASM $(BUILD)/audio/
	cd $(BUILD)/audio && sh $(RUN) DEMO.YM.log "$(UNIAS_PATH)" -l DEMO.YM.LST -o DEMO.YM DEMO.ASM
	cd $(BUILD)/audio && sh $(RUN) YPLAY.PGM.log "$(UNIAS_PATH)" -l YPLAY.PGM.LST -o YPLAY.raw.PGM YPLAY.ASM
	cd $(BUILD)/audio && sh $(RUN) GFXMUSIC.PGM.log "$(UNIAS_PATH)" -D GFXMUSIC_DEMO -l GFXMUSIC.PGM.LST -o GFXMUSIC.raw.PGM GFXMUSIC.ASM
	$(DATA) pgm $(BUILD)/audio/YPLAY.raw.PGM $(BUILD)/audio/YPLAY.PGM $(BUILD)/audio/YPLAY.PGM.LST $(BUILD)/audio/manifest.json auto
	$(DATA) pgm $(BUILD)/audio/GFXMUSIC.raw.PGM $(BUILD)/audio/GFXMUSIC.PGM $(BUILD)/audio/GFXMUSIC.PGM.LST $(BUILD)/audio/gfxmusic.json auto
	$(DATA) labels $(BUILD)/audio/YPLAY.PGM.LST $(BUILD)/audio/yplay_labels.h YP
	$(DATA) labels $(BUILD)/audio/GFXMUSIC.PGM.LST $(BUILD)/audio/gfxmusic_labels.h YP
	rm -f $(BUILD)/audio/*.raw.PGM

gfx: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/gfx
	cp firmware/gfx/* firmware/audio/AY.ASM firmware/audio/AYHOWTO.TXT $(BUILD)/gfx/
	@set -e; for app in GFX VIEW SPRITES HAM CLIPSPR AY HVIEW; do \
	(cd $(BUILD)/gfx && sh $(RUN) $$app.log "$(UNIAS_PATH)" -l $$app.LST -o $$app.raw.PGM $$app.ASM); \
	trim=0; case $$app in VIEW|HAM|HVIEW) trim=8192;; esac; \
	$(DATA) pgm $(BUILD)/gfx/$$app.raw.PGM $(BUILD)/gfx/$$app.PGM $(BUILD)/gfx/$$app.LST $(BUILD)/gfx/$$app.json $$trim; done
	rm -f $(BUILD)/gfx/*.raw.PGM

hg: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/hg
	cp firmware/hg/* $(BUILD)/hg/
	cd $(BUILD)/hg && sh $(RUN) HG.log "$(UNIAS_PATH)" -l HG.LST -o HG.raw.PGM HG.ASM
	cd $(BUILD)/hg && sh $(RUN) HGTIME.log "$(UNIAS_PATH)" -D TIME_ONLY -l HGTIME.LST -o HGTIME.raw.PGM HG.ASM
	@set -e; for app in HG HGTIME; do $(DATA) pgm $(BUILD)/hg/$$app.raw.PGM $(BUILD)/hg/$$app.PGM $(BUILD)/hg/$$app.LST $(BUILD)/hg/$$app.json 0; done
	$(DATA) index $(BUILD)/hg/manifest.json $(BUILD)/hg/HG.json $(BUILD)/hg/HGTIME.json
	rm -f $(BUILD)/hg/*.raw.PGM

memory: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/memory-test
	cp firmware/memory/RAMPAGE.ASM firmware/memory/RAMHOW.TXT $(BUILD)/memory-test/
	cd $(BUILD)/memory-test && sh $(RUN) RAMPAGE.PGM.log "$(UNIAS_PATH)" -l RAMPAGE.PGM.LST -o RAMPAGE.raw.PGM RAMPAGE.ASM
	cd $(BUILD)/memory-test && sh $(RUN) RAMALLOC.PGM.log "$(UNIAS_PATH)" -D ALLOCATED_TEST -l RAMALLOC.PGM.LST -o RAMALLOC.raw.PGM RAMPAGE.ASM
	$(DATA) pgm $(BUILD)/memory-test/RAMPAGE.raw.PGM $(BUILD)/memory-test/RAMPAGE.PGM $(BUILD)/memory-test/RAMPAGE.PGM.LST $(BUILD)/memory-test/manifest.json 0
	$(DATA) pgm $(BUILD)/memory-test/RAMALLOC.raw.PGM $(BUILD)/memory-test/RAMALLOC.PGM $(BUILD)/memory-test/RAMALLOC.PGM.LST $(BUILD)/memory-test/ramalloc.json 0
	$(DATA) labels $(BUILD)/memory-test/RAMPAGE.PGM.LST $(BUILD)/memory-test/rampage_labels.h RP
	rm -f $(BUILD)/memory-test/*.raw.PGM

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
	cp firmware/nc/* $(BUILD)/nc/
	@set -e; for app in NC NCMAIN NCEDIT NCELOAD; do \
	defs=""; if [ "$$app" = NCEDIT ]; then defs="-D NC_EDITOR"; fi; \
	(cd $(BUILD)/nc && sh $(RUN) $$app.log "$(UNIAS_PATH)" $$defs -l $$app.LST -o $$app.raw.PGM $$app.ASM); \
	$(DATA) pgm $(BUILD)/nc/$$app.raw.PGM $(BUILD)/nc/$$app.PGM $(BUILD)/nc/$$app.LST $(BUILD)/nc/$$app.json auto; \
	$(DATA) labels $(BUILD)/nc/$$app.LST $(BUILD)/nc/$$app.h $$app; done
	python3 tools/nc_editor_pack.py
	$(DATA) index $(BUILD)/nc/manifest.json $(BUILD)/nc/NC.json $(BUILD)/nc/NCMAIN.json $(BUILD)/nc/NCEDIT.json
	rm -f $(BUILD)/nc/*.raw.PGM

ramloader: $(BUILD)/firmware-data
	mkdir -p $(BUILD)/ramloader
	cp firmware/ramloader/* $(BUILD)/ramloader/
	@set -e; for app in RAMLOAD RAMCORE RAMCHECK; do \
	(cd $(BUILD)/ramloader && sh $(RUN) $$app.log "$(UNIAS_PATH)" -l $$app.LST -o $$app.raw.PGM $$app.ASM); \
	$(DATA) pgm $(BUILD)/ramloader/$$app.raw.PGM $(BUILD)/ramloader/$$app.PGM $(BUILD)/ramloader/$$app.LST $(BUILD)/ramloader/$$app.json auto; \
	$(DATA) labels $(BUILD)/ramloader/$$app.LST $(BUILD)/ramloader/$$app.h $$app; done
	cp $(BUILD)/ramloader/RAMLOAD.PGM $(BUILD)/ramloader/RAMLOAD.prefix.PGM
	cd $(BUILD)/ramloader && sh $(RUN) CRC16.log "$(UNIAS_PATH)" -l CRC16.LST -o CRC16.ROM CRC16.ASM
	cd $(BUILD)/ramloader && sh $(RUN) CRCALT.log "$(UNIAS_PATH)" -D SECOND_MODULE -l CRCALT.LST -o CRCALT.ROM CRC16.ASM
	python3 tools/ramloader_pack.py
	$(DATA) index $(BUILD)/ramloader/manifest.json $(BUILD)/ramloader/RAMLOAD.json $(BUILD)/ramloader/RAMCORE.json $(BUILD)/ramloader/RAMCHECK.json
	rm -f $(BUILD)/ramloader/*.raw.PGM

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
