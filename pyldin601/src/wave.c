/*
 *
 * Pyldin-601 emulator version 3.4
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2015
 *
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <SDL.h>
#include "core/types.h"
#include "core/devices.h"
#include "wave.h"
#include "rdtsc.h"

#define BUFFER_SIZE	2048

static SDL_AudioSpec sdl_audio = {48000, AUDIO_U8, 1, 0, 1024};

static int fInited = 0;

static byte dac_out = 0;

static int tick = 0;

static byte buffer[BUFFER_SIZE];
static int bufferLength = BUFFER_SIZE;
static int readPtr = 0;
static int writePtr = 0;

void audio_callback(void *data, byte *stream, int len)
{
    static byte lastValue = 0;
    int i;
    for (i = 0; i < len; i++) {
	if (readPtr == writePtr) {
	    stream[i] = lastValue;
	    continue;
	}

	stream[i] = buffer[readPtr++];
	lastValue = stream[i];

	if (readPtr == bufferLength) {
	    readPtr = 0;
	}
    }

}

int BeeperInit(void)
{
    fInited = 0;

    if ( SDL_InitSubSystem(SDL_INIT_AUDIO) < 0 ) {
	fprintf(stderr, "Couldn't init audio: %s\n", SDL_GetError());
	return -1;
    }

    sdl_audio.callback = audio_callback;
#ifdef _WIN32
    sdl_audio.samples = 512;
#endif

    if ( SDL_OpenAudio(&sdl_audio, 0) < 0 ) {
	fprintf(stderr, "Couldn't open audio: %s\n", SDL_GetError());
	return -1;
    }

    fInited = 1;

    SDL_PauseAudio(0);

    return 0;
}

void BeeperFinish(void)
{
    if (fInited) {
	SDL_PauseAudio(1);
	fInited = 0;
    }
}

void BeeperSetBit(byte val)
{
    CovoxSetByte(val?0xa0:0);
}

void CovoxSetByte(byte val)
{
    dac_out = val;
    if (tick == 0) {
	tick = rdtsc();
    } else {
	unsigned int new = rdtsc();
	unsigned int period = (new - tick) / 48000;
	tick = new;
//	fprintf(stderr, "----- %d %d\n", period, val);

	SDL_LockAudio();
	while (period-- > 0) {
	    unsigned int tmpPtr = writePtr + 1;
	    if (tmpPtr == bufferLength) {
		tmpPtr = 0;
	    }
	    if (tmpPtr == readPtr) {
		break;
	    }
	    buffer[writePtr] = val;
	    writePtr = tmpPtr;
	}
	SDL_UnlockAudio();
    }
}
