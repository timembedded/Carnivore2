#include "dos.h"


bool fcreate(char *filename, char mode, char attributes)
{
	if (supportDos2())
		return dos2_fcreate(filename, mode, attributes);
	else
		return dos1_fcreate(filename);
}
