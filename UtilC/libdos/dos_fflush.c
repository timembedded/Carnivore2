#include "dos.h"


FILEH fflush(FILEH fh)
{
	if (supportDos2())
		return dos2_fflush(fh);
	else {
		return dos1_fflush();
	}
}
