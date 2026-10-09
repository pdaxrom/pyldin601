// Actual UniDOS directory operations against the durable C host volume.
#define _POSIX_C_SOURCE 200809L
#define _DARWIN_C_SOURCE
#include <assert.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#define HG_UNIDOS_MAIN unused_hg_main
#include "test_hg_unidos.c"
static HgVolume volume;
static int durable_write(unsigned block, const uint8_t *data, unsigned length) {
    return hg_volume_write(&volume, block, data, length);
}
static void native_command(const char *text) {
    command(text);
    if (contains("File creation failure") || contains("Unknown error") ||
        contains("Path not found") || contains("Bad command") || resets) {
        dump();
        fprintf(stderr, "native directory command failed: %s\n", text);
        exit(1);
    }
    assert(!hg_volume_sync(&volume));
    host_image = volume.image;
}
static void verify_rom_copy(void) {
    uint8_t oracle[320 * 512];
    memcpy(oracle, physical + 0x20000, 65536);
    for (unsigned bank = 2; bank <= 4; bank++)
        memcpy(oracle + 65536 + (bank - 2) * 32768, physical + 0x10000 + bank * 65536, 32768);
    unsigned root = (le16(oracle + 14) + oracle[16] * le16(oracle + 22)) * 512;
    unsigned data = root + ((le16(oracle + 17) * 32 + 511) / 512) * 512;
    const uint8_t *table = oracle + le16(oracle + 14) * 512;
    HgFiles files = {0};
    assert(!hg_fat_files(volume.image, volume.size, &files));
    unsigned count = 0;
    for (unsigned at = root; at < root + le16(oracle + 17) * 32 && oracle[at]; at += 32) {
        const uint8_t *e = oracle + at;
        if (e[0] == 0xe5 || e[11] & 0x18)
            continue;
        char name[80] = "DISK_C/", *p = name + 7;
        for (unsigned k = 0; k < 8 && e[k] != ' '; k++)
            *p++ = e[k];
        *p++ = '.';
        for (unsigned k = 8; k < 11 && e[k] != ' '; k++)
            *p++ = e[k];
        *p = 0;
        const HgFile *f = hg_find(&files, name);
        assert(f && f->size == le32(e + 28));
        unsigned cluster = le16(e + 26), offset = 0, unit = oracle[13] * 512;
        while (offset < f->size) {
            unsigned length = f->size - offset > unit ? unit : f->size - offset;
            assert(!memcmp(f->data + offset, oracle + data + (cluster - 2) * unit, length));
            unsigned next = le16(table + cluster + cluster / 2);
            cluster = cluster & 1 ? next >> 4 : next & 4095;
            offset += length;
        }
        char path[1024];
        snprintf(path, sizeof(path), "%s/%s", volume.path, name);
        FILE *host = fopen(path, "rb");
        assert(host);
        for (unsigned k = 0; k < f->size; k++)
            assert(fgetc(host) == f->data[k]);
        assert(fgetc(host) == EOF && !fclose(host));
        count++;
    }
    assert(count == 13);
    hg_files_free(&files);
}
static void cleanup(const char *path) {
    DIR *dir = opendir(path);
    assert(dir);
    struct dirent *e;
    while ((e = readdir(dir))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, ".."))
            continue;
        char name[1024];
        snprintf(name, sizeof(name), "%s/%s", path, e->d_name);
        struct stat st;
        assert(!lstat(name, &st));
        if (S_ISDIR(st.st_mode))
            cleanup(name);
        else
            assert(!unlink(name));
    }
    closedir(dir);
    assert(!rmdir(path));
}
int main(int argc, char **argv) {
    if (argc != 4)
        return 2;
    model_a = !strcmp(argv[2], "601a");
    cpu_hd = !strcmp(argv[3], "hd6303");
    hg_v2 = 1;
    MC6800SetMachine(cpu_hd ? PYLDIN_MACHINE_HD6303 : PYLDIN_MACHINE_601);
    size_t size;
    uint8_t *rom = load(model_a ? "build/rom-a.reference" : "build/rom.reference", &size);
    assert(size == 0x51a00);
    memcpy(config, rom, 64);
    memcpy(physical + 0x10000, rom + 512, 0x51800);
    free(rom);
    image = load(argv[1], &image_size);
    memcpy(config + 64, image + 462, 32);
    char dir[] = "/tmp/p601-hg-unidos-XXXXXX";
    assert(mkdtemp(dir));
    assert(!hg_volume_open(&volume, dir, true, HG_MAX_SECTORS, false));
    host_image = volume.image;
    host_size = volume.size;
    host_write = durable_write;
    committed = 1;
    MC6800Init();
    MC6800Reset();
    until(60000000);
    key(0x1c);
    key(0x1c);
    until(virtual_cycles + 1000000);
    watch_resets = 1;
    native_command("b:hg");
    native_command("md e:disk_c");
    native_command("copy c:*.* e:disk_c\\*.*");
    verify_rom_copy();
    native_command("md e:disk_c\\sub");
    native_command("copy e:disk_c\\ue.cmd e:disk_c\\sub\\ue.cmd");
    native_command("copy e:disk_c\\sub\\ue.cmd a:ue.cmd");
    HgFiles local = {0}, remote = {0};
    assert(!hg_fat_files(image + le32(image + 470) * 512, le32(image + 474) * 512, &local));
    assert(!hg_fat_files(volume.image, volume.size, &remote));
    assert(hg_same(hg_find(&local, "UE.CMD"), hg_find(&remote, "DISK_C/UE.CMD")));
    hg_files_free(&local);
    hg_files_free(&remote);
    native_command("del e:disk_c\\sub\\ue.cmd");
    native_command("rd e:disk_c\\sub");
    native_command("dir e:disk_c\\*.*");
    hg_volume_close(&volume);
    assert(!hg_volume_open(&volume, dir, true, HG_MAX_SECTORS, false));
    verify_rom_copy();
    hg_volume_close(&volume);
    cleanup(dir);
    printf("PASS native %s/%s HG v2: MD/COPY all 13 ROM files byte-exact to host DISK_C, "
           "nested COPY/read/delete/RD, C-server restart, zero resets\n",
           argv[2], argv[3]);
    return 0;
}
