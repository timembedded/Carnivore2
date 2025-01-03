#include "dos.h"

static RETB s_dos_version;

RETB supportDos2(void) __naked __sdcccall(1)
{
	__asm
		ld   a,(_s_dos_version)
		cp   #2
		jr   c,sd2l1$
		ld   a,#1
		ret         ; return 1 if dos2 or higher (Nextor)
	sd2l1$:
		or   a
		ld   a,#0
		ret  nz     ; return 0 if dos1
		; unknown, call dosVersion
		call _dosVersion
		cp   #2
		ld   a,#1
		ret  nc     ; return 1 if dos2 or higer (Nextor)
		xor  a
		ret         ; return 0 if dos1 or still unknown
	__endasm;
}

RETB dosVersion(void) __naked __sdcccall(1)
{
/*
    GET MSX-DOS VERSION NUMBER (6FH)
    Parameters:    C = 6FH (_DOSVER)
    Results:       A = Error (always zero)
                  BC = MSX-DOS kernel version
                  DE = MSXDOS2.SYS version number

This function allows a program to determine which version of MSX-DOS it is
running under. Two version numbers are returned, one in BC for the MSX-DOS
kernel in ROM and the other is DE for the MSXDOS2.SYS system file. Both of
these version numbers are BCD values with the major version number in the high
byte and the two digit version number in the low byte. For example if there
were a version 2.34 of the system, it would be represented as 0234h.

For compatibility with MSX-DOS 1.0, the following procedure should always be
followed in using this function. Firstly if there is any error (A<>0) then it
is not MSX-DOS at all. Next look at register B. If this is less than 2 then the
system is earlier than 2.00 and registers C and DE are undefined. If register B
is 2 or greater then registers BC and DE can be used as described above. In
general the version number which should be checked (after this procedure) is
the MSXDOS2.SYS version in register DE.

*** NEXTOR OS have additional functionality in this call ***
*/
	__asm
		ld   a,(_s_dos_version)
		or   a
		ret  nz

		push ix

		ld   b,  #0x5A		; magic numbers to detect Nextor
		ld   hl, #0x1234
		ld   de, #0xABCD
		ld   ix, #0

		ld   c,#DOSVER
		call 0xF37D			; BDOS (upper memory DOSCALL)

		or   a
		jr   z,check_dos1$
		xor  a				; A = VER_UNKNOWN (unknown DOS)
		jr   ret_version$

	check_dos1$:
		ld   a,b				; B<2 --> MSX-DOS 1
		cp   #2
		jr   nc,check_dos2nextor$
		ld   a,#VER_MSXDOS1x	; A = VER_MSXDOS1x (is MSX-DOS 1)
		jr   ret_version$

	check_dos2nextor$:
		push ix				; Nextor: IXh must contain '1'
		pop  hl
		ld   a,h
		dec  a
		jr   z,is_nextor$
		ld   a,#VER_MSXDOS2x	; A = VER_MSXDOS2x (is MSXDOS 2)
		jr   ret_version$

	is_nextor$:				; A = VER_NextorDOS (is NextorDOS)
		ld   a,#VER_NextorDOS

	ret_version$:
		ld   (_s_dos_version),a
		pop  ix
		ret					; Returns A
	__endasm;
}

