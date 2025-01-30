#pragma once

#define JOYSTICK_XBOX360

#ifdef JOYSTICK_XBOX360
enum {
    JOYBUT_A,
    JOYBUT_B,
    JOYBUT_X,
    JOYBUT_Y,
    JOYBUT_LTRIGGER,
    JOYBUT_RTRIGGER,
    JOYBUT_BACK,
    JOYBUT_START,
    JOYBUT_HOME,
    JOYBUT_LAXISBUTTON,
    JOYBUT_RAXISBUTTON,
};
#else
enum {
    JOYBUT_TRIANGLE,
    JOYBUT_CIRCLE,
    JOYBUT_CROSS,
    JOYBUT_SQUARE,
    JOYBUT_LTRIGGER,
    JOYBUT_RTRIGGER,
    JOYBUT_DOWN,
    JOYBUT_LEFT,
    JOYBUT_UP,
    JOYBUT_RIGHT,
    JOYBUT_SELECT,
    JOYBUT_START,
    JOYBUT_HOME,
    JOYBUT_HOLD
};
#endif
