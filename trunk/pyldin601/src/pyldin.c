/*
 *
 * Pyldin-601 emulator version 3.4
 * Copyright (c) Sasha Chukov & Yura Kuznetsov, 2000-2015
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <dirent.h>
#include <zlib.h>

#include <SDL.h>
#include <SDL_opengles2.h>

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
#include "shader.h"
#include "rdtsc.h"

#include "kbdfix.h"

#ifndef VERSION
#define VERSION "unknown"
#endif

#include "virtkbd.xbm"
#include "vmenu.xbm"

#ifdef PYLDIN_LOGO
#include <SDL_image.h>
#include "logo.h"

SDL_Surface *pyldinLogo;
#endif

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

static int resetRequest;
static int exitRequest;

#define PRNFILE	"pyldin.prn"
static FILE *printerFile = NULL;

//
static SDL_Window *window;
static SDL_Surface *framebuffer;

static float scaleX = 1;
static float scaleY = 1;

static int enableVirtualKeyboard;
int	enableDiskManager;
static int drawMenu;
static int drawScreen;
static int drawInfo;

static volatile uint64_t currentCpuFrequency = 0;
static volatile uint64_t oneUSecDelay = 0;
static volatile uint64_t oneUSecDelayConst = 0;

void resetRequested(void)
{
    resetRequest = 1;
}

void exitRequested(void)
{
    exitRequest = 1;
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
			if (enableDiskManager) {
			    FloppyManagerUpdateList(-1);
			} else
			    jkeybDown(0x48); 
			break;
		    case JOYBUT_DOWN:
			if (enableDiskManager) {
			    FloppyManagerUpdateList(1);
			} else
			    jkeybDown(0x50); 
			break;
		    case JOYBUT_LEFT:	jkeybDown(0x4b); break;
		    case JOYBUT_RIGHT:	jkeybDown(0x4d); break;
		    case JOYBUT_TRIANGLE: jkeybDown(0x01); break; //ESC
		    case JOYBUT_CROSS:
			if (enableDiskManager) {
			    selectFloppyByNum();
			    FloppyManagerOff();
			    drawMenu = 1;
			    clearVScr = 1;
			    enableDiskManager = 0;
#ifdef USE_JOYMOUSE
			} else if (enableVirtualKeyboard) {
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
			if (enableDiskManager) {
			    break;
			}
			enableVirtualKeyboard = enableVirtualKeyboard?0:1;
			drawMenu = 1;
			clearVScr = 1;
			break;
#endif
		    case JOYBUT_LTRIGGER:
			if (enableVirtualKeyboard) {
			    break;
			}
			if (!enableDiskManager) {
			    enableDiskManager = 1;
			    FloppyManagerOn(FLOPPY_A, datadir);
			} else {
			    FloppyManagerOff();
			    drawMenu = 1;
			    clearVScr = 1;
			    enableDiskManager = 0;
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
		//int k=0;
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
		    //k = (int)sdlkey;
		    SDL_Log("key=%d\n", sdlkey);
		}
		//key(k, 0);
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
	    	x = (float)event.button.x / scaleX;
		y = (float)event.button.y / scaleY;
		vmenu_process = 1;
		break;
	    }
	    case SDL_MOUSEBUTTONUP:
		if (enableVirtualKeyboard) {
		    vkeybUp();
		}
		break;
	}
	
	if (vmenu_process) {
	    if (enableDiskManager) {
		selectFloppy(y);
		FloppyManagerOff();
		drawMenu = 1;
		enableDiskManager = 0;
	    } else {
		if (enableVirtualKeyboard) {
		    vkeybDown(x, y);
		}
		if (y > 216) {
		    if (x > 5 && x < 21) {
			//power off
			exitRequested();
		    } else if (x > 33 && x < 50 && enableVirtualKeyboard == 0) {
			enableDiskManager = 1;
			FloppyManagerOn(FLOPPY_A, datadir);
		    } else if (x > 63 && x < 80 && enableVirtualKeyboard == 0) {
			enableDiskManager = 1;
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
			enableVirtualKeyboard = enableVirtualKeyboard?0:1;
			//if (vkbdEnabled == 0) 
			drawMenu = 1;
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

    while (!exitRequest) {
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

#ifdef PYLDIN_LOGO

#ifdef __MINGW32__
#define	sleep(a)	_sleep((unsigned long)(a) * 1000l);
#endif


void LoadLogo(void)
{
    pyldinLogo = NULL;
    SDL_RWops *src = SDL_RWFromMem(pyldin_foto, pyldin_foto_len);
    SDL_Surface *tmp = IMG_LoadJPG_RW(src);
    if (!tmp) {
	SDL_Log("Loading logo... Failed!\n");
    } else {
	pyldinLogo = SDL_ConvertSurfaceFormat(tmp, SDL_PIXELFORMAT_ABGR8888, 0);
	SDL_FreeSurface(tmp);
	SDL_Log("Loading logo... Ok!\n");
    }
    SDL_FreeRW(src);
}

#endif

void clearScr()
{
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
    enum {
	ATTRIB_VERTEX,
	ATTRIB_TEXTUREPOSITON,
	NUM_ATTRIBUTES
    };

    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f,
    };

    static const GLfloat textureVertices[] = {
         0.0f,  1.0f,
         1.0f,  1.0f,
         0.0f,  0.0f,
         1.0f,  0.0f,
    };

    SDL_GLContext context;
    SDL_DisplayMode mode;

    SDL_Log("Video thread starting...");

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

    // Start of GL init

    GLuint vertexShader = -1;
    GLuint fragmentShader = -1;

    if (process_shader(&vertexShader, "shaders/shader.vert", GL_VERTEX_SHADER)) {
	SDL_Log("Unable load vertex shader");
	return 1;
    }

    if (process_shader(&fragmentShader, "shaders/shader.frag", GL_FRAGMENT_SHADER)) {
	SDL_Log("Unable load fragment shader");
	return 1;
    }

    GLuint shaderProgram  = glCreateProgram ();                 // create program object
    glAttachShader ( shaderProgram, vertexShader );             // and attach both...
    glAttachShader ( shaderProgram, fragmentShader );           // ... shaders to it

    glBindAttribLocation(shaderProgram, ATTRIB_VERTEX, "position");
    glBindAttribLocation(shaderProgram, ATTRIB_TEXTUREPOSITON, "inputTextureCoordinate");

    glLinkProgram ( shaderProgram );    // link the program
    glUseProgram  ( shaderProgram );    // and select it for usage

    glActiveTexture(GL_TEXTURE0);
    GLuint videoFrameTexture = 0;
    glGenTextures(1, &videoFrameTexture);
    glBindTexture(GL_TEXTURE_2D, videoFrameTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindTexture(GL_TEXTURE_2D, videoFrameTexture);

    GLint tex = glGetUniformLocation(shaderProgram, "tex");

    glUniform1i(tex, 0);

    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices);
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, textureVertices);
    glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);

    glViewport ( 0 , 0 , mode.w , mode.h );

    // End of GL init


#ifdef PYLDIN_ICON
    SetIcon(window);
#endif

    SDL_Surface *surface = SDL_CreateRGBSurface(SDL_SWSURFACE, 320, 240, 32,
#if SDL_BYTEORDER == SDL_LIL_ENDIAN     /* OpenGL RGBA masks */
                                 0x000000FF,
                                 0x0000FF00, 0x00FF0000, 0xFF000000
#else
                                 0xFF000000,
                                 0x00FF0000, 0x0000FF00, 0x000000FF
#endif
        );


    framebuffer = SDL_CreateRGBSurface(SDL_SWSURFACE, 320, 240, 16,
#if SDL_BYTEORDER == SDL_LIL_ENDIAN     /* OpenGL RGBA masks */
	0xF800, 0x07E0, 0x001F, 0x0000
#else
	0x001F, 0x07E0, 0xF800, 0x0000
#endif
        );

    scaleX = (float) mode.w / 320;
    scaleY = (float) mode.h / 240;

#ifdef PYLDIN_LOGO
    LoadLogo();

    if (pyldinLogo) {
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, pyldinLogo->w, pyldinLogo->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, pyldinLogo->pixels);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	SDL_GL_SwapWindow(window);

	sleep(1);
    }
#endif

    while (!exitRequest) {
	if ( ! enableDiskManager ) {
	    mc6845_drawScreen(framebuffer->pixels, framebuffer->w, framebuffer->h);
	}

	if (drawInfo) {
	    char buf[64];

	    sprintf(buf, "%1.2fMHz", (float)currentCpuFrequency / 1000);
//SDL_Log("CPU: %lld", actual_speed);
	    drawString(buf, 160, 28, 0xffff, 0);
	}

	if (enableVirtualKeyboard) {
	    drawXbm(virtkbd_pict_bits, 0, 0, virtkbd_pict_width, virtkbd_pict_height, 1);
	}

	if (drawMenu) {
	    drawXbm(vmenu_bits, 0, 216, vmenu_width, vmenu_height, 0);
	    drawMenu = 0;
	}

#ifdef USE_JOYSTICK
#ifdef USE_JOYMOUSE
	if (joymouse_enabled && (enableVirtualKeyboard || (joymouse_y >= 216))) {
	    drawChar('+', joymouse_x, joymouse_y, 0xff00, 0);
	    if (joymouse_y >= 216) {
		drawMenu = 1;
	    }
	}
#endif
#endif
	while(!(drawScreen || exitRequest)) {
	    usleep(1000);
	}

	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	SDL_GL_SwapWindow(window);

	SDL_BlitSurface(framebuffer, NULL, surface, NULL);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, surface->w, surface->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, surface->pixels);

	drawScreen = 0;
    }

#ifdef PYLDIN_LOGO
    if (pyldinLogo) {
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, pyldinLogo->w, pyldinLogo->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, pyldinLogo->pixels);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	SDL_GL_SwapWindow(window);
	sleep(1);
	SDL_FreeSurface(pyldinLogo);
    }
#endif

    SDL_GL_DeleteContext(context);
    SDL_DestroyWindow(window);

    SDL_Log("Video thread finished...");
    return 0;
}

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

byte *allocateCpuRam(dword size)
{
    return (byte *) malloc(sizeof(byte) * size);
}

void printer_put_char(byte data)
{
    if (!printerFile) {
	char file[256];
	char *home = getenv("HOME");
	if (home) {
	    sprintf(file, "%s/%s", home, PRNFILE);
	} else {
	    strcpy(file, PRNFILE);
	}

	SDL_Log("Printer file: %s\n", file);
	printerFile = fopen(file, "wb");
    }
    if (printerFile) {
	fputc(data, printerFile);
    }
}

int main(int argc, char *argv[])
{
    int setTimeFromHost = 0;
    int printerPortDevice = PRINTER_NONE;
    char *bootFloppy = NULL;

    drawInfo = 0;
    SDL_Thread *videoThread;
    SDL_Thread *inputThread;

    SDL_Log("Portable Pyldin-601 emulator version " VERSION " (http://pyldin.info)\n");
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
//	    vScale = atoi(optarg);
//	    SDL_Log("scale %d\n", vScale);
	    break;
	case 't':
	    setTimeFromHost = 1;
	    break;
	case 'i':
	    drawInfo = 1;
	    break;
        case 'd':
	    datadir = optarg;
            break;
	case 'p':
	    if (!strcmp(optarg, "file")) {
		printerPortDevice = PRINTER_FILE;
	    } else if (!strcmp(optarg, "covox")) {
		printerPortDevice = PRINTER_COVOX;
	    } else if (!strcmp(optarg, "system")) {
		printerPortDevice = PRINTER_SYSTEM;
	    }
	    break;
	case 'g':
//	    sscanf(optarg, "%dx%d", &vscr_width, &vscr_height);
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


    mc6800Init();

    {
	volatile uint64_t a = rdtsc();
	sleep(1);
	oneUSecDelay = rdtsc();
#ifdef __PPC__
#warning "PPC PS3 calculation, fixme"
	oneUSecDelay -= a;
	SDL_Log("Detecting host cpu frequency... %lld MHz\n", oneUSecDelay * 4 / 100000);
	oneUSecDelay /= 1000000;
	oneUSecDelayConst = oneUSecDelay;
#else
	oneUSecDelay -= a;
	oneUSecDelay /= 1000000;
	oneUSecDelayConst = oneUSecDelay;
	SDL_Log("Detecting host cpu frequency... %lld MHz\n", oneUSecDelayConst);
#endif
    }

    initFloppy();

    if (bootFloppy) {
	insertFloppy(FLOPPY_A, bootFloppy);
    }

    printer_init(printerPortDevice);

    // sound initialization
    Speaker_Init();

    drawScreen = 0;
    drawMenu = 1;
    enableVirtualKeyboard = 0;
    enableDiskManager = 0;
    resetRequest = 0;
    exitRequest = 0;

    videoThread = SDL_CreateThread(HandleVideo, "Pyldin video", NULL);
    inputThread = SDL_CreateThread(HandleKeyboard, "Pyldin keyboard", NULL);

    mc6800Reset();

    int vSyncCounter = 0;		//

    if (setTimeFromHost) {
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

    volatile uint64_t emulatorCycleStarted = rdtsc();
    volatile uint64_t oldClockCounter = emulatorCycleStarted;
    do {
	int cpuCycles = mc6800Step();

	vSyncCounter += cpuCycles;

	if (vSyncCounter >= 20000) {
	    devices_set_tick50();
	    mc6845_curBlink();
	    mc6800SetInterrupt(1);
	    drawScreen = 1;

	    volatile uint64_t newClockCounter = rdtsc();
	    currentCpuFrequency = (vSyncCounter * 1000) / ((newClockCounter - oldClockCounter) / oneUSecDelayConst);
	
	    oldClockCounter = newClockCounter;
	    vSyncCounter = 0;

	    int diff = abs(1000 - currentCpuFrequency);
//SDL_Log("--- %d", diff);
	    if (diff < 10) {
		diff = 1;
	    } else {
		diff /= 10;
	    }

	if (currentCpuFrequency && currentCpuFrequency < 1000) {
//SDL_Log("+++ %lld, %lld, %d", one_takt_delay, actual_speed, diff);
	    oneUSecDelay -= diff;
	} else if (currentCpuFrequency && currentCpuFrequency > 1000) {
//SDL_Log("--- %lld, %lld, %d", one_takt_delay, actual_speed, diff);
	    oneUSecDelay += diff;
	}

	}

	if (resetRequest == 1) {
	    mc6800Reset();
	    resetRequest = 0;
	}


	volatile uint64_t emulatorCycleFinished;
	do {
	    emulatorCycleFinished = rdtsc();
	} while ((emulatorCycleFinished - emulatorCycleStarted) < (oneUSecDelay * cpuCycles));
	emulatorCycleStarted = emulatorCycleFinished;

    } while( exitRequest == 0);	//

    SDL_WaitThread(videoThread, NULL);
    SDL_WaitThread(inputThread, NULL);

    freeFloppy();

    mc6800Finish();
    Speaker_Finish();
    printer_fini();

    SDL_Quit();

//    SDL_Quit();
    return 0;
}
