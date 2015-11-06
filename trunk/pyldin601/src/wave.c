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
#include "core/printer.h"
#include "wave.h"
#include "rdtsc.h"

static SDL_AudioSpec sdl_audio = {48000, AUDIO_S16, 2, 0, 128};

static int fInited = 0;

static byte dac_out = 0;

static int tick = 0;

void audio_callback(void *data, byte *stream, int len)
{
//fprintf(stderr, "SOUND %d\n", len);
    word *ptr = (word *) stream;
    for (int i = 0; i < len / 4; i++) {
	//stream[i] = (spkr_en == 3) && CAST(unsigned short)mem[0x4AA] ? -((54 * wave_counter++ / CAST(unsigned short)mem[0x4AA]) & 1) : sdl_audio.silence;
	ptr[i * 2 + 0] = (dac_out << 8) ^ 0x8000;
	ptr[i * 2 + 1] = (dac_out << 8) ^ 0x8000;
    }

//	spkr_en = io_ports[0x61] & 3;
}

int Speaker_Init(void)
{
return -1;
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

void Speaker_Finish(void)
{
    if (fInited) {
	SDL_PauseAudio(1);
	fInited = 0;
    }
}

void Speaker_Set(byte val)
{
    Covox_Set(val?0xa0:0);
}

void Covox_Set(byte val)
{
    dac_out = val;
    if (tick == 0) {
	tick = rdtsc();
    } else {
	unsigned int new = rdtsc();
	fprintf(stderr, "----- %d\n", new - tick);
	tick = new;
    }
}
