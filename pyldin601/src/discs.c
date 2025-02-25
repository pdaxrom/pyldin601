#include <stdio.h>
#include <string.h>
#if defined(__APPLE__) && (__GNUC__)
#include <stdlib.h>
#else
#include <malloc.h>
#endif
#include <zlib.h>
typedef unsigned char UBYTE;
#include "core/floppy.h"

int loadDiskImage(char *name, int disk)
{
    gzFile inf = gzopen(name, "rb");

    if (!inf) 
        return -1;

    if (!diskImage[disk]) 
        diskImage[disk] = (char *) malloc(737280 * 2);

    diskSize[disk] = gzread(inf, diskImage[disk], 737280 * 2);

    gzclose(inf);

    if (diskSize[disk] <= 0) {
        free(diskImage[disk]);
        return -1;
    }

    diskChanged[disk] = 0;

    return 0;
}

int unloadDiskImage(char *name, int disk)
{
    int ret = 0;
    
    if (!diskImage[disk]) 
        return -1;

    if (diskChanged[disk] == 0) {
        free(diskImage[disk]);
        diskImage[disk] = NULL;
        return 0;
    }
    
    gzFile outf = gzopen(name, "wb9");
    if (!outf) {
        free(diskImage[disk]);
        diskImage[disk] = NULL;
        diskChanged[disk] = 0;
        return -1;
    }
    
    if (gzwrite(outf, diskImage[disk], diskSize[disk]) != diskSize[disk])
        ret = -1;

    free(diskImage[disk]);
    diskImage[disk] = NULL;
    diskChanged[disk] = 0;
    gzclose(outf);
    
    return ret;
}
