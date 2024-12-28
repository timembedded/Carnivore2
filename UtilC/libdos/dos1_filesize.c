#include <stdbool.h>
#include "dos.h"


RETDW dos1_filesize(char *filename)
{
	RETDW size = -1;
	if (dos1_fopen(filename)) {
		size = ((FCB*)SYSFCB)->fileSize;
	}
	dos_initializeFCB();
	return size;
}
