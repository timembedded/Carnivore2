/* Carnivore2 Cartridge's ROM->RAM Loader
   Reverse-engineered from original c2ramldr tool
   Original tool is made by RBSC
   Reversed engineered by Tim Brugman (SHS)
*/

/* Includes */

#include <stdint.h>
#include <ctype.h>  // toupper
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dos.h>
#include <printf.h>

#include <msxBIOS.h>
#include <msxDOS.h>

#include <textmode_MSX.h>

/* Defines */

/* System-RAM definitions */
#define SCR0WID    ((uint8_t *)0xF3AE)     // Screen0 width
#define CURSF      ((uint8_t *)0xFCA9)
#define TPASLOT1   ((uint8_t *)0xF342)
#define TPASLOT2   ((uint8_t *)0xF343)
#define CSRY       ((uint8_t *)0xF3DC)
#define CSRX       ((uint8_t *)0xF3DD)
#define ARG        ((uint8_t *)0xF847)
#define EXTBIO     ((uint8_t *)0xFFCA)
#define MNROM      ((uint8_t *)0xFCC1)     // Main-ROM Slot number & Secondary slot flags table

#define CardMDR    ((uint8_t *)0x4F80)
#define AddrM0     ((uint8_t *)(0x4F80+1))
#define AddrM1     ((uint8_t *)(0x4F80+2))
#define AddrM2     ((uint8_t *)(0x4F80+3))
#define DatM0      ((uint8_t *)(0x4F80+4))

#define AddrFR     ((uint8_t *)(0x4F80+5))

#define R1Mask     ((uint8_t *)(0x4F80+6))
#define R1Addr     ((uint8_t *)(0x4F80+7))
#define R1Reg      ((uint8_t *)(0x4F80+8))
#define R1Mult     ((uint8_t *)(0x4F80+9))
#define B1MaskR    ((uint8_t *)(0x4F80+10))
#define B1AdrD     ((uint8_t *)(0x4F80+11))

#define R2Mask     ((uint8_t *)(0x4F80+12))
#define R2Addr     ((uint8_t *)(0x4F80+13))
#define R2Reg      ((uint8_t *)(0x4F80+14))
#define R2Mult     ((uint8_t *)(0x4F80+15))
#define B2MaskR    ((uint8_t *)(0x4F80+16))
#define B2AdrD     ((uint8_t *)(0x4F80+17))

#define R3Mask     ((uint8_t *)(0x4F80+18))
#define R3Addr     ((uint8_t *)(0x4F80+19))
#define R3Reg      ((uint8_t *)(0x4F80+20))
#define R3Mult     ((uint8_t *)(0x4F80+21))
#define B3MaskR    ((uint8_t *)(0x4F80+22))
#define B3AdrD     ((uint8_t *)(0x4F80+23))

#define R4Mask     ((uint8_t *)(0x4F80+24))
#define R4Addr     ((uint8_t *)(0x4F80+25))
#define R4Reg      ((uint8_t *)(0x4F80+26))
#define R4Mult     ((uint8_t *)(0x4F80+27))
#define B4MaskR    ((uint8_t *)(0x4F80+28))
#define B4AdrD     ((uint8_t *)(0x4F80+29))

#define MConf      ((uint8_t *)(0x4F80+30))


/* Global variables */
static uint8_t ERMSlt;

#define TEST_ARGUMENTS 0

uint8_t /* A */ SlotPeek(uint8_t slot /* A */, const void *addr /* DE */) __naked
{
__asm

  push  ix
  ex    de,hl
  ld    iy,(0xFCC0)
  ld    ix,#0x0C  // RDSLT
  call  0x1C      // CALSLT
  pop   ix
  ret

__endasm;
}

void SlotPoke(uint8_t slot /* A */, const void *reg /* DE */, uint8_t value /* (SP+2) */) __naked
{
__asm

  ld    iy,#2
  add   iy,sp
  push  ix
  ld    l,(iy)
  ex    de,hl
  ld    iy,(0xFCC0)
  ld    ix,#0x14  // WRSLT
  call  0x1C      // CALSLT
  pop   ix
  pop   hl
  inc   sp
  jp    (hl)

__endasm;
}

void SlotEnable(uint8_t slot /* A */, uint8_t baseh /* L - 0/0x40/0x80/0xc0 */) __naked
{
__asm

  push  ix
  ld    h,l
  ld    iy,(0xFCC0)
  ld    ix,#0x24  // ENASLT
  call  0x1C      // CALSLT
  pop   ix
  ret

__endasm;
}

void reset(void) __naked
{
__asm

  ld    iy,(0xFCC0)
  ld    ix,#0
  jp    0x1C

__endasm;
}

static inline uint8_t MapRegRead(const void *reg)
{
    return SlotPeek(ERMSlt, reg);
}

static inline void MapRegWrite(const void *reg, uint8_t value)
{
    SlotPoke(ERMSlt, reg, value);
}

static inline void MapRegWriteBuf(const void *reg, uint8_t *buf, uint8_t len)
{
    while (len--) {
        SlotPoke(ERMSlt, reg, *buf++);
        reg = (uint8_t*)reg + 1;
    }
}

static char hex(uint8_t a)
{
    return (a > 9)? 'A'+a-10 : '0'+a;
}

bool TestSlot(uint8_t slot)
{
    const void *reg = (void*)0x4000;
    uint8_t save = SlotPeek(slot, reg);
    SlotPoke(slot, reg, 'c');
    SlotPoke(slot, reg, 'v');
    SlotPoke(slot, reg, '2');
    bool found = (SlotPeek(slot, reg) == 'C' &&
                  SlotPeek(slot, reg) == 'V' &&
                  SlotPeek(slot, reg) == '2');
    SlotPoke(slot, reg, save);
    return found;
}

bool FindSlot()
{
    for (int8_t pri = 3; pri >= 0; pri--) {
        uint8_t slot = MNROM[pri] | pri;
        if (slot & 0x80) {
            /* expanded slot */
            for (uint8_t sec = 0; sec < 4; sec++) {
                uint8_t xslot = slot | (sec << 2);
                if (TestSlot(xslot)) {
                    ERMSlt = xslot;
                    return true;
                }
            }
        }else{
            /* primary slot */
            if (TestSlot(pri)) {
                ERMSlt = pri;
                return true;
            }
        }
    }
    return false;
}

static bool WriteToRAM(uint8_t EBlock, uint8_t PreBnk, uint8_t *src)
{
    MapRegWrite(R2Reg, PreBnk);
    MapRegWrite(AddrFR, EBlock);

    SlotEnable(ERMSlt, 0x80);

    // check writable
    uint8_t *ptr = (uint8_t *)0x8000;
    bool ok = true;
    *ptr = 0xaa;
    if (*ptr != 0xaa)
        ok = false;
    *ptr = 0x55;
    if (*ptr != 0x55)
        ok = false;

    if (ok) {
        memcpy(ptr, src, 0x2000);
    }

    SlotEnable(*TPASLOT2, 0x80);

    return ok;
}

static void hexout(uint8_t hex)
{
    char c;
    c = (hex >> 4) + '0';
    if (c > '9')
        c += 7;
    putchar(c);
    c = (hex & 15) + '0';
    if (c > '9')
        c += 7;
    putchar(c);
}

static bool flag_help;
static bool flag_verbose;
static char flag_mapper;
static bool flag_noprotect;
static bool flag_primary;
static bool flag_nomemorymapper;
static bool flag_nocconfirm;
static bool flag_noreset;
static bool rcp_loaded = false;
static char rcp_file[256];
static uint8_t rcp_data[30];
static uint8_t record[64];
static uint8_t *block_buffer = (uint8_t *)0x6000;
static uint8_t B2ON[6] = { 0xF0, 0x70, 0x01, 0x15, 0x7F, 0x80 };
static uint8_t SRSize;

typedef struct {
    char identifier;
    char name[34];
    uint8_t bank0[6];
    uint8_t bank1[6];
    uint8_t bank2[6];
    uint8_t bank3[6];
    uint8_t settings[5];
} cardtab_item_t;

static cardtab_item_t cardtab[6] = {
    {
        'U', "Unknown mapper type",
        {0xF8,0x50,0x00,0xA4,0xFF,0x40},
        {0xF8,0x70,0x01,0xA4,0xFF,0x60},
        {0xF8,0x90,0x02,0xA4,0xFF,0x80},
        {0xF8,0xB0,0x03,0xA4,0xFF,0xA0},
        {0xFF,0xBC,0x00,0x02,0xFF},
    },{
        'k', "Konami (Konami 4)",
        {0xF8,0x50,0x00,0x24,0xFF,0x40},
        {0xF8,0x60,0x01,0xA4,0xFF,0x60},
        {0xF8,0x80,0x02,0xA4,0xFF,0x80},
        {0xF8,0xA0,0x03,0xA4,0xFF,0xA0},
        {0xFF,0xAC,0x00,0x02,0xFF},
    },{
        'K', "Konami SCC (Konami 5)",
        {0xF8,0x50,0x00,0xA4,0xFF,0x40},
        {0xF8,0x70,0x01,0xA4,0xFF,0x60},
        {0xF8,0x90,0x02,0xA4,0xFF,0x80},
        {0xF8,0xB0,0x03,0xA4,0xFF,0xA0},
        {0xFF,0xBC,0x00,0x02,0xFF},
    },{
        'a', "ASCII 8",
        {0xF8,0x60,0x00,0xA4,0xFF,0x40},
        {0xF8,0x68,0x00,0xA4,0xFF,0x60},
        {0xF8,0x70,0x00,0xA4,0xFF,0x80},
        {0xF8,0x78,0x00,0xA4,0xFF,0xA0},
        {0xFF,0xAC,0x00,0x02,0xFF},
    },{
        'A', "ASCII 16",
        {0xF8,0x60,0x00,0xA5,0xFF,0x40},
        {0xF8,0x70,0x00,0xA5,0xFF,0x80},
        {0xF8,0x60,0x00,0xA5,0xFF,0xC0},
        {0xF8,0x70,0x00,0xA5,0xFF,0x00},
        {0xFF,0x8C,0x00,0x01,0xFF},
    },{
        'M', "Mini ROM (without mapper)",
        {0xF8,0x60,0x00,0x26,0x7F,0x40},
        {0xF8,0x70,0x01,0x28,0x7F,0x80},
        {0xF8,0x70,0x02,0x28,0x3F,0xC0},
        {0xF8,0x78,0x03,0x28,0x3F,0xA0},
        {0xFF,0x8C,0x07,0x01,0xFF},
    }
};

void SelectMapper(uint8_t dmap)
{
    cardtab_item_t *map = &cardtab[dmap];
    record[4] = map->identifier;
    memcpy(&record[0x23], &map->bank0, sizeof(map->bank0) + sizeof(map->bank1) +
           sizeof(map->bank2) + sizeof(map->bank3) + sizeof(map->settings));
    printf("\r\nThe ROM's mapper type is set to: %s\r\n", map->name);
}

typedef struct {
    uint8_t jt;
    uint8_t ji;
} jt_ji_t;

void TestROM(jt_ji_t *id)
{
    // Enable ROM in page 2
    SlotEnable(ERMSlt, 0x80);

    // Pointer to ROM
    uint8_t *p = (uint8_t *)0x8000;

    if (p[0] == 'A' && p[1] == 'B') {
        id->jt |= 0x40;
    }
    if (p[0] == 'C' && p[1] == 'D') {
        id->jt |= 0x80;
    }

    if (id->jt) {
        uint8_t v = 0;
        for(uint8_t i = 0; i < 8; i += 2) {
            v >>= 1;
            if (p[i+2] || p[i+3]) {
                v |= 0x80;
            }
        }
        v >>= 4;
        id->jt |= v;

        if (v) {
            if (v & 0x01) {
                id->ji = p[3];
            }else
            if (v & 0x02) {
                id->ji = p[5];
            }else
            if (v & 0x04) {
                id->ji = p[7];
            }else{
                id->ji = p[9];
            }
        }
    }

    // Restore RAM in page 2
    SlotEnable(*TPASLOT2, 0x80);
}

bool DetectMapper(void)
{
    // Mapper types Singature
    // Konami:
    //    LD    (#6000),a
    //    LD    (#8000),a
    //    LD    (#a000),a
    //
    //    Konami SCC:
    //    LD    (#5000),a
    //    LD    (#7000),a
    //    LD    (#9000),a
    //    LD    (#b000),a
    //
    //    ASCII8:
    //    LD    (#6000),a
    //    LD    (#6800),a
    //    LD    (#7000),a
    //    LD    (#7800),a
    //
    //    ASCII16:
    //    LD    (#6000),a
    //    LD    (#7000),a
    //
    //    32 00 XX
    //
    //    For Konami games is easy since they always use the same register addresses.
    //
    //    But ASC8 and ASC16 is more difficult because each game uses its own addresses and instructions to access them.
    //    I.e.:
    //    LD    HL,#68FF 2A FF 68
    //    LD    (HL),A   77
    //
    //    BIT E 76543210
    //          !!!!!!!. 5000h
    //          !!!!!!.- 6000h
    //          !!!!!.-- 6800h
    //          !!!!.--- 7000h
    //          !!!.---- 7800h
    //          !!.----- 8000h
    //          !.------ 9000h
    //          .------- A000h
    //    BIT D 76543210
    //                 . B000h

    // ROM identification
    jt_ji_t id[3];
    memset(id, 0, sizeof(id));

    // Test page 0 of ROM
    MapRegWrite(AddrFR, 4);
    MapRegWrite(R2Reg, 0);
    TestROM(&id[0]);

    // Test page 1 of ROM
    if (SRSize == 0 || SRSize >= 6) {
        MapRegWrite(R2Reg, 2);
         TestROM(&id[1]);

        // Test page 2 of ROM
        if (SRSize == 0 || SRSize >= 7) {
            MapRegWrite(R2Reg, 4);
            TestROM(&id[2]);
        }
    }

    if (flag_verbose) {
        print("ROM's descriptor table:\r\n");
        hexout(id[0].jt);
        putchar(' ');
        hexout(id[1].jt);
        putchar(' ');
        hexout(id[2].jt);
        print("\r\n");
        hexout(id[0].ji);
        putchar(' ');
        hexout(id[1].ji);
        putchar(' ');
        hexout(id[2].ji);
        print("\r\n");
    }

    uint8_t DMAP = 0;
    if (SRSize != 0 && SRSize < 7) {
        /* MiniROM */
        DMAP = 5;
    }else{
        /* MapperROM or ROM > 32kB */
        SRSize = 0;
        // DTMAP
        print("Detecting ROM's mapper type ... ");
    }

    // Enable ROM in page 2
    SlotEnable(ERMSlt, 0x80);

    // Search 4 pages of 8kB
    uint16_t BMAP = 0;
    while (DMAP == 0) {
        for (uint8_t i = 0; i < 4; i++) {
            if (BMAP & 0x8000) {
                // 2nd 32kb
                MapRegWrite(R2Reg, i+4);
            }else{
                // First 32kB
                MapRegWrite(R2Reg, i);
            }

            for(uint8_t *p = (uint8_t *)0x8000; p != (uint8_t *)0xA000-3; p++) {
                if (p[0] == 0x2A) {
                    if (p[1] != 0xFF)
                        continue;
                    if (p[3] != 0x77)
                        continue;
                    switch (p[2]) {
                        case 0x60:
                            BMAP |= 0x02;
                            continue;
                        case 0x68:
                            BMAP |= 0x04;
                            continue;
                        case 0x70:
                            BMAP |= 0x08;
                            continue;
                        case 0x78:
                            BMAP |= 0x10;
                            continue;
                    }
                }
                if (p[0] == 0x32) {
                    if (p[1] != 0x00)
                        continue;
                    switch (p[2]) {
                        //  Bug: For some reason the original tool does not recognize this sequence (for example in PACMANIA.ROM),
                        //  there is no combination that includes this bit, so the matching depends on this bug. Diable the code here
                        //  to match the original behavior
                        //case 0x50:
                        //    BMAP |= 0x01;
                        //    continue;
                        case 0x60:
                            BMAP |= 0x02;
                            continue;
                        case 0x68:
                            BMAP |= 0x04;
                            continue;
                        case 0x70:
                            BMAP |= 0x08;
                            continue;
                        case 0x78:
                            BMAP |= 0x10;
                            continue;
                        case 0x80:
                            BMAP |= 0x20;
                            continue;
                        case 0x90:
                            BMAP |= 0x40;
                            continue;
                        case 0xA0:
                            BMAP |= 0x80;
                            continue;
                        case 0xB0:
                            BMAP |= 0x100;
                            continue;
                    }
                }
            }
        }

        if (flag_verbose) {
            hexout(BMAP >> 8);
            hexout(BMAP & 0xff);
            putchar(' ');
        }

        // BMAP bit 876543210
        //          !!!!!!!!!. 5000h
        //          !!!!!!!!.- 6000h
        //          !!!!!!!.-- 6800h
        //          !!!!!!.--- 7000h
        //          !!!!!.---- 7800h
        //          !!!!.----- 8000h
        //          !!!.------ 9000h
        //          !!.------- A000h
        //          !.-------- B000h

        if (BMAP & 0x100) {
            // Konami 5
            DMAP = 2;
        }else{
            switch(BMAP & 0xFF) {
                case 0x0A:
                    // ASCII 16
                    DMAP = 4;
                    break;
                case 0xA2: /* Konami 4 */
                case 0xA0: /* Aleste */
                case 0x22: /* 6000h 8000h */
                case 0x20: /* 8000h */
                    // Konami 4
                    DMAP = 1;
                    break;
                case 0x1E: /* 6000h,6800h,7000h,8700h */
                case 0x1C:
                case 0x18:
                    // ASCII 8
                    DMAP = 3;
                    break;
            }
        }

        if (SRSize != 0 && SRSize <= 6 /* <= 32kB */) {
            switch(BMAP & 0xFF) {
                case 0x02: /* ZanacEX */
                case 0x08:
                case 0x48:
                    // ASCII 16
                    DMAP = 4;
                    break;
                case 0x0E:
                case 0x04:
                case 0x20:
                    // ASCII 8
                    DMAP = 3;
                    break;
            }
        }

        if (DMAP == 0) {
            if (BMAP & 0x8000) {
                // Also not found the 2nd search
                break;
            }
            // Not found the first attempt, try 2nd 32kB
            BMAP |= 0x8000; // 2nd search bit
        }
    }

    // Restore RAM in page 2
    SlotEnable(*TPASLOT2, 0x80);

    if (DMAP == 0) {
        if (SRSize == 0) {
            printf("\r\nUnable to detect mapper type\r\n");
            return false;
        }
        printf("\r\nAssuming MiniROM\r\n");
        DMAP = 5;
        SRSize = 0;
    }

    // Save MAP config to Record form
    SelectMapper(DMAP);

    if (DMAP == 5) {
        // MiniROM

        // Default base address for bank 0
        record[0x28] = id[0].ji & 0xc0; // Bank 0 - addr

        if (SRSize < 6) {
            if (SRSize < 5) {
                // =< 8kB
                record[0x26] = 0xA4;    // Bank 0 - Size 8kB, no Ch.reg
            }else{
                // =< 16kB
                record[0x26] = 0xA5;    // Bank 0 - Size 16kB, no Ch.reg
            }
            record[0x2C] = 0xAD;    // Bank 1 - off
            record[0x32] = 0xAD;    // Bank 2 - off
            record[0x38] = 0xAD;    // Bank 3 - off
        }else
        if (SRSize < 7) {
            // =< 32kB
            record[0x26] = 0xA5;    // Bank 0 - Size 16kB, no Ch.reg
            record[0x2C] = 0xA5;    // Bank 1 - Size 16kB, no Ch.reg
            record[0x32] = 0xAD;    // Bank 2 - off
            record[0x38] = 0xAD;    // Bank 3 - off

            if (id[0].jt != 0 &&
               (id[0].ji & 0xc0) == 0x80) {
                record[0x28] = 0x80; // Bank 0 - addr
                record[0x2E] = 0xC0; // Bank 1 - addr
            }
        }else
        if (SRSize == 7) {
            // 64 kB ROM
            record[0x26] = 0xA7;    // Bank 0 - Size 64kB, no Ch.reg
            record[0x2C] = 0xAD;    // Bank 1 - off
            record[0x32] = 0xAD;    // Bank 2 - off
            record[0x38] = 0xAD;    // Bank 3 - off
            record[0x28] = 0x00;    // Bank 0 - addr = 0
        }else{
            // 48kB ROM
            record[0x26] = 0xA5;    // Bank 0 - Size 16kB, no Ch.reg
            record[0x2C] = 0xA5;    // Bank 1 - Size 16kB, no Ch.reg
            record[0x32] = 0xA5;    // Bank 2 - Size 16kB, no Ch.reg
            record[0x38] = 0xAD;    // Bank 3 - off
            record[0x2B] = 1;       // correction for bank 1

            if (id[0].jt == 0) {
                if (id[1].jt == 0) {
                    if (id[2].jt == 0) {
                        record[0x28] = 0x00; // Bank 0 - addr
                        record[0x2E] = 0x80; // Bank 1 - addr
                    }
                }else
                if ((id[1].ji & 0xc0) == 0x40) {
                    record[0x28] = 0x00; // Bank 0 - addr
                    record[0x2E] = 0x40; // Bank 1 - addr
                    record[0x34] = 0x80; // Bank 2 - addr
                }
            }else{
                if ((id[0].ji & 0xc0) == 0) {
                    record[0x28] = 0x00; // Bank 0 - addr
                    record[0x2E] = 0x40; // Bank 1 - addr
                    record[0x34] = 0x80; // Bank 2 - addr
                }
            }
        }

        // label Csm05
        record[0x3D] = SRSize;

        if (flag_verbose) {
            print("MMROM-CSRM: ");
            hexout(record[0x3D]);
            putchar('-');
            hexout(record[0x26]);
            putchar('-');
            hexout(record[0x2C]);
            putchar('-');
            hexout(record[0x32]);
            putchar('-');
            hexout(record[0x38]);
            print("\r\n");
        }
    }

    return true;
}

int main(char** argv, int argc)
{
    char *filename = NULL;

    print("Carnivore2 MultiFunctional Cartridge RAM Loader v2.00\r\n"
          "(C) 2015-2024 RBSC/SHS. All rights reserved\r\n\r\n");

#if TEST_ARGUMENTS
    uint8_t dosver = dosVersion();
    printf("arguments: %d, dosver: %d\r\n", argc, dosver);
    for(uint8_t i = 0; i < (uint8_t)argc; i++) {
        printf("%d: [%s]\r\n", i, argv[i]);
    }
#endif

    for(uint8_t i = 0; i < (uint8_t)argc; i++) {
        char *arg = argv[i];
        if (arg[0] == '/' || arg[0] == '-') {
            switch(toupper(arg[1])) {
                case 'H':
                    flag_help = true;
                    break;
                case 'V':
                    flag_verbose = true;
                    break;
                case 'M':
                    if (arg[2] < '1' || arg[2] > '4') {
                        print("Invalid mapper type\r\n");
                        return 1;
                    }
                    flag_mapper = arg[2] - '0';
                    break;
                case 'W':
                    flag_noprotect = true;
                    break;
                case 'P':
                    flag_primary = true;
                    break;
                case 'N':
                    flag_nomemorymapper = true;
                    break;
                case 'A':
                    flag_nocconfirm = true;
                    break;
                case 'R':
                    flag_noreset = true;
                    break;
                default:
                    printf("Invalid parameter: %c%c\r\n", arg[0], arg[1]);
                    return 1;
            }
        }else{
            filename = arg;
        }
    }

    if (!filename) {
        print(
            "Usage:\r\n\n"
            " c2ramldr [filename.rom] [/h] [/v] [/mN] [/a] [/p] [/r]\r\n\n"
            "Command line options:\r\n"
            " /h  - this help screen\r\n"
            " /v  - verbose mode (show detailed information)\r\n"
            " /m[1..4] - mapper select\r\n"
            "   (1 = Konami 4, 2 = Konami 5 SCC, 3 = ASCII 8, 4 = ASCII 16)\r\n"
            " /p  - run in primary slot (disables RAM, FM-PAC and CompatFlash)\r\n"
            " /n  - run with memory mapper disabled\r\n"
            " /w  - writable, switch RAM protection off after copying the ROM\r\n"
            " /a  - do not ask configrmation (no user interaction)\r\n"
            " /r  - do not restart the computer after uploading the ROM\r\n"
        );
        return 0;
    }

    // Find the cartridge
    if (!FindSlot()) {
        print("Carnivore2 cartridge was not found\r\n");
        return 1;
    }
    printf("Found Carnivore2 cartridge in slot(s): %c%c\r\n",
           '0'+(ERMSlt & 3), (ERMSlt & 0x80)? '0'+((ERMSlt & 0x0C) >> 2) : ' ');

    // Load RCP-file if available
    strcpy(rcp_file, filename);
    uint8_t flen = strlen(rcp_file);
    while (flen--) {
        if (rcp_file[flen] == '.') {
            strcpy(&rcp_file[flen], ".RCP");
            break;
        }
    }
    FILEH fh = fopen(rcp_file, O_RDONLY);
    if (fh < ERR_FIRST) {
        if (flag_verbose) {
            printf("Autodetection ignored, using data from RCP file %s\r\n", rcp_file);
        }
        if (!fread(rcp_data, sizeof(rcp_data), fh)) {
            print("File read error!\r\n");
            return 1;
        }
        rcp_loaded = true;
        fclose(fh);

        // Patch RCP data
        rcp_data[0x04] |= 0x20;
        rcp_data[0x0A] |= 0x20;
        rcp_data[0x10] |= 0x20;
        rcp_data[0x16] |= 0x20;
    }

    // Open ROM file
    printf("\r\nOpening file: %s\r\n", filename);
    int32_t rom_size = filesize(filename);
    if (rom_size < 0) {
        print("File not found!\r\n");
        return 1;
    }
    fh = fopen(filename, O_RDONLY);
    if (fh >= ERR_FIRST) {
        print("Could not open ROM file!\r\n");
        return 1;
    }
    if (flag_verbose) {
        print("File size (hexadecimal): ");
        hexout((rom_size >> 24) & 0xff);
        hexout((rom_size >> 16) & 0xff);
        hexout((rom_size >> 8) & 0xff);
        hexout(rom_size & 0xff);
        print("\r\n");
    }

    // Enable bank 2
    MapRegWrite(MConf, MapRegRead(MConf)); // overwrite any pending configuration change
    MapRegWrite(CardMDR, 0x20); // immediate changes enabled
    MapRegWriteBuf(CardMDR + 12, B2ON, sizeof(B2ON)); // enable bank 2

    // calc blocks len
    uint16_t blocks64k = (rom_size >> 16);
    if (blocks64k >= 12) {
        print("File is too big to be loaded into the cartridge's RAM!\r\n"
              "You can only upload ROM files up to 720kb into RAM.\r\n"
              "Please select another file...\r\n");
        return 1;
    }
    record[3] = blocks64k & 0xff;

    record[2] = 4; // start from 4th block in RAM
    record[1] = 0xff; // set active flag

    // SRSize
    const char *maptxt;
    if (rom_size <= 8*1024L) {
        maptxt = "8kB or less";
        SRSize = 4; /* <= 8 kB */
    }else
    if (rom_size <= 16*1024L) {
        maptxt = "16kB";
        SRSize = 5; /* <= 16 kB */
    }else
    if (rom_size <= 32*1024L) {
        maptxt = "32kB";
        SRSize = 6; /* <= 32 kB */
    }else
    if (rom_size <= 48*1024L) {
        maptxt = "48kB";
        SRSize = 14; /* <= 48 kB */
    }else
    if ((rom_size >> 16) == 0) {
        maptxt = "64kB";
        SRSize = 7; /* <= 64 kB */
    }else{
        maptxt = ">64kB (mapper is required)";
        SRSize = 0;
    }
    if (flag_verbose) {
        printf("ROM's file size: %s\r\n", maptxt);
    }

    // LoadImage
    // ---------

    // Configure mapper
    MapRegWrite(R2Mult, 0x34); // Bank 2: RAM instead of ROM, Bank write enabled, 8kb pages, control off

    // loading ROM-image to RAM

    uint8_t EBlock = record[2]; // start block (absolute block 64kB), 4 for RAM/Flash
    MapRegWrite(AddrFR, EBlock);

    print("Writing ROM image, please wait...\r\n");

    // calc loading cycles
    uint16_t blocks8k = (rom_size >> 13);
    uint16_t lastsize = 0x2000;
    if (rom_size & 0x1fff) {
        lastsize = rom_size & 0x1fff;
        blocks8k++;
    }

    uint8_t PreBnk = 0;              // no shift for the first block
    while(blocks8k--) {
        // load portion from file
        if (!fread(block_buffer, blocks8k? 0x2000 : lastsize, fh)) {
            print("\r\nFile read error!\r\n");
            return 1;
        }
        if (blocks8k == 0 && lastsize != 0x2000) {
            memset(block_buffer + lastsize, 0xFF, 0x2000 - lastsize);
        }

        if (!WriteToRAM(EBlock, PreBnk, block_buffer)) {
            print("\r\nFailed to write to mapper\r\n");
            return 1;
        }

        if (++PreBnk == 8) {
            PreBnk = 0;
            EBlock++;
        }

        putchar('>');
    }
    print("\r\n");

    fclose(fh);

    print("\r\nThe ROM image was successfully written into cartridge's RAM!\r\n");

    // Select mapper type
    if (flag_mapper) {
        rcp_loaded = false; // forced mapper type, ignore rcp
        SelectMapper(flag_mapper);
    }else
    if (!rcp_loaded) {
        if (!DetectMapper()) {
            return 1;
        }
    }

    // Copy RCP to record
    if (rcp_loaded) {
        record[4] = rcp_data[0];
        memcpy(&record[0x23], &rcp_data[1], 29);
    }

    // Remove write-protect if requested
    if (flag_noprotect) {
        record[0x23 + 0*6 + 3 /* R0Mult */] |= 0x10;
        record[0x23 + 1*6 + 3 /* R1Mult */] |= 0x10;
        record[0x23 + 2*6 + 3 /* R2Mult */] |= 0x10;
        record[0x23 + 3*6 + 3 /* R3Mult */] |= 0x10;
    }

    // Primary option
    if (flag_primary) {
        print("Game will run in primary slot\r\n");
        record[0x3B /* MConf */] = 0x21; // Only enable YM2413 chip, SCC and ROM in primary slot
    }else
    // No memory mapper option
    if (flag_nomemorymapper) {
        print("Game will with memory mapper disabled\r\n");
        record[0x3B /* MConf */] &= ~4; // Disable memory mapper
    }

    if (flag_verbose) {
        print("config: ");
        hexout(record[2]);
        for(uint8_t i = 0; i < 25; i++) {
            hexout(record[0x23+i]);
        }
        hexout(record[0x3C] | 0x89);
        print("\r\n");
    }

    // Configure mapper
    MapRegWrite(CardMDR, 0x38); // enable delayed reconfiguration
    MapRegWrite(AddrFR, record[2]); // set start block
    MapRegWriteBuf(R1Mask, &record[0x23], 25); // configure mapper banks (0x23 .. 0x3A)
    MapRegWrite(CardMDR, record[0x3C] | 0x89); // CardMDR from RCP; disable config register and enable delayed reconfiguration

    // Reset into game
    if (!flag_noreset) {
        print("\r\nYour MSX will reboot now ...\r\n");
        reset();
    }

    print("\r\nThe program will now exit\r\n");
    return 0;
}
