#include <stdbool.h>
#include "dos.h"


bool dos1_fileexists(char *filename)
{
	bool result = dos1_fopen(filename);
	dos_initializeFCB();
	return result;
}
