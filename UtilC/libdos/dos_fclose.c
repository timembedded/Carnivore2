#include "dos.h"

bool fclose(FILEH fh)
{
	if (supportDos2())
		return dos2_fclose(fh);
	else
		return dos1_fclose();
}
