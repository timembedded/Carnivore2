#include "dos.h"


RETW fwrite(char* buf, uint16_t size, FILEH fh)
{
	if (supportDos2())
		return dos2_fwrite(buf, size, fh);
	else
		return dos1_fwrite(buf, size);
}
