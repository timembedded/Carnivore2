#include "dos.h"


FILEH fopen(char *filename, char mode)
{
	if (supportDos2())
		return dos2_fopen(filename, mode);
	else
		return dos1_fopen(filename)? 0 : ERR_NOFIL;
}
