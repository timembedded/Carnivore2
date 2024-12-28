#include <stdbool.h>
#include "dos.h"


bool fileexists(char *filename)
{
	if (supportDos2()) {
		FILEH fh = dos2_fopen(filename, O_RDONLY);
		if (fh >= ERR_FIRST) {
			return false;
		}
		dos2_fclose(fh);
		return true;
	}
	return dos1_fileexists(filename);
}
