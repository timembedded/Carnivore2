#include <string.h>
#include "dos.h"

RETW dos2_fputs(char *str, FILEH fh)
{
	uint16_t size = strlen(str);
	return dos2_fwrite(str, size, fh);
}