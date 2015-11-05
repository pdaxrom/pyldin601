/*
 *
 * Pyldin-601 emulator version 3.1 for Linux,MSDOS,Win32
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2004
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <dirent.h>
#include <zlib.h>
#include <time.h>

#include <SDL.h>

#include "pyldin.h"
#include "core/mc6800.h"
#include "core/mc6845.h"
#include "core/devices.h"
#include "core/keyboard.h"
#include "core/floppy.h"
#include "core/printer.h"
#include "wave.h"
#include "sshot.h"
#include "printer.h"
#include "floppymanager.h"
#include "screen.h"

#include "kbdfix.h"

#ifndef VERSION
#define VERSION "unknown"
#endif

#include "virtkbd.xbm"
#include "vmenu.xbm"

#ifdef USE_JOYSTICK
#include "joyfix.h"
#ifdef USE_JOYMOUSE
static int joymouse_enabled = 0;
static int joymouse_x = 160;
static int joymouse_y = 110;
#endif
#endif

char *datadir = DATADIR;

#define MAX_LOADSTRING 100

static int fReset = 0;
static int fExit = 0;

#define PRNFILE	"pyldin.prn"
static FILE *prn = NULL;

//
static SDL_Window *window;
static SDL_Surface *screen;
static SDL_Surface *framebuffer;
static SDL_GLContext context;

static int vScale = 1;
static int vscr_width = 320;
static int vscr_height = 240;

static int vkbdEnabled = 0;
static int redrawVMenu = 0;
static int clearVScr = 0;

//
static int updateScreen = 0;
static int show_info = 0;
static volatile uint64_t actual_speed = 0;
//
int	filemenuEnabled = 0;
// timer
int	fRef = 0;

//
static volatile uint64_t one_takt_delay = 0;
static volatile uint64_t one_takt_calib = 0;
static volatile uint64_t one_takt_one_percent = 0;

#if defined(__PPC__)
#warning "PPC32 code"

#define TIMEBASE 79800000

#define READ_TIMESTAMP(val) \
{				\
    unsigned int tmp;		\
    do {			\
	__asm__ __volatile__ (	\
	"mftbu %0 \n\t"		\
	"mftb  %1 \n\t"		\
	"mftbu %2 \n\t"		\
	: "=r"(((long*)&val)[0]), "=r"(((long*)&val)[1]), "=r"(tmp)	\
	:			\
	);			\
    } while (tmp != (((long*)&val)[0]));	\
}

#elif defined(__i386__)

#define READ_TIMESTAMP(val) \
    __asm__ __volatile__("rdtsc" : "=A" (val))

#elif defined(__x86_64__)

#define READ_TIMESTAMP(val) \
    __asm__ __volatile__("rdtsc" : "=a" (((int*)&val)[0]), "=d" (((int*)&val)[1]));

#else

#define READ_TIMESTAMP(var) readTSC(&var)

static void readTSC(volatile uint64_t *v)
{
#if defined(__GNUC__) && defined(__ARM_ARCH_7A__)
    uint32_t pmccntr;
    uint32_t pmuseren;
    uint32_t pmcntenset;
    static int no_mrc = 0;

    // Read the user mode perf monitor counter access permissions.
    asm volatile ("mrc p15, 0, %0, c9, c14, 0" : "=r" (pmuseren));
    if (pmuseren & 1) {  // Allows reading perfmon counters for user mode code.
      asm volatile ("mrc p15, 0, %0, c9, c12, 1" : "=r" (pmcntenset));
      if (pmcntenset & 0x80000000ul) {  // Is it counting?
        asm volatile ("mrc p15, 0, %0, c9, c13, 0" : "=r" (pmccntr));
        // The counter is set up to count every 64th cycle
        *v = (uint64_t)pmccntr * 64;  // Should optimize to << 6
	return;
      }
    } else if (!no_mrc) {
	no_mrc = 1;
	SDL_Log("No tsc :( Use non optimized clock counter...");
    }
#endif
    struct timespec tp;
    clock_gettime (CLOCK_MONOTONIC_RAW, &tp);
    *v = (uint64_t)tp.tv_sec * 1e9 + tp.tv_nsec;
}

#endif

void resetRequested(void)
{
    fReset = 1;
}

void exitRequested(void)
{
    fExit = 1;
}

static void ChecKeyboard(void)
{
    SDL_Event event;
    int x = 0, y = 0;
    int vmenu_process = 0;

    if(SDL_WaitEvent(&event) > 0){
	switch(event.type) {
	    case SDL_QUIT:
		exitRequested();
		break;
#ifdef USE_JOYSTICK
	    case SDL_JOYBUTTONDOWN:
		switch(event.jbutton.button) {
		    case JOYBUT_HOME: 	exitRequested(); break; //OFF
		    case JOYBUT_START: 	resetRequested(); break;//RESET
		    case JOYBUT_UP:
			if (filemenuEnabled) {
			    FloppyManagerUpdateList(-1);
			} else
			    jkeybDown(0x48); 
			break;
		    case JOYBUT_DOWN:
			if (filemenuEnabled) {
			    FloppyManagerUpdateList(1);
			} else
			    jkeybDown(0x50); 
			break;
		    case JOYBUT_LEFT:	jkeybDown(0x4b); break;
		    case JOYBUT_RIGHT:	jkeybDown(0x4d); break;
		    case JOYBUT_TRIANGLE: jkeybDown(0x01); break; //ESC
		    case JOYBUT_CROSS:
			if (filemenuEnabled) {
			    selectFloppyByNum();
			    FloppyManagerOff();
			    redrawVMenu = 1;
			    clearVScr = 1;
			    filemenuEnabled = 0;
#ifdef USE_JOYMOUSE
			} else if (vkbdEnabled) {
			    x = joymouse_x;
			    y = joymouse_y;
			    vmenu_process = 1;
#endif
			} else
			    jkeybDown(0x39);   //SPACE 
			break;
		    case JOYBUT_SQUARE:	jkeybDown(0x0f); break;   //TAB
		    case JOYBUT_CIRCLE:	jkeybDown(0x1c); break;   //RETURN
#ifdef USE_JOYMOUSE
		    case JOYBUT_RTRIGGER:
			if (filemenuEnabled) {
			    break;
			}
			vkbdEnabled = vkbdEnabled?0:1;
			redrawVMenu = 1;
			clearVScr = 1;
			break;
#endif
		    case JOYBUT_LTRIGGER:
			if (vkbdEnabled) {
			    break;
			}
			if (!filemenuEnabled) {
			    filemenuEnabled = 1;
			    FloppyManagerOn(FLOPPY_A, datadir);
			} else {
			    FloppyManagerOff();
			    redrawVMenu = 1;
			    clearVScr = 1;
			    filemenuEnabled = 0;
			}
			break;
//		    case JOYBUT_SELECT:	savepng(vscr, 320 * vScale, 27 * 8 * vScale); break;
		    default: 		jkeybDown(0x39);
		}
		break;
	    case SDL_JOYBUTTONUP:
		switch(event.jbutton.button) {
		    case JOYBUT_SELECT:
		    case JOYBUT_LTRIGGER:
#ifdef USE_JOYMOUSE
		    case JOYBUT_RTRIGGER:
#endif
			break;
		    default:		jkeybUp();
		}
		break;
#ifdef USE_JOYMOUSE
	    case SDL_JOYAXISMOTION:
		//SDL_ShowCursor(1);
		//SDL_WarpMouse(160, 100);
		joymouse_enabled = 1;
		//joymouse_x++;
		//joymouse_y++;
		if (event.jaxis.axis == 0) {
		    int x = event.jaxis.value + 32768;
		    x *= 320 * vScale;
		    x /= 65535;
		    joymouse_x += (x - 160) / 10;
		    if (joymouse_x < 0) {
			joymouse_x = 0;
		    } else if (joymouse_x > (320 - 8)) {
			joymouse_x = 320 - 8;
		    }
		} else if (event.jaxis.axis == 1) {
		    int y = event.jaxis.value + 32768;
		    y *= 240 * vScale;
		    y /= 65535;
		    joymouse_y += (y - 120) / 10;
		    if (joymouse_y < 0) {
			joymouse_y = 0;
		    } else if (joymouse_y > (240 - 8)) {
			joymouse_y = 240 - 8;
		    }
		}
		break;
#endif
#endif
	    case SDL_KEYDOWN: {
		SDL_Keycode sdlkey = event.key.keysym.sym;
		int k=0;
		switch(sdlkey){
		case SDLK_UP:		jkeybDown(0x48); break;
		case SDLK_DOWN:		jkeybDown(0x50); break;
		case SDLK_LEFT:		jkeybDown(0x4b); break;
		case SDLK_RIGHT:	jkeybDown(0x4d); break;
		case SDLK_ESCAPE:	jkeybDown(0x01); break;
		
		case SDLK_F1:		jkeybDown(0x3b); break;
		case SDLK_F2:		jkeybDown(0x3c); break;
		case SDLK_F3:		jkeybDown(0x3d); break;
		case SDLK_F4:		jkeybDown(0x3e); break;
		case SDLK_F5:		jkeybDown(0x3f); break;
		case SDLK_F6:		jkeybDown(0x40); break;
		case SDLK_F7:		jkeybDown(0x41); break;
		case SDLK_F8:		jkeybDown(0x42); break;
		case SDLK_F9:		jkeybDown(0x43); break;
		case SDLK_F10:		jkeybDown(0x44); break;
		case SDLK_F11:		jkeybDown(0x57); break;
		case SDLK_F12:		jkeybDown(0x58); break;
		
		case SDLK_HOME:		jkeybDown(0x47); break;
		case SDLK_END:		jkeybDown(0x4f); break;
		case SDLK_INSERT:	jkeybDown(0x52); break;
		
		case SDLK_1:		jkeybDown(0x02); break;
		case SDLK_2:		jkeybDown(0x03); break;
		case SDLK_3:		jkeybDown(0x04); break;
		case SDLK_4:		jkeybDown(0x05); break;
		case SDLK_5:		jkeybDown(0x06); break;
		case SDLK_6:		jkeybDown(0x07); break;
		case SDLK_7:		jkeybDown(0x08); break;
		case SDLK_8:		jkeybDown(0x09); break;
		case SDLK_9:		jkeybDown(0x0a); break;
		case SDLK_0:		jkeybDown(0x0b); break;
		case SDLK_MINUS:	jkeybDown(0x0c); break;
		case SDLK_EQUALS:	jkeybDown(0x0d); break;
		case xSDLK_BACKSLASH:	jkeybDown(0x2b); break;
		case SDLK_BACKSPACE:	jkeybDown(0x0e); break;
		case xSDLK_LSUPER:	jkeybDown(0x46); break;

		case SDLK_TAB:		jkeybDown(0x0f); break;
		case xSDLK_q:		jkeybDown(0x10); break;
		case xSDLK_w:		jkeybDown(0x11); break;
		case xSDLK_e:		jkeybDown(0x12); break;
		case xSDLK_r:		jkeybDown(0x13); break;
		case xSDLK_t:		jkeybDown(0x14); break;
		case xSDLK_y:		jkeybDown(0x15); break;
		case xSDLK_u:		jkeybDown(0x16); break;
		case xSDLK_i:		jkeybDown(0x17); break;
		case xSDLK_o:		jkeybDown(0x18); break;
		case xSDLK_p:		jkeybDown(0x19); break;
		case xSDLK_BACKQUOTE:	jkeybDown(0x29); break;
		case SDLK_RETURN:	jkeybDown(0x1c); break;

		case xSDLK_a:		jkeybDown(0x1e); break;
		case xSDLK_s:		jkeybDown(0x1f); break;
		case xSDLK_d:		jkeybDown(0x20); break;
		case xSDLK_f:		jkeybDown(0x21); break;
		case xSDLK_g:		jkeybDown(0x22); break;
		case xSDLK_h:		jkeybDown(0x23); break;
		case xSDLK_j:		jkeybDown(0x24); break;
		case xSDLK_k:		jkeybDown(0x25); break;
		case xSDLK_l:		jkeybDown(0x26); break;
		case xSDLK_SEMICOLON:	jkeybDown(0x27); break;
		case xSDLK_QUOTE:	jkeybDown(0x28); break;
		case xSDLK_LEFTBRACKET:	jkeybDown(0x1a); break;
		case xSDLK_RIGHTBRACKET:	jkeybDown(0x1b); break;

		case xSDLK_z:		jkeybDown(0x2c); break;
		case xSDLK_x:		jkeybDown(0x2d); break;
		case xSDLK_c:		jkeybDown(0x2e); break;
		case xSDLK_v:		jkeybDown(0x2f); break;
		case xSDLK_b:		jkeybDown(0x30); break;
		case xSDLK_n:		jkeybDown(0x31); break;
		case xSDLK_m:		jkeybDown(0x32); break;
		case xSDLK_COMMA:	jkeybDown(0x33); break;
		case xSDLK_PERIOD:	jkeybDown(0x34); break;
		case SDLK_SLASH:	jkeybDown(0x35); break;

		case SDLK_SPACE:	jkeybDown(0x39); break;

		case SDLK_CAPSLOCK:	jkeybDown(0x3a); break;
		
		case SDLK_LCTRL:	jkeybModeDown(1); break;
		case SDLK_LSHIFT:	jkeybModeDown(2); break;
		case SDLK_RCTRL:	jkeybModeDown(1); break;
		case SDLK_RSHIFT:	jkeybModeDown(2); break;

//		case SDLK_PRINT:	savepng(vscr, 320 * vScale, 27 * 8 * vScale); break;
		case SDLK_PAUSE:	resetRequested(); break;
		case SDLK_SCROLLLOCK: {
		    Uint32 flags = SDL_GetWindowFlags(window);
		    if (flags & SDL_WINDOW_FULLSCREEN) {
			flags = SDL_FALSE;
		    } else {
			flags = SDL_TRUE;
		    }
		    if (!SDL_SetWindowFullscreen(window, flags)) {
			SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Unable to change video mode!\n");
		    }
		    break;
		}
		default:
		    k = (int)sdlkey;
		    SDL_Log("key=%d\n", sdlkey);
		}
//		key(k, 0);
		break;
	    }
	    case SDL_KEYUP: {
		SDL_Keycode sdlkey=event.key.keysym.sym;
		switch(sdlkey){

		case SDLK_LCTRL:	jkeybModeUp(1); break;
		case SDLK_LSHIFT:	jkeybModeUp(2); break;
		case SDLK_RCTRL:	jkeybModeUp(1); break;
		case SDLK_RSHIFT:	jkeybModeUp(2); break;

		default:
		    jkeybUp();
		}
		break;
	    }
	    case SDL_MOUSEBUTTONDOWN: {
	    	x = (event.button.x - ((vscr_width - 320 * vScale) >> 1)) / vScale;
		y = (event.button.y - ((vscr_height - 240 * vScale) >> 1)) / vScale;
		vmenu_process = 1;
		break;
	    }
	    case SDL_MOUSEBUTTONUP:
		if (vkbdEnabled) {
		    vkeybUp();
		}
	    default:
		break;
	}
	
	if (vmenu_process) {
	    if (filemenuEnabled) {
		selectFloppy(y);
		FloppyManagerOff();
		redrawVMenu = 1;
		clearVScr = 1;
		filemenuEnabled = 0;
	    } else {
		if (vkbdEnabled) {
		    vkeybDown(x, y);
		}
		if (y > 216) {
		    if (x > 5 && x < 21) {
			//power off
			exitRequested();
		    } else if (x > 33 && x < 50 && vkbdEnabled == 0) {
			filemenuEnabled = 1;
			FloppyManagerOn(FLOPPY_A, datadir);
		    } else if (x > 63 && x < 80 && vkbdEnabled == 0) {
			filemenuEnabled = 1;
			FloppyManagerOn(FLOPPY_B, datadir);
		    } else if (x > 93 && x < 110) {
			Uint32 flags = SDL_GetWindowFlags(window);
			if (flags & SDL_WINDOW_FULLSCREEN) {
			    flags = SDL_FALSE;
			} else {
			    flags = SDL_TRUE;
			}
			if (!SDL_SetWindowFullscreen(window, flags)) {
			    SDL_Log("Unable change video mode!\n");
			}
		    } else if (x > 123 && x < 140) {
//			savepng(vscr, 320 * vScale, 27 * 8 * vScale);
		    } else if (x > 274 && x < 300) {
			vkbdEnabled = vkbdEnabled?0:1;
			//if (vkbdEnabled == 0) 
			redrawVMenu = 1;
			clearVScr = 1;
		    }
		}
	    }
	}
    }
}

int SDLCALL HandleKeyboard(void *unused)
{
    SDL_Log("Keyboard thread starting...");

#ifdef USE_JOYSTICK
    SDL_Joystick *joystick = SDL_JoystickOpen(0);

    if (joystick == NULL) {
	SDL_Log("No joystick detected\n");
    } else {
	SDL_Log("Use joystick %s\n", SDL_JoystickName(SDL_JoystickIndex(joystick)));
    }
#endif

    while (!fExit) {
	ChecKeyboard();
    }

#ifdef USE_JOYSTICK
    if (joystick) {
	SDL_JoystickClose(joystick);
    }
#endif
    SDL_Log("Keyboard thread finished...");

    return 0;
}

void clearScr()
{
#warning "clearScr() stub"
}

void drawXbm(unsigned char *xbm, int xp, int yp, int w, int h, int over)
{
    screen_drawXbm(framebuffer->pixels, framebuffer->w, framebuffer->h, xbm, xp, yp, w, h, over);
}

void drawChar(unsigned int c, int xp, int yp, unsigned int fg, unsigned int bg)
{
    screen_drawChar(framebuffer->pixels, framebuffer->w, framebuffer->h, c, xp, yp, fg, bg);
}

void drawString(char *str, int xp, int yp, unsigned int fg, unsigned int bg)
{
    screen_drawString(framebuffer->pixels, framebuffer->w, framebuffer->h, str, xp, yp, fg, bg);
}

int SDLCALL HandleVideo(void *unused)
{
    SDL_Renderer *renderer;
    SDL_DisplayMode mode;

    SDL_Log("Video thread starting...");

//    SDL_Log("Set screen geometry to %dx%d, scale %d\n", vscr_width, vscr_height, vScale);

    SDL_GetDesktopDisplayMode(0, &mode);

    SDL_GL_SetAttribute(SDL_GL_BUFFER_SIZE, 16);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);

    window = SDL_CreateWindow("PYLDIN 601", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
	mode.w, mode.h, SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);

    if(!window) {
	SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Window creation fail : %s\n",SDL_GetError());
	return 1;
    }

    context = SDL_GL_CreateContext(window);
    if (!context) {
	SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Unable to create GL context : %s\n",SDL_GetError());
	return 1;
    }

    SDL_GL_MakeCurrent(window, context);

//    SDL_SetWindowTitle(window, "PYLDIN-601 Emulator v" VERSION);

#ifdef PYLDIN_ICON
    SetIcon(window);
#endif

    framebuffer = SDL_CreateRGBSurface(SDL_SWSURFACE, 320, 240, 16,
#if SDL_BYTEORDER == SDL_LIL_ENDIAN     /* OpenGL RGBA masks */
	0xF800, 0x07E0, 0x001F, 0x0000
#else
	0x001F, 0x07E0, 0xF800, 0x0000
#endif
        );

    screen = SDL_GetWindowSurface(window);
//SDL_UpdateWindowSurface(window);
//    renderer = SDL_CreateSoftwareRenderer(surface);
//    if(!renderer) {
//	SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Render creation for surface fail : %s\n", SDL_GetError());
//	return 1;
//    }

//    renderer = SDL_CreateSoftwareRenderer(screen);
//    if(!renderer) {
//	SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Render creation for surface fail : %s\n",SDL_GetError());
//	return 1;
//    }

#ifdef PYLDIN_LOGO
    LoadLogo();
    
    if (pyldin_logo) {
	SDL_SoftStretch(pyldin_logo, &pyldin_logo->clip_rect, screen, &screen->clip_rect);
	SDL_UpdateWindowSurface(window);
	sleep(1);
    }
#endif

    while (!fExit) {
	SDL_BlitScaled(framebuffer, NULL, screen, NULL);
	SDL_UpdateWindowSurface(window);
//SDL_Log("UP!");

	if ( ! filemenuEnabled ) {
	    mc6845_drawScreen(framebuffer->pixels, framebuffer->w, framebuffer->h);
	}

	if (show_info) {
	    char buf[64];

	    sprintf(buf, "%1.2fMHz", (float)actual_speed / 1000);
//SDL_Log("CPU: %lld", actual_speed);
	    drawString(buf, 160, 28, 0xffff, 0);
	}

	if (vkbdEnabled) {
	    drawXbm(virtkbd_pict_bits, 0, 0, virtkbd_pict_width, virtkbd_pict_height, 1);
	}

	if (redrawVMenu) {
	    drawXbm(vmenu_bits, 0, 216, vmenu_width, vmenu_height, 0);
	    redrawVMenu = 0;
	}

#ifdef USE_JOYSTICK
#ifdef USE_JOYMOUSE
	if (joymouse_enabled && (vkbdEnabled || (joymouse_y >= 216))) {
	    drawChar('+', joymouse_x, joymouse_y, 0xff00, 0);
	    if (joymouse_y >= 216) {
		redrawVMenu = 1;
	    }
	}
#endif
#endif
	while(!(updateScreen || fExit)) {
	    usleep(1000);
	}

	updateScreen = 0;
    }

#ifdef PYLDIN_LOGO
    if (pyldin_logo) {
	SDL_SoftStretch(pyldin_logo, &pyldin_logo->clip_rect, screen, &screen->clip_rect);
	SDL_UpdateWindowSurface(window);
	sleep(1);
    }
#endif

    SDL_GL_DeleteContext(context);
    SDL_DestroyWindow(window);

    SDL_Log("Video thread finished...");
    return 0;
}

#ifdef PYLDIN_LOGO
#include "logo.h"
#include <SDL_image.h>

#ifdef __MINGW32__
#define	sleep(a)	_sleep((unsigned long)(a) * 1000l);
#endif

SDL_Surface *pyldin_logo;

void LoadLogo(void)
{
    SDL_RWops *src = SDL_RWFromMem(pyldin_foto, pyldin_foto_len);

    SDL_Surface *tmp = IMG_LoadJPG_RW(src);

    if (!tmp) {
	SDL_Log("Loading logo... Failed!\n");
    } else {
	pyldin_logo = SDL_CreateRGBSurface(SDL_SWSURFACE,
					tmp->clip_rect.w,
					tmp->clip_rect.h,
					screen->format->BitsPerPixel,
					screen->format->Rmask,
					screen->format->Gmask,
					screen->format->Bmask,
					screen->format->Amask
					);

	SDL_BlitSurface(tmp, NULL, pyldin_logo, NULL);

	SDL_FreeSurface(tmp);
	SDL_Log("Loading logo... Ok!\n");
    }
    SDL_FreeRW(src);
}

#endif

#ifdef PYLDIN_ICON

#include "icon.h"

void SetIcon(SDL_Window *window)
{
    SDL_Surface *icon;

    SDL_RWops *src = SDL_RWFromMem(pyldin_icon, pyldin_icon_len);

    icon = IMG_LoadPNG_RW(src);

    if (!icon) {
	SDL_Log("Loading icon... Failed!\r\n");
	return;
    } else {
	SDL_Log("Loading icon... Ok!\r\n");
    }

    SDL_FreeRW(src);

    SDL_SetWindowIcon(window, icon);

    SDL_FreeSurface(icon);
}
#endif

void usage(char *app)
{
    SDL_Log("Usage: %s [-d <dir>][-h][-i][-t][-p <type>][-s <N>][boot floppy image]\n", app);
    SDL_Log("-d <dir>  - path to directory with Rom/Floppy images\n");
    SDL_Log("-g WxH    - set screen geometry WxH\n");
    SDL_Log("-h        - this help\n");
    SDL_Log("-i        - show cpu performance\n");
    SDL_Log("-t        - setup date&time from host\n");
    SDL_Log("-p <type> - function of printer port:\n");
    SDL_Log("            file   - output to file\n");
    SDL_Log("            system - output to default system printer\n");
    SDL_Log("            covox  - output to unsigned 8bit DAC (COVOX emulation)\n");
    SDL_Log("-s <N>    - scale screen x N\n");
    exit(0);
}

static byte *pyldin_bios_mem = NULL;
static byte *pyldin_ramdisk_mem = NULL;
static byte *pyldin_romchip_mem[MAX_ROMCHIPS] = {NULL, NULL, NULL, NULL, NULL };
static byte *pyldin_videorom_mem = NULL;

static char *romName[] = {
    "str$08.roz",
    "str$09.roz",
    "str$0a.roz",
    "str$0b.roz",
    "str$0c.roz",
    "str$0d.roz",
    "str$0e.roz",
    "str$0f.roz"
};

static char *romDiskName[] = {
    "rom0.roz",
    "rom1.roz",
    "rom2.roz",
    "rom3.roz",
    "rom4.roz"
};

int load_packed_file(char *file, byte *mem, dword size)
{
   gzFile fi = gzopen(file, "rb");

    if (fi) {
	gzread(fi, mem, size);
	gzclose(fi); 
	return size;
    } else { 
	return 0;
    }
}

byte *get_bios_mem(dword size)
{
    char ftemp[256];

    if (pyldin_bios_mem) {
	return pyldin_bios_mem;
    }

    pyldin_bios_mem = (byte *) malloc(sizeof(byte) * size);

    sprintf(ftemp, "%s/Bios/bios.roz", datadir);

    if (load_packed_file(ftemp, pyldin_bios_mem, size)) {
	SDL_Log("Loading main rom... Ok\r\n");
    } else {
	SDL_Log("Loading main rom... Failed!\r\n");
    }

    return pyldin_bios_mem;
}

byte *get_videorom_mem(dword size)
{
    char ftemp[256];

    if (pyldin_videorom_mem) {
	return pyldin_videorom_mem;
    }

    pyldin_videorom_mem = (byte *) malloc(sizeof(byte) * size);

    sprintf(ftemp, "%s/Bios/video.roz", datadir);

    if (load_packed_file(ftemp, pyldin_videorom_mem, size)) {
	SDL_Log("Loading font rom... Ok\n");
    } else {
	SDL_Log("Loading font rom... Failed!\n"); 
    }

    return pyldin_videorom_mem;
}

byte *get_ramdisk_mem(dword size)
{
    if (!pyldin_ramdisk_mem) {
	pyldin_ramdisk_mem = (byte *) malloc(sizeof(byte) * size);
    }

    return pyldin_ramdisk_mem;
}

byte *get_romchip_mem(byte chip, dword size)
{
    char ftemp[256];
    int loaded = 0;

    if (chip >= MAX_ROMCHIPS) {
	chip = MAX_ROMCHIPS - 1;
    }
    if (size > 65536) {
	size = 65536;
    }

    if (!pyldin_romchip_mem[chip]) {
	pyldin_romchip_mem[chip] = (byte *) malloc(sizeof(byte) * size);
    }

    sprintf(ftemp, "%s/Rom/%s", datadir, romDiskName[chip]);

    if ((loaded = load_packed_file(ftemp, pyldin_romchip_mem[chip], size))) {
	if ((loaded > 0) & (!(loaded & 0x1fff))) {
	    SDL_Log("%s as ROM %d : 27%d\n", romDiskName[chip], chip, loaded / 1024 * 8);
	    int ptr = loaded;
	    while (ptr < 65536) {
		memcpy(pyldin_romchip_mem[chip] + ptr, pyldin_romchip_mem[chip], loaded);
		ptr += loaded;
	    }
	}
    }

    if ((chip == 0) && (loaded == 0)) {
	int i;
	for (i = 0; i < 8; i++) {
	    sprintf(ftemp, "%s/Rom/%s", datadir, romName[i]);
	    if (load_packed_file(ftemp, pyldin_romchip_mem[0] + i * 8192, 8192)) {
		char name[9];
		memset(name, 0, 9);
		memcpy(name, pyldin_romchip_mem[0] + i * 8192 + 2, 8);
		SDL_Log("%s as page %d\n", name, i);
	    }
	}
    }

    return pyldin_romchip_mem[chip];
}

byte *get_cpu_mem(dword size)
{
    return (byte *) malloc(sizeof(byte) * size);
}

void printer_put_char(byte data)
{
    if (!prn) {
	char file[256];
	char *home = getenv("HOME");
	if (home) {
	    sprintf(file, "%s/%s", home, PRNFILE);
	} else {
	    strcpy(file, PRNFILE);
	}

	SDL_Log("Printer file: %s\n", file);
	prn = fopen(file, "wb");
    }
    if (prn) {
	fputc(data, prn);
    }
}

int main(int argc, char *argv[])
{
    int set_time = 0;
    int printer_type = PRINTER_NONE;
    char *bootFloppy = NULL;
    Uint32 sys_flags;

    SDL_Thread *video_thread;
    SDL_Thread *keybd_thread;

    SDL_Log("Portable Pyldin-601 emulator version " VERSION " (http://code.google.com/p/pyldin)\n");
    SDL_Log("Copyright (c) 1997-2015 Sasha Chukov <sash@pdaXrom.org>, Yura Kuznetsov <yura@petrsu.ru>\n");

    extern char *optarg;
    extern int optind, optopt, opterr;
    int c;

    while ((c = getopt(argc, argv, "hits:d:p:g:")) != -1)
    {
        switch (c)
        {
	case 'h':
	    usage(argv[0]);
	    break;
	case 's':
	    vScale = atoi(optarg);
	    SDL_Log("scale %d\n", vScale);
	    break;
	case 't':
	    set_time = 1;
	    break;
	case 'i':
	    show_info = 1;
	    break;
        case 'd':
	    datadir = optarg;
            break;
	case 'p':
	    if (!strcmp(optarg, "file")) {
		printer_type = PRINTER_FILE;
	    } else if (!strcmp(optarg, "covox")) {
		printer_type = PRINTER_COVOX;
	    } else if (!strcmp(optarg, "system")) {
		printer_type = PRINTER_SYSTEM;
	    }
	    break;
	case 'g':
	    sscanf(optarg, "%dx%d", &vscr_width, &vscr_height);
	    break;
        default:
	    usage(argv[0]);
            break;
        }
    }

    for ( ; optind < argc; optind++) {
	bootFloppy = argv[optind];
    }

    SDL_LogSetPriority(SDL_LOG_CATEGORY_APPLICATION, SDL_LOG_PRIORITY_INFO);

    if (SDL_Init(SDL_INIT_EVERYTHING) < 0) { /* Initialize SDL's Video subsystem */
	SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "SDL_Init fail : %s\n", SDL_GetError());
	return 1;
    }


    mc6800_init();

    {
	volatile uint64_t a;
	READ_TIMESTAMP(a);
	sleep(1);
	READ_TIMESTAMP(one_takt_delay);
#ifdef __PPC__
#warning "PPC PS3 calculation, fixme"
	one_takt_delay -= a;
	SDL_Log("Detecting host cpu frequency... %lld MHz\n", one_takt_delay * 4 / 100000);
	one_takt_delay /= 1000000;
	one_takt_calib = one_takt_delay;
#else
	one_takt_delay -= a;
	one_takt_delay /= 1000000;
	one_takt_calib = one_takt_delay;
	SDL_Log("Detecting host cpu frequency... %lld MHz\n", one_takt_calib);
#endif
    }

    initFloppy();

    if (bootFloppy) {
	insertFloppy(FLOPPY_A, bootFloppy);
    }

    printer_init(printer_type);

    // sound initialization
//    Speaker_Init();

    updateScreen = 0;
    video_thread = SDL_CreateThread(HandleVideo, "Pyldin video", NULL);
    keybd_thread = SDL_CreateThread(HandleKeyboard, "Pyldin keyboard", NULL);

    mc6800_reset();

    vkbdEnabled = 0;
    redrawVMenu = 1;
    fReset = 0;
    fExit = 0;
    filemenuEnabled = 0;

    int vcounter = 0;		//
    int scounter = 0;		// syncro counter
    int takt;

    volatile uint64_t clock_old;
    READ_TIMESTAMP(clock_old);

//    vscr = (unsigned short *) framebuffer->pixels;

    if (set_time) {
	struct tm *dt;
	time_t t = time(NULL);
	dt = localtime(&t);
	devices_setDATETIME( dt->tm_year,
			    dt->tm_mon,
			    dt->tm_mday,
			    dt->tm_hour,
			    dt->tm_min,
			    dt->tm_sec
			    );
    }

    volatile uint64_t ts1;
    READ_TIMESTAMP(ts1);
    do {
	takt = mc6800_step();

	vcounter += takt;
	scounter += takt;

	if (vcounter >= 20000) {
	    devices_set_tick50();
	    mc6845_curBlink();
	    mc6800_setIrq(1);
	    updateScreen = 1;

	    volatile uint64_t clock_new;
	    READ_TIMESTAMP(clock_new);
	    actual_speed = (vcounter * 1000) / ((clock_new - clock_old) / one_takt_calib);
	
	    clock_old = clock_new;
	    vcounter = 0;

	    int diff = abs(1000 - actual_speed);
//SDL_Log("--- %d", diff);
	    if (diff < 10) {
		diff = 1;
	    } else {
		diff /= 10;
	    }

	if (actual_speed && actual_speed < 1000) {
//SDL_Log("+++ %lld, %lld, %d", one_takt_delay, actual_speed, diff);
	    one_takt_delay -= diff;
	} else if (actual_speed && actual_speed > 1000) {
//SDL_Log("--- %lld, %lld, %d", one_takt_delay, actual_speed, diff);
	    one_takt_delay += diff;
	}

	}

	if (fReset == 1) {
	    mc6800_reset();
	    fReset = 0;
	}


	volatile uint64_t ts2;
	do {
	    READ_TIMESTAMP(ts2);
	} while ((ts2 - ts1) < (one_takt_delay * takt));
	ts1 = ts2;

    } while( fExit == 0);	//

    SDL_WaitThread(video_thread, NULL);
    SDL_WaitThread(keybd_thread, NULL);

    freeFloppy();

    mc6800_fini();
    Speaker_Finish();
    printer_fini();

    SDL_Quit();

//    SDL_Quit();
    return 0;
}
