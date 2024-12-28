#include "dos.h"


inline RETDW dos1_ftell(void)
{
	return ((FCB*)SYSFCB)->rndRecord;
}