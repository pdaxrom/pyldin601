#define NK_INCLUDE_FIXED_TYPES
#define NK_INCLUDE_STANDARD_IO
#define NK_INCLUDE_STANDARD_VARARGS
#define NK_INCLUDE_DEFAULT_ALLOCATOR
#define NK_INCLUDE_FONT_BAKING
#define NK_INCLUDE_DEFAULT_FONT
#define NK_IMPLEMENTATION
#define NK_SDL_GFX_IMPLEMENTATION

#include "nuklear/nuklear.h"
#include "nuklear/sdl_gfx/nuklear_sdl_gfx.h"
#include "gui.h"

#ifdef USE_GLES2
#include <SDL_opengles2.h>
#else
#define GL_GLEXT_PROTOTYPES
#include <SDL_opengl.h>
#endif

int open_config_window(SDL_Window *window, SDL_Surface *surface, int *enable_sound, int *enable_turbo, int *keyboard_opaque)
{
    SDL_Renderer *renderer;
    struct nk_color background;
    int win_width, win_height;
    int running = 1;

	int flag_sound = *enable_sound;
	int flag_turbo = *enable_turbo;
	int keyb_opaque = *keyboard_opaque;


    static SDL_BlendMode blendMode = SDL_BLENDMODE_NONE;

    /* GUI */
    struct nk_context *ctx;

    SDL_Log("Open config window\n");

    SDL_GetWindowSize(window, &win_width, &win_height);

    surface = SDL_CreateRGBSurface(SDL_SWSURFACE, win_width, win_height, 32,
#if SDL_BYTEORDER == SDL_LIL_ENDIAN     /* OpenGL RGBA masks */
                                 0x000000FF,
                                 0x0000FF00, 0x00FF0000, 0xFF000000
#else
                                 0xFF000000,
                                 0x00FF0000, 0x0000FF00, 0x000000FF
#endif
        );


    renderer = SDL_CreateSoftwareRenderer(surface);
    if (!renderer) {
    	SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Render creation for surface fail : %s\n",SDL_GetError());
    	return 1;
    }

    SDL_SetRenderDrawBlendMode(renderer, blendMode);
    SDL_SetRenderDrawColor(renderer, 0xA0, 0xA0, 0xA0, 0xFF);
    SDL_RenderClear(renderer);

    /* GUI */
    ctx = nk_sdl_init(window, renderer);

    /* Load Fonts: if none of these are loaded a default font will be used  */
    /* Load Cursor: if you uncomment cursor loading please hide the cursor */
    {
    	struct nk_font_atlas *atlas;
    	nk_sdl_font_stash_begin(&atlas);
    	nk_sdl_font_stash_end();
    }

//    background = nk_rgba(28, 48, 62, 0xff);
    background = nk_rgba(0, 0, 0, 0xff);
    while (running) {
    	SDL_Event evt;
    	nk_input_begin(ctx);
    	if (SDL_WaitEvent(&evt)) {
    		if (evt.type == SDL_QUIT ||
    				(evt.type == SDL_KEYUP && evt.key.keysym.sym == SDLK_ESCAPE)) {
    			running = 0;
    		}
    		if (evt.type == SDL_MOUSEBUTTONDOWN || evt.type == SDL_MOUSEBUTTONUP) {

    		}
    		nk_sdl_handle_event(&evt);
    	}
    	nk_input_end(ctx);

    	/* GUI */
    	if (nk_begin(ctx, "Settings", nk_rect(10, 10, 300, 220),
    			NK_WINDOW_BORDER|NK_WINDOW_TITLE)) {
			nk_layout_row_static(ctx, 30, 80, 1);

			nk_checkbox_label(ctx, "Sound", &flag_sound);
			nk_checkbox_label(ctx, "Turbo CPU", &flag_turbo);

			nk_layout_row_dynamic(ctx, 25, 1);
			nk_property_int(ctx, "Keyboard opaque:", 0, &keyb_opaque, 255, 10, 1);

			nk_layout_row_dynamic(ctx, 25, 2);

			if (nk_button_label(ctx, "OK")) {
				fprintf(stdout, "OK button pressed\n");
				*enable_sound = flag_sound;
				*enable_turbo = flag_turbo;
				*keyboard_opaque = keyb_opaque;
				running = 0;
			}

			if (nk_button_label(ctx, "Cancel")) {
				fprintf(stdout, "Cancel button pressed\n");
				running = 0;
			}
    	}

    	nk_end(ctx);

		SDL_SetRenderDrawColor(renderer, background.r, background.g, background.b, /*background.a*/ 255);
		SDL_RenderClear(renderer);

		nk_sdl_render();

		SDL_RenderPresent(renderer);

		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, surface->w, surface->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, surface->pixels);

	    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

	    SDL_GL_SwapWindow(window);
    }

	nk_sdl_shutdown();
	SDL_DestroyRenderer(renderer);
	SDL_FreeSurface(surface);

	return 0;
}
