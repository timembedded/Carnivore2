#pragma once

#include <stdint.h>
#include <limits.h>

//typedef enum {FALSE=0, TRUE=1} BOOLEAN;

typedef int8_t   CHAR;
typedef uint8_t  UCHAR;
typedef int8_t   BYTE;
typedef uint8_t  UBYTE;

typedef int16_t  WORD;
typedef uint16_t UWORD;
typedef int16_t  INT;
typedef uint16_t UINT;

typedef int32_t  DWORD;
typedef uint32_t UDWORD;
typedef int32_t  LONG;
typedef uint32_t ULONG;

#ifndef uint
typedef unsigned int uint;
#endif

#ifndef byte
typedef unsigned char byte;
#endif

#ifndef ulong
typedef unsigned long ulong;
#endif

#ifndef bool
typedef unsigned char bool;
#endif

#ifndef false
#define false (0)
#endif

#ifndef true
#define true (!(false))
#endif

#ifndef null
#define null ((void*)0)
#endif

