/*
 *
 * Pyldin-601 emulator version 3.4
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2015
 *
 */

#pragma once

int  BeeperInit(int fullspeed);
void BeeperFinish(void);
void BeeperFlush(unsigned int ticks, int enable_flag);
