#include <stdbool.h>
#include "dos.h"


RETDW filesize(char *filename)
{
	if (supportDos2()) {
		RETDW size = -1;
		FILEH fh = dos2_fopen(filename, O_RDONLY);
		if (fh >= ERR_FIRST) {
			return -1;
		}
		size = dos2_fseek(fh, 0, SEEK_END);
		if (fh >= ERR_FIRST) {
			return -1;
		}
		dos2_fclose(fh);
		return size;
	}
	return dos1_filesize(filename);
}
