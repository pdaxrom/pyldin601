#include <stdio.h>

int main(int argc, char *argv[])
{
    int i;
    for (i = 0; i < 122880; i++) {
	printf("%c", 255);
    }

    return 0;
}
