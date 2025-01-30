#pragma once

void initFloppy(void);
void freeFloppy(void);
void ejectFloppy(int disk);
void insertFloppy(int disk, char *path);
void FloppyManagerOn(int disk, char *dir);
void FloppyManagerUpdateList(int dir);
void FloppyManagerOff(void);
int  selectFloppy(int y);
int selectFloppyByNum(void);
