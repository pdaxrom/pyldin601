CC ?= cc
BUILD ?= ../../build/hg-host
CFLAGS ?= -O2 -g
FTDI_CFLAGS ?= $(shell pkg-config --cflags libftdi1)
FTDI_LIBS ?= $(shell pkg-config --libs libftdi1)
WARN := -std=c11 -Wall -Wextra -Wpedantic -Werror
COMMON := fat12.c volume.c protocol.c

.PHONY: all test clean
all: $(BUILD)/hgfsd
$(BUILD):
	mkdir -p $(BUILD)
$(BUILD)/hgfsd: hgfsd.c mpsse.c $(COMMON) hg.h | $(BUILD)
	$(CC) $(CFLAGS) $(WARN) $(FTDI_CFLAGS) hgfsd.c mpsse.c $(COMMON) $(FTDI_LIBS) -o $@
$(BUILD)/test_hg_host: ../../tests/test_hg_host.c $(COMMON) hg.h | $(BUILD)
	$(CC) $(CFLAGS) $(WARN) -I. ../../tests/test_hg_host.c $(COMMON) -o $@
test: all $(BUILD)/test_hg_host
	$(BUILD)/test_hg_host
	python3 ../../tests/test_hg_watch.py --daemon $(abspath $(BUILD)/hgfsd)
clean:
	rm -f $(BUILD)/hgfsd $(BUILD)/test_hg_host
