#include "dos.h"


RETW fread(char* buf, uint16_t size, FILEH fh)
{
	if (supportDos2())
		return dos2_fread(buf, size, fh);
	else
		return dos1_fread(buf, size);
}
