#include "dos.h"


RETDW ftell(FILEH fh)
{
	if (supportDos2())
		return dos2_ftell(fh);
	else
		return dos1_ftell();
}
