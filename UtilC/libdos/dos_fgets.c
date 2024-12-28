#include "dos.h"


char* fgets(char *str, uint16_t size, FILEH fh)
{
	if (supportDos2())
		return dos2_fgets(str, size, fh);
	else {
		return dos1_fgets(str, size);
	}
}
