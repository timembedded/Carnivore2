#include <string.h>
#include "dos.h"


/**
 * Writes a string to the current output FCB file.
 *
 * @param str The null-terminated string to be written.
 * @return The number of characters written, or -1 if an error occurred.
 */
RETW fputs(char *str, FILEH fh)
{
	uint16_t size = strlen(str);
	if (supportDos2())
		return dos2_fwrite(str, size, fh);
	else
		return dos1_fwrite(str, size);
}
