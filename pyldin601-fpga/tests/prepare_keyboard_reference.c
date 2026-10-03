// Use the existing emulator fixture and the original keyboard.c translator.
// Expected PC set-1 codes in the HDL bench are independent of ps2_set2.mem.
#define main firmware_boot_main
#include "test_firmware.c"
#undef main

int main(void) {
    FILE *out = fopen("build/keyboard-reference.mem", "w");
    if (!out) return 1;
    for (unsigned mode = 0; mode < 8; mode++) {
        flagKey = ((mode & 2) ? 1 : 0) | ((mode & 1) ? 2 : 0);
        cyrMode = mode & 4;
        for (unsigned scan = 0; scan < 128; scan++)
            fprintf(out, "%02x\n", KBDTranslateKey(scan));
    }
    if (fclose(out)) return 1;
    puts("Prepared all eight keyboard modes from original keyboard.c");
    return 0;
}
