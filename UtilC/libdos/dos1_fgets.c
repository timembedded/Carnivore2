#include "dos.h"


char* dos1_fgets(char *str, uint16_t size)
{
	char *p = str;
	uint16_t ret;

	while (--size) {
		ret = dos1_fread(p, 1);
		if (*p++ == '\n') break;
		if (ret == 0xffc7) break;	// ERR_EOF
	}
	*p = '\0';
	return str;
}
