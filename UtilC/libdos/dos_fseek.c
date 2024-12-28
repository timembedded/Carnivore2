#include "dos.h"


RETDW fseek(FILEH fh, uint32_t offset, uint8_t origin)
{
	if (supportDos2())
		return dos2_fseek(fh, offset, origin);
	else
		return dos1_fseek(offset, origin);
}
