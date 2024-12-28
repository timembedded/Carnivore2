#include "dos.h"


inline bool dos1_fflush()
{
	return dos1_fclose();
}
