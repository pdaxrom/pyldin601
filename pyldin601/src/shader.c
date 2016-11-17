/*
 *
 * Portable Pyldin-601 emulator
 * Copyright (c) Sasha Chukov, 2016
 *
 */

#include <stdio.h>
#include <malloc.h>
#include <SDL.h>
#include "shader.h"

char *load_shader(char *fileName) {
    char *text = NULL;
    long len = 0;

    SDL_RWops* file = SDL_RWFromFile(fileName, "rb" );

    if (!file) {
        fprintf(stderr, "Error: Cannot read file '%s'\n", fileName);
	return NULL;
    }

    len = SDL_RWsize(file);
    text = calloc(len + 1, sizeof(char));

    if (SDL_RWread(file, text, 1, len) == len) {
	text[len] = '\0';
    } else {
	free(text);
	text = NULL;
    }
    SDL_RWclose(file);

    return text;
}

int process_shader(GLuint *shader, char *fileName, GLint shaderType) {
    GLint iStatus;
    const char *texts[1] = { NULL };

    /* Create shader and load into GL. */
    *shader = glCreateShader(shaderType);

    texts[0] = load_shader(fileName);
    if (!texts[0]) {
	return 1;
    }

    glShaderSource(*shader, 1, texts, NULL);

    int errCode = glGetError();
    if (errCode != GL_NO_ERROR) {
	fprintf(stderr, "GLErr.  %X\n", errCode);
	return 1;
    }

    /* Clean up shader source. */
    free((void *)texts[0]);
    texts[0] = NULL;

    /* Try compiling the shader. */
    glCompileShader(*shader);

    glGetShaderiv(*shader, GL_COMPILE_STATUS, &iStatus);

    // Dump debug info (source and log) if compilation failed.
    if(iStatus != GL_TRUE) {
#if 1
	GLint len;
	char *debugSource = NULL;
	char *errorLog = NULL;

	/* Get shader source. */
	glGetShaderiv(*shader, GL_SHADER_SOURCE_LENGTH, &len);

	debugSource = malloc(len);

	glGetShaderSource(*shader, len, NULL, debugSource);

	printf("Debug source START:\n%s\nDebug source END\n\n", debugSource);
	free(debugSource);

	/* Now get the info log. */
	glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &len);

	errorLog = malloc(len);

	glGetShaderInfoLog(*shader, len, NULL, errorLog);

	printf("Log START:\n%s\nLog END\n\n", errorLog);
	free(errorLog);
#endif
	return 1;
    }
    return 0;
}

