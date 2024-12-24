/*
   Simplified printf and sprintf for SDCC+Z80
   (c) 2018 Konamiman - www.konamiman.com

   This version is about 1.5K smaller than the one contained
   in the z80 library supplied with SDCC

   To compile:
   sdcc -mz80 -c --disable-warning 85 --disable-warning 196 --max-allocs-per-node 100000 --allow-unsafe-read --opt-code-size printf.c

   Supported format specifiers:

   %d or %i: signed int
   %u: unsigned int
   %x: hexadecimal int
   %c: character
   %s: string
   %%: a % character

   Also if SUPPORT_LONG is defined:

   %l: signed long
   %lu: unsigned long
   %lx: hexadecimal long
*/
#pragma once

#include <stdio.h>

void print(char* s);
int printf_custom(const char *fmt, ...);
int sprintf_custom(const char* buf, const char* fmt, ...);

// replace standard printf
#undef printf
#define printf printf_custom
#undef sprintf
#define sprintf sprintf_custom
