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

#define NUMBUF		2

static SDL_AudioDeviceID dev;

static SDL_AudioSpec sdl_audio;// = {48000, AUDIO_U8, 1, 0, 1024};

static int fInited = 0;

static byte dac_out = 0;

static unsigned int sound_count = 0;
static unsigned int sound_tick;

typedef struct {
	short *buf;
	unsigned int ptr;
	unsigned int size;
} sound_buf_t;

static sound_buf_t sound_buf[NUMBUF];
static int cur_buf = 0;
static int cur_out_buf = 0;

static SDL_sem *sem;

void audio_callback(void *data, byte *stream, int len)
{
	if (SDL_SemValue(sem) == NUMBUF) {
		return;
	}

	memcpy(stream, sound_buf[cur_out_buf].buf, len);

	cur_out_buf = (cur_out_buf + 1) % NUMBUF;

	SDL_SemPost(sem);
}

void BeeperFlush(int ticks, int enable_flag)
{
	if (!fInited) {
		return;
	}
	while(ticks >= sound_count) {
		sound_buf[cur_buf].buf[sound_buf[cur_buf].ptr++] = enable_flag?(dac_out << 7):0;
		sound_count += sound_tick;
		if (sound_buf[cur_buf].ptr == sound_buf[cur_buf].size) {
			sound_buf[cur_buf].ptr = 0;
			cur_buf = (cur_buf + 1) % NUMBUF;
			if (enable_flag) {
				SDL_SemWait(sem);
			}
		}
	}
}

int BeeperInit(int fullspeed)
{
	int i;

	static SDL_AudioSpec sdl_audio_want;

    fInited = 0;

    if ( SDL_InitSubSystem(SDL_INIT_AUDIO) < 0 ) {
    	fprintf(stderr, "Couldn't init audio: %s\n", SDL_GetError());
    	return -1;
    }

    SDL_memset(&sdl_audio_want, 0, sizeof(sdl_audio_want));

    sdl_audio_want.callback = audio_callback;

    sdl_audio_want.format   = 16;
    sdl_audio_want.channels = 1;
    sdl_audio_want.freq     = 48000;

#ifdef __BIONIC__
	#ifdef __mips__
    // Paladin Novo 7 has problem with small buffer :(
    sdl_audio_want.samples  = (1 <<(sdl_audio_want.freq / 12000 + 8));
	#else
    sdl_audio_want.samples  = (1 <<(sdl_audio_want.freq / 12000 + 7));
	#endif
#else
    sdl_audio_want.samples  = (1 <<(sdl_audio_want.freq / 12000 + 8));
#endif
    dev = SDL_OpenAudioDevice(NULL, 0, &sdl_audio_want, &sdl_audio, SDL_AUDIO_ALLOW_ANY_CHANGE);

    if (dev == 0) {
        SDL_Log("Failed to open audio: %s", SDL_GetError());
        return -1;
    }

    SDL_Log("audio samples = %d\n", sdl_audio.samples);
    SDL_Log("audio format  = %d\n", sdl_audio.format);
    SDL_Log("audio freq    = %d\n", sdl_audio.freq);
    SDL_Log("audio channels= %d\n", sdl_audio.channels);

    for (i = 0; i < NUMBUF; i++) {
    	sound_buf[i].ptr = 0;
    	sound_buf[i].size = sdl_audio.samples;
    	sound_buf[i].buf = malloc(sound_buf[i].size * sizeof(short));
    }

    cur_buf = 0;
    cur_out_buf = 0;
    sound_count = 0;
    sound_tick = 1000000 / sdl_audio.freq;

    sem = SDL_CreateSemaphore(NUMBUF);

    fInited = 1;

    SDL_PauseAudioDevice(dev, 0);

    return 0;
}

void BeeperFinish(void)
{
    if (fInited) {
    	SDL_PauseAudioDevice(dev, 1);
    	SDL_CloseAudioDevice(dev);
    	SDL_DestroySemaphore(sem);
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
}
