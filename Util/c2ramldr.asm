;
; Carnivore2 Cartridge's ROM->RAM Loader
; Copyright (c) 2015-2023 RBSC
; Version 1.40
;


; !COMPILATION OPTIONS!

SPC     equ     0               ; 1 = for Arabic and Korean computers
                                ; 0 = for all other MSX computers
; !COMPILATION OPTIONS!


;************************
;***                  ***
;***   MAIN PROGRAM   ***
;***                  ***
;************************

        org     #100                    ; Needed for programs running under MSX-DOS

        jp      PRGSTART

        include "lib/defs.inc"
        include "lib/flash.inc"
        include "lib/console.inc"
        include "lib/megamap.inc"
        include "lib/argparse.inc"

;------------------------
;---  Initialization  ---
;------------------------

PRGSTART:
; Set screen
        call    CLRSCR
        call    KEYOFF
;--- Checks the DOS version and sets DOS2 flag

        ld      c,_DOSVER
        call    DOS
        or      a
        jr      nz,PRTITLE
        ld      a,b
        cp      2
        jr      c,PRTITLE

        ld      a,#FF
        ld      (DOS2),a                ; #FF for DOS 2, 0 for DOS 1
;       print   USEDOS2_S               ; !!! Commented out by Alexey !!!

;--- Prints the title
PRTITLE:
        print   PRESENT_S

; Command line options processing
        ld      a,1
        call    F_Key                   ; C- no parameter; NZ- not flag; S(M)-ilegal flag
        jr      c,Stfp01
        jr      nz,Stfp07
        jp      p,Stfp02
Stfp03:
        print   I_FLAG_S
        jr      Stfp09
Stfp07:
        ld      a,1
        ld      (p1e),a                 ; File parameter exists!

Stfp02:
        ld      a,2
        call    F_Key
        jr      c,Stfp01
        jp      m,Stfp03
        jr      z,Stfp04
Stfp05:
        print   I_PAR_S
Stfp09:
        print   H_PAR_S
        jp      Exit
Stfp04:
        ld      a,3
        call    F_Key
        jr      c,Stfp01
        jp      m,Stfp03
        jr      nz,Stfp05
        ld      a,4
        call    F_Key
        jr      c,Stfp01
        jp      m,Stfp03
        jr      nz,Stfp05
        ld      a,5
        call    F_Key
        jr      c,Stfp01
        jp      m,Stfp03
        jr      nz,Stfp05
        print   I_MPAR_S
        jr      Stfp09
Stfp01:
        ld      a,(p1e)
        jr      nz,Stfp06               ; if not file parameter
        xor     a
        ld      (F_A),a                 ; Automatic flag not active
Stfp06:
        ld      a,(F_P)
        or      a
        jr      z,Stfp08
        ld      a,#FF

Stfp08: inc     a
        ld      (protect),a             ; set protection status

        ld      a,(F_H)
        or      a
        jr      nz,Stfp09

; mapper type
        ld      a,(F_M)
        or      a
        jr      z,Stfp10
        sub     "0"
        jr      z,Stfp09
        jr      c,Stfp09
        ld      b,a
        call    TTAB
        ld      a,(hl)
        or      a
        jr      z,Stfp09
        push    hl
        ; copy tp RCPData
        ld      de,RCPData
        ldi
        ld      bc,34
        add     hl,bc
        ld      bc,29
        ldir
        ; print selected map
        print   NoAnalyze
        pop     de
        inc     de
        ld      c,_STROUT
        call    DOS
        print   ONE_NL_S

Stfp10:
; Find used slot
        call    FindSlot
        jp      c,Exit
        call    Testslot
        jp      z,Stfp30

; print warning for incompatible or uninit cartridge and exit
        print   M_Wnvc
        jp      Exit

Stfp30:
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
        ld      a,(CardMod)             ; overwrite any pending configuration change
        ld      (CardMod),a
        ld      a,#20                   ; immediate changes enabled
        ld      (CardMDR),a
        ld      hl,B2ON
        ld      de,CardMDR+#0C          ; set Bank2
        ld      bc,6
        ldir

        ld      a,(p1e)
        or      a
        jr      z,MainM                 ; no file parameter

        ld      a,1
        ld      de,BUFFER
        call    EXTPAR
        jr      c,MainM                 ; No parameter

        ld      ix,BUFFER
        call    FnameP

        jp      ADD_OF                  ; continue loading ROM image


; Main menu
MainM:
        xor     a
        ld      (CURSF),a

        print   MAIN_S
Ma01:
        ld      a,1
        ld      (CURSF),a

        ld      c,_INNOE
        call    DOS

        push    af
        xor     a
        ld      (CURSF),a
        pop     af

        cp      27
        jp      z,Exit
        cp      "3"
        jr      z,DoReset
        cp      "0"
        jp      z,Exit
        cp      "1"
        jr      z,ADDimage
        cp      "2"
        jr      nz,Ma01
        xor     a
        jr      ADDimgR

DoReset:
; Restore slot configuration!
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT

        xor     a
        ld      (AddrFR),a
        ld      a,#38
        ld      (CardMDR),a
        ld      hl,RSTCFG
        ld      de,R1Mask
        ld      bc,26
        ldir

        in      a,(#F4)                 ; read from F4 port on MSX2+
        or      #80
        out     (#F4),a                 ; avoid "warm" reset on MSX2+

        rst     #30                     ; call to BIOS
   if SPC=0
        db      0
   else
        db      #80
   endif
        dw      0                       ; address

;
; ADD ROM image
;
ADDimage:
        ld      a,1
ADDimgR:
        ld      (protect),a

        print   ADD_RI_S
        ld      de,Bi_FNAM
        ld      c,_BUFIN
        call    DOS
        ld      a,(Bi_FNAM+1)
        or      a                       ; Empty input?
        jr      z,SelFile

        ld      c,a
        ld      b,0
        ld      hl,Bi_FNAM+2
        add     hl,bc
        ld      (hl),0

        ld      hl,Bi_FNAM+2
        ld      b,13
ADDIM1:
        ld      a,(hl)
        cp      '.'
        jr      z,ADDIM2
        or      a
        jr      z,ADDIMC
        inc     hl
        djnz    ADDIM1

ADDIMC:
        ex      de,hl
        ld      hl,ROMEXT               ; copy extension and zero in the end
        ld      bc,5
        ldir
        jr      ADDIM3

ADDIM2:
        inc     hl
        ld      a,(hl)
        or      a
        jr      z,ADDIM3
        cp      32                      ; empty extension?
        jr      c,ADDIMC

ADDIM3:
        ld      ix,Bi_FNAM+2
        call    FnameP
        jp      ADD_OF

SelFile:
        print   SelMode
        ld      c,_SDMA
        ld      de,BUFTOP
        call    DOS

SelFile0:
        ld      de,FCBROM
        ld      c,_FSEARCHF             ; Search First File
        call    DOS
        or      a
        jr      z,SelFile1              ; file found!
        print   NoMatch

        ld      a,(F_A)
        or      a
        jp      nz,Exit                 ; Automatic exit

        jp      MainM

SelFile1:
        ld      b,8
        ld      hl,BUFTOP+1
Sf1:    push    bc
        push    hl
        ld      e,(hl)
        ld      c,_CONOUT
        call    DOS
        pop     hl
        inc     hl
        pop     bc
        djnz    Sf1
        ld      e,"."
        ld      c,_CONOUT
        call    DOS
        ld      b,3
        ld      hl,BUFTOP+9
Sf2:    push    bc
        push    hl
        ld      e,(hl)
        ld      c,_CONOUT
        call    DOS
        pop     hl
        inc     hl
        pop     bc
        djnz    Sf2

Sf3:    ld      c,_INNOE
        call    DOS
        cp      13                      ; Enter? -> select file
        jr      z,Sf5
        cp      27                      ; ESC? -> exit
        jp      nz,Sf3z
        print   ONE_NL_S
        jp      MainM
Sf3z:
        cp      9                       ; Tab? -> next file
        jr      nz,Sf3

        ld      a,(F_V)                 ; verbose mode?
        or      a
        jr      nz,Sf3b

        ld      b,12
Sf3a:   push    bc
        ld      e,8
        ld      c,_CONOUT
        call    DOS                     ; Erase former file name with backspace
        pop     bc
        djnz    Sf3a
        jr      Sf4

Sf3b:   ld      e,9
        ld      c,_CONOUT
        call    DOS                     ;  Output a tab before new file

Sf4:
        ld      c,_FSEARCHN             ; Search Next File
        call    DOS
        or      a
        jp      nz,SelFile0             ; File not found? Start from beginning
        jp      SelFile1                ; Print next found file

Sf5:
        ld      de,Bi_FNAM+2
        ld      hl,BUFTOP+1
        ld      bc,8
        ldir
        ld      a,"."
        ld      (de),a
        inc     de
        ld      bc,3
        ldir                            ; copy selected file name
        xor     a
        ld      (de),a                  ; zero in the end of the file

        ld      ix,Bi_FNAM+2
        call    FnameP

ADD_OF:
;Open file
        ld      de,OpFile_S
        ld      c,_STROUT
        call    DOS

        ld      a,(FCB)
        or      a
        jr      z,opf1                  ; dp not print device letter
        add     a,#40                   ; 1 => "A:"
        ld      e,a
        ld      c,_CONOUT
        call    DOS
        ld      e,":"
        ld      c,_CONOUT
        call    DOS
opf1:   ld      b,8
        ld      hl,FCB+1
opf2:   push    bc
        push    hl
        ld      e,(hl)
        ld      c,_CONOUT
        call    DOS
        pop     hl
        inc     hl
        pop     bc
        djnz    opf2
        ld      e,"."
        ld      c,_CONOUT
        call    DOS
        ld      b,3
        ld      hl,FCB+9
opf3:   push    bc
        push    hl
        ld      e,(hl)
        ld      c,_CONOUT
        call    DOS
        pop     hl
        inc     hl
        pop     bc
        djnz    opf3
        print   ONE_NL_S

; load RCP file if exists
        ld      a,(RCPData)             ; check RCP data (is set when mapper type was specified)
        or      a
        jr      nz,usercp

        ld      hl,FCB
        ld      de,FCBRCP
        ld      bc,40
        ldir                            ; copy FCB
        ld      hl,RCPExt
        ld      de,FCBRCP+9
        ld      bc,3
        ldir                            ; change extension to .RCP

        ld      de,FCBRCP
        ld      c,_FOPEN
        call    DOS                     ; Open RCP file
        or      a
        jr      nz,opf4
        ld      hl,30
        ld      (FCBRCP+14),hl          ; Record size = 30 bytes

        ld      c,_SDMA
        ld      de,BUFTOP
        call    DOS

        ld      hl,1
        ld      c,_RBREAD
        ld      de,FCBRCP
        call    DOS                     ; read RCP file

        push    af
        push    hl
        ld      de,FCBRCP
        ld      c,_FCLOSE
        call    DOS                     ; close RCP file
        pop     hl
        pop     af
        or      a
        jr      nz,opf4
        ld      a,l
        cp      1                       ; 1 record (30 bytes) read?
        jr      nz,opf4

; RCP file is loaded, use it
        ld      hl,BUFTOP
        ld      de,RCPData
        ld      bc,30
        ldir                            ; copy read RCP data to its place
        print   UsingRCP
usercp:
        ld      hl,RCPData+#04
        ld      a,(hl)
        or      %00100000               ; for ROM use and %11011111
        ld      (hl),a                  ; set RAM as source
        ld      hl,RCPData+#0A
        ld      a,(hl)
        or      %00100000               ; for ROM use and %11011111
        ld      (hl),a                  ; set RAM as source
        ld      hl,RCPData+#10
        ld      a,(hl)
        or      %00100000               ; for ROM use and %11011111
        ld      (hl),a                  ; set RAM as source
        ld      hl,RCPData+#16
        ld      a,(hl)
        or      %00100000               ; for ROM use and %11011111
        ld      (hl),a                  ; set RAM as source

; ROM file open
opf4:
        ld      de,FCB
        ld      c,_FOPEN
        call    DOS                     ; Open file
        ld      hl,1
        ld      (FCB+14),hl             ; Record size = 1 byte
        or      a
        jr      z,Fpo

        ld      de,F_NOT_F_S
        ld      c,_STROUT
        call    DOS
        ld      a,(F_A)
        or      a
        jp      nz,Exit                 ; Automatic exit
        jp      MainM

Fpo:
; set DMA
        ld      c,_SDMA
        ld      de,BUFTOP
        call    DOS

; get file size
        ld      hl,FCB+#10
        ld      bc,4
        ld      de,Size
        ldir

; print ROM size in hex
        ld      a,(F_V)                 ; verbose mode?
        or      a
        jr      z,vrb00

        print   FileSZH                 ; print file size
        ld      a,(Size+3)
        call    HEXOUT
        ld      a,(Size+2)
        call    HEXOUT
        ld      a,(Size+1)
        call    HEXOUT
        ld      a,(Size)
        call    HEXOUT

        print   ONE_NL_S

vrb00:

; File size <= 32 κα ?
;       ld      a,(Size+3)
;       or      a
;       jr      nz,Fptl
;       ld      a,(Size+2)
;       or      a
;       jr      nz,Fptl
;       ld      a,(Size+1)
;       cp      #80
;       jr      nc,Fptl
; ROM Image is small, use no mapper
; bla bla bla :)

FMROM:
        print   MROMD_S
        ld      hl,(Size)
        exx
        ld      hl,(Size+2)
        ld      bc,0
        exx

        ld      a,%00000100
        ld      de,ssr08
        ld      bc,#2001                ; >8Kb
        or      a
        sbc     hl,bc
        exx
        sbc     hl,bc
        exx
        jr      c,FMRM01

        ld      a,%00000101
        ld      de,ssr16
        ld      bc,#4001-#2001          ; (#2000) >16kB
        sbc     hl,bc
        exx
        sbc     hl,bc
        exx
        jr      c,FMRM01

        ld      a,%00000110
        ld      de,ssr32
        ld      bc,#8001-#4001          ; (#4000) >32kb
        sbc     hl,bc
        exx
        sbc     hl,bc
        exx
        jr      c,FMRM01

        ld      a,%00001110
        ld      de,ssr48
        ld      bc,#C001-#8001          ; (#4000) >48kB
        sbc     hl,bc
        exx
        sbc     hl,bc
        exx
        jr      c,FMRM01

        ld      a,%00000111
        ld      de,ssr64
        ld      bc,#4000                ; #10001-#C001 >64kB
        sbc     hl,bc
        exx
        sbc     hl,bc
        exx
        jr      c,FMRM01

        xor     a
        ld      de,ssrMAP


FMRM01:                                 ; fix size
        ld      (SRSize),a
        ld      c,_STROUT
        call    DOS
        print   ONE_NL_S

; !!!! file attribute fix by Alexey !!!!
        ld      a,(FCB+#0D)
        cp      #20
        jr      z,Fptl
        ld      a,#20
        ld      (FCB+#0D),a
; !!!! file attribute fix by Alexey !!!!

; Analyze ROM-Image

; load first 8000h bytes for analysis
Fptl:   ld      hl,#8000
        ld      c,_RBREAD
        ld      de,FCB
        call    DOS
        ld      a,l
        or      h
        jp      z,FrErr

; descriptor analysis
;ROMABCD - % 0, 0, CD2, AB2, CD1, AB1, CD0, AB0
;ROMJT0  - CD, AB, 0,0,TEXT ,DEVACE, STAT, INIT
;ROMJT1
;ROMJT2
;ROMJI0 - high byte INIT jmp-address
;ROMJI1
;ROMJI2
        ld      bc,6
        ld      hl,ROMABCD
        ld      de,ROMABCD+1
        ld      (hl),b
        ldir                            ; clear descr tab

        ld      ix,BUFTOP               ; test #0000
        call    fptl00
        ld      (ROMJT0),a
        and     #0F
        jr      z,fpt01
        ld      a,e
        ld      (ROMJI0),a
fpt01:
        ld      a,(SRSize)
        and     #0F
        jr      z,fpt07                 ; MAPPER
        cp      6
        jr      c,fpt03                 ; <= 16 kB
fpt07:
        ld      ix,BUFTOP+#4000         ; test #4000
        call    fptl00
        ld      (ROMJT1),a
        and     #0F
        jr      z,fpt02
        ld      a,e
        ld      (ROMJI1),a
fpt02:
        ld      a,(SRSize)
        and     #0F
        jr      z,fpt08                 ; MAPPER
        cp      7
        jr      c,fpt03                 ; <= 16 kB
fpt08:
        ld      c,_SDMA
        ld      de,BUFFER
        call    DOS

        ld      hl,#0010
        ld      c,_RBREAD
        ld      de,FCB
        call    DOS
        ld      a,l
        or      h
        jp      z,FrErr

        ld      ix,BUFFER               ; test #8000
        call    fptl00
        ld      (ROMJT2),a
        and     #0F
        jr      z,fpt03
        ld      a,e
        ld      (ROMJI2),a

fpt03:
        ld      c,_SDMA
        ld      de,BUFTOP
        call    DOS
        jp      FPT10

fptl00:
        ld      h,(ix+1)
        ld      l,(ix)
        ld      bc,"A"+"B"*#100
        xor     a
        push    hl
        sbc     hl,bc
        pop     hl
        jr      nz,fptl01
        set     6,a
fptl01: ld      bc,"C"+"D"*#100
        or      a
        sbc     hl,bc
        jr      nz,fptl02
        set     7,a
fptl02: ld      e,a
        ld      d,0
        or      a
        jr      z,fptl03                ; no AB,CD descriptor

        ld      b,4
        push    ix
        pop     hl
        inc     hl                      ; +1
fptl05:
        inc     hl                      ; +2
        ld      a,(hl)
        inc     hl
        or      (hl)                    ; +3
        jr      z,fptl04
        scf
fptl04: rr      d
        djnz    fptl05
        rrc     d
        rrc     d
        rrc     d
        rrc     d
fptl03:
        ld      a,d
        or      e
        ld      d,a
        ld      e,(ix+3)
        bit     0,d
        jr      nz,fptl06
        ld      e,(ix+5)
        bit     1,d
        jr      nz,fptl06
        ld      e,(ix+7)
        bit     2,d
        jr      nz,fptl06
        ld      e,(ix+9)
fptl06:
;       ld      e,a
;       ld      a,d
        ret
FPT10:

; file close NO! saved for next block
;       ld      de,FCB
;       ld      c,_FCLOSE
;       call    DOS

; print test ROM descriptor table
        ld      a,(F_V)                 ; verbose mode?
        or      a
        jr      z,vrb02

        print   TestRDT
        ld      a,(ROMJT0)
        call    HEXOUT
        ld      e," "
        ld      c,_CONOUT
        call    DOS
        ld      a,(ROMJT1)
        call    HEXOUT
        ld      e," "
        ld      c,_CONOUT
        call    DOS
        ld      a,(ROMJT2)
        call    HEXOUT
        print   ONE_NL_S
        ld      a,(ROMJI0)
        call    HEXOUT
        ld      e," "
        ld      c,_CONOUT
        call    DOS
        ld      a,(ROMJI1)
        call    HEXOUT
        ld      e," "
        ld      c,_CONOUT
        call    DOS
        ld      a,(ROMJI2)
        call    HEXOUT
        print   ONE_NL_S

vrb02:
; Map / miniROm select
        ld      a,(SRSize)
        and     #0F
        jr      z,FPT01A                ; MAPPER ROM
        cp      7
        jp      c,FPT04                 ; MINI ROM

;       print   MRSQ_S
;FPT03: ld      c,_INNOE                ; 32 < ROM =< 64
;       call    DOS
;       cp      "n"
;       jr      z,FPT01                 ; no minirom (mapper)
;       cp      "y"                     ; yes minirom
;       jr      nz,FPT03

        jr      FPT01B                  ; Mapper detected!

FPT01A:
        xor     a
        ld      (SRSize),a
FPT01B:
        ld      a,(RCPData)
        or      a                       ; RCP data available?
        jp      z,DTMAP

        ld      de,FCB
        ld      c,_FCLOSE
        call    DOS                     ; close file

        ld      hl,RCPData
        ld      de,Record+#04
        ld      a,(hl)
        ld      (de),a                  ; copy mapper type
        inc     hl
        ld      de,Record+#23
        ld      bc,29
        ldir                            ; copy the RCP record to directory record

        jp      SFM80


; Mapper types Singature
; Konami:
;    LD    (#6000),a
;    LD    (#8000),a
;    LD    (#a000),a
;
;    Konami SCC:
;    LD    (#5000),a
;    LD    (#7000),a
;    LD    (#9000),a
;    LD    (#b000),a
;
;    ASCII8:
;    LD    (#6000),a
;    LD    (#6800),a
;    LD    (#7000),a
;    LD    (#7800),a
;
;    ASCII16:
;    LD    (#6000),a
;    LD    (#7000),a
;
;    32 00 XX
;
;    For Konami games is easy since they always use the same register addresses.
;
;    But ASC8 and ASC16 is more difficult because each game uses its own addresses and instructions to access them.
;    I.e.:
;    LD    HL,#68FF 2A FF 68
;    LD    (HL),A   77
;
;    BIT E 76543210
;          !!!!!!!. 5000h
;          !!!!!!.- 6000h
;          !!!!!.-- 6800h
;          !!!!.--- 7000h
;          !!!.---- 7800h
;          !!.----- 8000h
;          !.------ 9000h
;          .------- A000h
;    BIT D 76543210
;                 . B000h
DTMAP:
        print   Analis_S
        ld      de,0
DTME6:                          ; point next portion analis
        ld      ix,BUFTOP
        ld      bc,#8000
DTM01:  ld      a,(ix)
        cp      #2A
        jr      nz,DTM03
        ld      a,(ix+1)
        cp      #FF
        jr      nz,DTM02
        ld      a,(ix+3)
        cp      #77
        jr      nz,DTM02
        ld      a,(ix+2)
        cp      #60
        jr      z,DTM60
        cp      #68
        jr      z,DTM68
        cp      #70
        jr      z,DTM70
        cp      #78
        jr      z,DTM78
        jr      DTM02
DTM03:  cp      #32
        jr      nz,DTM02
        ld      a,(ix+1)
        cp      #00
        jr      nz,DTM02
        ld      a,(ix+2)
        cp      #50
        jr      z,DTM50
        cp      #60
        jr      z,DTM60
        cp      #68
        jr      z,DTM68
        cp      #70
        jr      z,DTM70
        cp      #78
        jr      z,DTM78
        cp      #80
        jr      z,DTM80
        cp      #90
        jr      z,DTM90
        cp      #A0
        jr      z,DTMA0
        cp      #B0
        jr      z,DTMB0

DTM02:  inc     ix
        dec     bc
        ld      a,b
        or      c
        jr      nz,DTM01
        jr      DTME
DTM50:
        set     0,e
        jr      DTM02
DTM60:
        set     1,e
        jr      DTM02
DTM68:
        set     2,e
        jr      DTM02
DTM70:
        set     3,e
        jr      DTM02
DTM78:
        set     4,e
        jr      DTM02
DTM80:
        set     5,e
        jr      DTM02
DTM90:
        set     6,e
        jr      DTM02
DTMA0:
        set     7,e
        jr      DTM02

DTMB0:
        set     0,d
        jr      DTM02


DTME:
        ld      (BMAP),de               ; save detected bit mask

        ld      a,(F_V)                 ; verbose mode?
        or      a
        jr      z,DTME23
; print bitmask
        ld      a,(BMAP+1)
        call    HEXOUT
        ld      a,(BMAP)
        call    HEXOUT
        ld      e," "
        ld      c,_CONOUT
        call    DOS
DTME23:

        ld      a,0

;    BIT E 76543210
;          !!!!!!!. 5000h
;          !!!!!!.- 6000h
;          !!!!!.-- 6800h
;          !!!!.--- 7000h
;          !!!.---- 7800h
;          !!.----- 8000h
;          !.------ 9000h
;          .------- A000h
;    BIT D 76543210
;                 . B000h
        ld      a,(BMAP+1)
        bit     0,a
;       cp      %00000001
        ld      a,(BMAP)
;       jr      z,DTME2                 ; Konami5
        jr      nz,DTME2                        ; Konami5

        ld      b,4                     ; AsCII 16
        cp      %00001010               ; 6000h 7000h
        jp      z,DTME1
;       cp      %00000010               ; Zanax-EX
;       jr      z,DTME1

        ld      b,1                     ; Konami (4)
        cp      %10100010               ; 6000h 8000h A000h
        jp      z,DTME1
        cp      %10100000               ; Aleste
        jp      z,DTME1
        cp      %00100010               ; 6000h 8000h
        jp      z,DTME1                 ;
        cp      %00100000               ; 8000h
        jp      z,DTME1


        ld      b,3                     ; ASCII 8
        cp      %00011110               ; 6000h,6800h,7000h,8700h
        jr      z,DTME1
        cp      %00011100
        jr      z,DTME1
        cp      %00011000               ; 0018
        jr      z,DTME1

DTME3:                                  ; Mapper not detected
                                        ; second portion ?
                                        ; next block file read
        ld      c,_SDMA
        ld      de,BUFTOP
        call    DOS
        ld      hl,#8000
        ld      c,_RBREAD
        ld      de,FCB
        call    DOS
        ld      a,l
        or      h
        ld      de,(BMAP)               ; load previos bitmask
        jp      z,DTME5
        set     7,d                     ; bit second seach
        jp      DTME6                   ; next analise search

DTME5:                                  ; fihish file
        ld      a,e
        ld      b,4
        cp      %00000010               ; 0002 = ASCII 16 ZanacEX
        jr      z,DTME1
        cp      %00001000               ; 0008 = ASCII 16
        jr      z,DTME1
        cp      %01001000               ; 0048 = ASCII 16
        jr      z,DTME1
        ld      b,3
        cp      %00001110               ; 000E = ASCII 8
        jr      z,DTME1
        cp      %00000100               ; 0004 = ASCII 8
        jr      z,DTME1
        cp      %00100000               ; 0010 = ASCII 8
        jr      z,DTME1
        ld      b,0
        jr      DTME1
DTME2:
        cp      %01001001               ; 5000h,7000h,9000h
        ld      b,2                     ; Konami 5 (SCC)
        jr      z,DTME1
        cp      %01001000               ; 5000h,7000h
        jr      z,DTME1
        cp      %01101001               ;
        jr      z,DTME1
        cp      %11101001               ; 01E9
        jr      z,DTME1
        cp      %01101000               ; 0168
        jr      z,DTME1
        cp      %11001000               ; 01C8
        jr      z,DTME1
        cp      %01000000               ; 0140
        jr      z,DTME1

        ld      b,3
        cp      %00011000
        jr      z,DTME1
        ld      b,1
        cp      %10100000
        jr      z,DTME1
        jr      DTME3
DTME1:
        ld      a,b
        ld      (DMAP),a                ; save detected Mapper type
        or      a
        jr      nz,DTME21

;mapper not found
        ld      a,(SRSize)
        or      a
        jr      z,DTME22                ; size > 64k ? not minirom

        print   MD_Fail

        ld      a,(F_A)
        or      a
        jr      nz,FPT04                ; flag auto yes

        print   MRSQ_S
FPT03:  ld      c,_INNOE                ; 32 < ROM =< 64
        call    DOS
        or      %00100000
        cp      "n"
        jp      z,MTC                   ; no minirom (mapper), select manually
        cp      "y"                     ; yes minirom
        jr      nz,FPT03

FPT04:
        ld      a,(RCPData)
        or      a                       ; RCP data available?
        jp      z,FPT05

        ld      hl,RCPData
        ld      de,Record+#04
        ld      a,(hl)
        ld      (de),a                  ; copy mapper type
        inc     hl
        ld      de,Record+#23
        ld      bc,29
        ldir                            ; copy the RCP record to directory record

        print   UsingRCP
        jp      SFM80

FPT05:
; Mini ROM set
        print   NoAnalyze
        ld      a,5
        ld      (DMAP),a                ; Minirom
        jr      DTME22

DTME21:
        xor     a
        ld      (SRSize),a

DTME22:
                                        ; file close
        ld      de,FCB
        ld      c,_FCLOSE
        call    DOS

        ld      a,(DMAP)
        ld      b,a
        call    TTAB
        inc     hl
        ex      de,hl
        ld      c,_STROUT               ; print selected MAP
        call    DOS
        print   ONE_NL_S

        ld      a,(SRSize)
        and     #0F
        jp      nz,DE_F1                ; do not confirm the mapper type

        ld      a,(F_A)
        or      a
        jp      nz,DE_F1                ; do not confirm the type mapper (auto)

        ld      a,(DMAP)
        or      a
        jr      z,MTC
        print   CTC_S                   ; (y/n)?
DTME4:  ld      c,_INNOE
        call    DOS
        or      %00100000
        cp      "y"
        jp      z,DE_F1
        cp      "n"
        jr      nz,DTME4
MTC:                                    ; Manually select MAP type
        print   CoTC_S
        ld      a,1
MTC2:   ld      (DMAPt),a               ; prtint all tab MAP
        ld      b,a
        call    TTAB
        ld      a,(hl)
        or      a
        jr      z,MTC1
        push    hl
        ld      a,(DMAPt)
        ld      e,a
        ld      d,0
        ld      hl,BUFFER
        ld      b,2
        ld      c," "
        ld      a,%00001000             ; print 2 decimal digit number
        call    NUMTOASC
        print   BUFFER
        ld      e," "
        ld      c,_CONOUT
        call    DOS
        pop     hl
        inc     hl
        ex      de,hl
        ld      c,_STROUT
        call    DOS
        print   ONE_NL_S
        ld      a,(DMAPt)
        inc     a
        jr      MTC2
MTC1:
        print   Num_S

MTC3:
        ld      c,_INNOE
        call    DOS                     ; input one character
        cp      "1"
        jr      c,MTC3
        cp      MAPPN + "1"             ; number of supported mappers + 1
        jr      nc,MTC3
        push    af
        ld      e,a
        ld      c,_CONOUT
        call    DOS                     ; print selection
        print   ONE_NL_S
        pop     af
        sub     a,"0"

MTC6:
; check input
        ld      hl,DMAPt
        cp      (hl)
        jp      nc,MTC
        or      a
        jp      z,MTC
        ld      b,a
        push    af
        push    bc
        print   SelMapT
        pop     bc
        pop     af
        jp      DTME1

DE_F1:
; Save MAP config to Record form
        ld      a,(DMAP)
        ld      b,a
        call    TTAB
        ld      a,(hl)
        ld      (Record+04),a           ; type descriptos symbol
        ld      bc,35                   ; TAB register map
        add     hl,bc
        ld      de,Record+#23           ; Record register map
        ld      bc,29                   ; (6 * 4) + 5
        ldir

        ld      a,(SRSize)
        ld      (Record+#3D),a

; Correction start metod

; ROMJT0
        ld      ix,ROMJT0
        and     #0F
        jp      z,Csm01                 ; mapper ROM

;Mini ROM-image
        cp      5                       ; =< 8Kb
        jr      nc,Csm04

        ld      a,#A4                   ; set size 8kB no Ch.reg
        ld      (Record+#26),a          ; Bank 0
        ld      a,#AD                   ; set Bank off
        ld      (Record+#2C),a          ; Bank 1
        ld      (Record+#32),a          ; Bank 2
        ld      (Record+#38),a          ; Bank 3
Csm08:  ld      a,(ix)
        cp      #41
        ld      a,#40
        jr      nz,Csm06                ; start on reset
        ld      a,(ix+3)
        and     #C0
        ld      (Record+#28),a          ; set Bank Addr
        cp      #40
        jr      z,Csmj4                 ; start on #4000
        cp      #80
        jr      z,Csmj8                 ; start Jmp(8002)
Csm06:
        ld      a,(ix+3)
        and     #C0
        ld      (Record+#28),a          ; set Bank Addr

        ld      a,01                    ; start on reset
Csm05:  ld      (Record+#3E),a
        jp      Csm80

Csmj4:  ld      a,2
        jr      Csm05
Csmj8:  ld      a,6
        jr      Csm05

;
Csm04:  cp      6                       ; =< 16 kB
        jr      nc,Csm07

        ld      a,#A5                   ; set size 16kB noCh.reg
        ld      (Record+#26),a          ; Bank 0
        ld      a,#AD                   ; set Bank off
        ld      (Record+#2C),a          ; Bank 1
        ld      (Record+#32),a          ; Bank 2
        ld      (Record+#38),a          ; Bank 3
        jp      Csm08

Csm07:  cp      7                       ; =< 32 kb
        jr      nc,Csm09
        ld      a,#A5                   ; set size 16kB noCh.reg
        ld      (Record+#26),a          ; Bank 0
        ld      a,#A5                   ; set size 16kB noCh.reg
        ld      (Record+#2C),a          ; Bank 1
        ld      a,#AD                   ; set Bank off
        ld      (Record+#32),a          ; Bank 2
        ld      (Record+#38),a          ; Bank 3
        ld      a,(ix)
        ld      b,a
;       cp      #41
        or      a
;       jr      z, Csm071
        jr      nz,Csm071
        ld      a,(ix+1)
        cp      #41
        jr      nz,Csm06
        ld      a,(ix+4)
        and     #C0
        cp      #80
        jr      nz,Csm06
        jr      Csmj8                   ; start Jmp(8002)
Csm071: ld      a,(ix+3)
        and     #C0
        cp      #40                     ; #4000
        jr      nz,Csm072
        ld      a,b
        cp      #41
        jp      nz,Csm06                ; R
        ld      a,2
        jp      Csm05                   ; start Jmp(4002)
        cp      #00                     ; #0000 subrom
        jr      nz,Csm072
        ld      (Record+#28),a          ; Bank1 #0000
        ld      a,#40
        ld      (Record+#2E),a          ; Bank2 #4000
        jp      Csm06                   ; start on reset
Csm072: cp      #80
        jp      nz,Csm06                ; start on reset
        ld      (Record+#28),a          ; Bank1 #0000
        ld      a,#C0
        ld      (Record+#2E),a          ; Bank2 #4000
        ld      a,6
        jp      Csm05                   ; start Jmp(8002)

Csm09:
        cp      7                       ; 64 kB ROM
        jr      nz,Csm10
        ld      a,#A7                   ; set size 64kB noCh.reg
        ld      (Record+#26),a          ; Bank 0
        ld      a,#AD                   ; set Bank off
        ld      (Record+#2C),a          ; Bank 1
        ld      (Record+#32),a          ; Bank 2
        ld      (Record+#38),a          ; Bank 3
        ld      a,0
        ld      (Record+#28),a          ; Bank 0 Address=0
        ld      a,(ix)
        or      a
        jp      nz,Csm06                ; start on Reset
        ld      a,(ix+1)
        or      a
        jr      z,Csm11
        cp      #41
        jp      nz,Csm06
        ld      a,2                     ; start jmp(4002)
        jp      Csm05
Csm11:  ld      a,(ix+2)
        cp      #41
        jp      nz,Csm06
        ld      a,6                     ; staer jmp(8002)
        jp      Csm05


Csm10:
;                                       ; %00001110 48 kB
        ld      a,#A5                   ; set size 16kB noCh.reg
        ld      (Record+#26),a          ; Bank 0
        ld      a,#A5                   ; set size 16kB noCh.reg
        ld      (Record+#2C),a          ; Bank 1
        ld      a,#A5                   ; set size 16kB noCh.reg
        ld      (Record+#32),a          ; Bank 2
        ld      a,#AD                   ; set Bank off
        ld      (Record+#38),a          ; Bank 3
        ld      a,1
        ld      (Record+#2B),a          ; correction for bank 1
        ld      a,(ix)
        or      a
        jr      z,Csm12
        cp      41
        jr      nz,Csm13
        ld      a,2                     ; start jmp(4002)
        jp      Csm05
Csm13:  ld      a,(ix+3)
        and     #C0
        jp      nz,Csm06                ; start on Reset
        xor     a                       ; 0 address
        ld      (Record+#28),a
        ld      a,#40
        ld      (Record+#2E),a
        ld      a,#80
        ld      (Record+#34),a
        jp      Csm06                   ; start on Reset
Csm12:  ld      a,(ix+1)
        or      a
        jr      z,Csm14
        ld      a,(ix+4)
        and     #C0
        cp      #40
        jr      nz,Csm15
        xor     a                       ; 0 address
        ld      (Record+#28),a
        ld      a,#40
        ld      (Record+#2E),a
        ld      a,#80
        ld      (Record+#34),a
        ld      a,(ix+1)
        cp      #41
        jp      nz,Csm06
        ld      a,2                     ; start jmp(4002)
        jp      Csm05
Csm15:  jp      Csm06

Csm14:  ld      a,(ix+2)
        or      a
        jp      nz,Csm06
        xor     a                       ; 0 address
        ld      (Record+#28),a
        ld      a,#80
        ld      (Record+#2E),a
        ld      a,(ix+2)
        cp      #41
        jp      nz,Csm06
        ld      a,6                     ; start jmp(8002)
        jp      Csm05

Csm01:

; Mapper ROM IMAGE start Bank #4000
;
        ld      a,(ix+1)                ; ROMJT1 (#8000)
        or      a
        jr      z,Csm02
Csm03:  ld      a,01                    ; Complex start
        ld      (Record+#3E),a          ; need Reset
        jp      Csm80
Csm02:
        ld      a,(ix)                  ; ROMJT0 (#4000)
        cp      #41
        jr      nz,Csm03                ; Reset
        ld      a,02                    ; Start to jump (#4002)
        ld      (Record+#3E),a

Csm80:  cp      1                       ; reset needed?
        jr      nz,Csm80a
        ld      a,(Record+#3C)
        and     %11111011               ; set reset bit to match 01 at #3E
        ld      (Record+#3C),a
        jr      Csm80b
Csm80a:
        cp      2
        jr      nz,Csm80b
        ld      a,(Record+#3C)
        or      %00000100               ; zero reset bit to match 02 at #3E
        ld      (Record+#3C),a

Csm80b:
; test print Size-start metod
        ld      a,(F_V)                 ; verbose mode?
        or      a
        jr      z,Csm81

        print   Strm_S
        ld      a,(Record+#3D)
        call    HEXOUT
        ld      e,"-"
        ld      c,_CONOUT
        call    DOS
        ld      a,(Record+#3E)
        call    HEXOUT
        print   ONE_NL_S

Csm81:  ld      a,(Record+#3D)
        and     #0F
        jp      SFM80                   ; mapper ROM

; Search free space in flash
SFM01:
;find
        ld      e,a
        push    de

        ld      a,(TPASLOT1)            ; reset 1 page
        ld      h,#40
        call    ENASLT

        ld      a,(F_V)                 ; verbose mode?
        or      a
        jr      z,SFM01A

        print   FNRE_S

        pop     de
        push    de
        ld      a,d                     ; print N record
        call    HEXOUT
        ld      e,"-"
        ld      c,_CONOUT
        call    DOS
        ld      a,(ix+2)                ; print N FlashBlock
        call    HEXOUT
        ld      e,"-"
        ld      c,_CONOUT
        call    DOS
        pop     de

        push    de
        ld      a,e                     ; print N Bank
        call    HEXOUT
        print   ONE_NL_S

SFM01A:
        pop     de

        ld      a,(Record+#3D)
        and     #0F
        cp      6
        ld      a,e
        jr      c,SFM70
        rlc     a
SFM70:
        ld      (Record+#25),a          ; R1Reg
        inc     a
        ld      (Record+#2B),a          ; R2Reg
        inc     a
        ld      (Record+#31),a          ; R3Reg
        inc     a
        ld      (Record+#37),a          ; R4Reg

        ld      a,e
        rlc     a
        rlc     a
        rlc     a
        rlc     a
        ld      b,a
        ld      a,(Record+#3D)
        and     #0F
        or      b
        ld      (Record+#3D),a

        ld      d,1
        ld      e,(ix+2)
        ld      a,d
        ld      (multi),a

        jp      DEFMR1

SFM80:
        xor     a
        ld      (multi),a

; Size  - size file 4 byte
; calc blocks len
        ld      a,(Size+3)
        or      a
        jr      nz,DEFOver
        ld      a,(Size+2)
        cp      #0C                     ; < 720kb?
        jr      c,DEFMR1

DEFOver:
        print   FileOver_S
        ld      a,(F_A)
        or      a
        jp      nz,Exit                 ; Automatic exit
        jp      MainM

DEFMR1:
        ld      a,4                     ; start from 4th block in RAM
        ld      (Record+02),a           ; Record+02 - starting block
        ld      a,(Size+2)
        or      a
        jr      nz,DEFMR2
        inc     a                       ; set minumum 1 block for any file
DEFMR2:
        ld      (Record+03),a           ; Record+03 - length in 64kb blocks
        ld      a,#FF
        ld      (Record+01),a           ; set active flag

DEF11:
        print   ONE_NL_S
        call    LoadImage               ; load file into RAM

; Restore slot configuration!
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
        ld      a,#15
        ld      (R2Mult),a              ; set 16kB Bank write
        xor     a
        ld      (EBlock),a
        ld      (AddrFR),a
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
        ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT                  ; Select Main-RAM at bank 8000h~BFFFh


; Configure cart register and start ROM
; ix - directory entry pointer
run_card:
        ld      hl,Record
        ld      de,#c100
        ld      bc,#40
        ldir
        ld      hl,reconf_begin
        ld      de,#c000
        ld      bc,reconf_end - reconf_begin
        ldir
        print   ONE_NL_S
        print   Prg_Su_S
        ld      a,(F_R)
        or      a
        jp      nz, #c000
        print   Prg_Reb_S
        xor     a
        jp      #c000

reconf_begin:
        push    af
        ld      a,(ERMSlt)              ; restore slot
        ld      h,#40
        call    ENASLT
        ld      a,%00111001             ; enable delayed reconfiguration
        ld      (CardMDR),a
        ld      a,(#c102)               ; set start block
        ld      (CardMDR+#05),a
        ld      hl,#c100                ; configure mapper
        ld      bc,#23
        add     hl,bc                   ; config data
        ld      de,CardMDR+#06
        ld      bc,25                   ; all but CardMDR
        ldir
        ld      a,(hl)                  ; CardMDR from RCP
        or      a,%10001000             ; disable config register and enable delayed reconfiguration
        ld      (de),a
        pop     af
        or      a
        jr      nz, reconf_exit

        ; reboot MSX
        in      a,(#F4)                 ; read from F4 port on MSX2+
        or      #80
        out     (#F4),a                 ; avoid "warm" reset on MSX2+

        rst     #30                     ; call to BIOS
   if SPC=0
        db      0
   else
        db      #80
   endif
        dw      0                       ; address

reconf_exit:
        ; leave to DOS instead of reboot
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
        ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT
        ld      de, Exit_S
        ld      c,_STROUT
        call    DOS
        ld      c,_TERM0
        jp      DOS

reconf_end:
        nop


;-----------------------------------------------------------------------------
LoadImage:
; Erase block's and load ROM-image

; Reopen file image

        ld      bc,24                   ; Prepare the FCB
        ld      de,FCB+13
        ld      hl,FCB+12
        ld      (hl),b
        ldir                            ; Initialize the second half with zero
        ld      de,FCB
        ld      c,_FOPEN
        call    DOS                     ; Open file
        ld      hl,1
        ld      (FCB+14),hl             ; Record size = 1 byte
        or      a
        jr      z,LIF01                 ; file open
        print   F_NOT_F_S
        ret
LIF01:  ld      c,_SDMA
        ld      de,BUFTOP
        call    DOS

; loading ROM-image to RAM
LIFM1:
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
        ld      a,#34                   ; RAM instead of ROM, Bank write enabled, 8kb pages, control off
        ld      (R2Mult),a              ; set value for Bank2

        ld      a,(Record+02)           ; start block (absolute block 64kB), 4 for RAM/Flash
        ld      (EBlock),a
        ld      (AddrFR),a
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT

        xor     a
        ld      (PreBnk),a              ; no shift for the first block

        print   LFRI_S

; calc loading cycles
; Size 3 = 0 ( or oversize )
; Size 2 (x 64 kB ) - cycles for (Eblock)
; Size 1,0 / 2000h - cycles for RAMProg portions

;Size / #2000
        ld      h,0
        ld      a,(Size+2)
        ld      l,a
        xor     a
        ld      a,(Size+1)
        rl      a
        rl      l
        rl      h                       ; 00008000
        rl      a
        rl      l
        rl      h                       ; 00004000
        rl      a
        rl      l
        rl      h                       ; 00002000
        ld      b,a
        ld      a,(Size)
        or      b
        jr      z,Fpr03
        inc     hl                      ; rounding up
Fpr03:  ld      (C8k),hl                ; save Counter 8kB blocks

Fpr02:

; !!!! file attribute fix by Alexey !!!!
        ld      a,(FCB+#0D)
        cp      #20
        jr      z,Fpr02a
        ld      a,#20
        ld      (FCB+#0D),a
; !!!! file attribute fix by Alexey !!!!

;load portion from file
Fpr02a: ld      c,_RBREAD
        ld      de,FCB
        ld      hl,#2000
        call    DOS
        ld      a,h
        or      l
        jp      z,Ld_Fail
;program portion
        ld      hl,BUFTOP
        ld      de,#8000
        ld      bc,#2000

        call    RAMProg                 ; save part of file to RAM
        jp      c,PRR_Fail

        ld      e,">"                   ; indicator
        ld      c,_CONOUT
        call    DOS
        ld      a,(PreBnk)
        inc     a                       ; next PreBnk
        and     7
        ld      (PreBnk),a
        jr      nz,FPr01
        ld      hl,EBlock
        inc     (hl)
FPr01:  ld      bc,(C8k)
        dec     bc
        ld      (C8k),bc
        ld      a,c
        or      b
        jr      nz,Fpr02

; finishing loading ROMimage

        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
        ld      a,#A4                   ; RAM instead of ROM, Bank write disabled, 8kb pages, control on
        ld      (R2Mult),a              ; set value for Bank2

        ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT                  ; Select Main-RAM at bank 8000h~BFFFh

        ret

LIF04:
; file close
        push    af
        ld      de,FCB
        ld      c,_FCLOSE
        call    DOS

        ld      a,(TPASLOT1)            ; reset 1 page
        ld      h,#40
        call    ENASLT
        ld      a,(TPASLOT2)            ; reset 1 page
        ld      h,#80
        call    ENASLT

        pop     af
        ret

PRR_Fail:
        print   ONE_NL_S
        print   FL_er_S
        print   ONE_NL_S
        scf                             ; set carry flag because of an error
        jr      LIF04

Ld_Fail:
        print   ONE_NL_S
        print   FR_ER_S
        print   ONE_NL_S
        scf                             ; set carry flag because of an error
        jr      LIF04


RAMProg:
; Block (0..2000h) program to RAM
; hl - buffer source
; de = #8000
; bc - Length
; (Eblock)x64kB, (PreBnk)x8kB(16kB) - start address in RAM
; output CF - failed flag
        exx
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
        ld      a,(PreBnk)
        ld      (R2Reg),a
        ld      a,(EBlock)
        ld      (AddrFR),a
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
        ld      a,(ERMSlt)
        ld      h,#80
        call    ENASLT
        exx

        ; check writable
        ex      de,hl
        ld      a,#aa
        ld      (hl),a
        cp      (hl)
        scf
        jr      nz,PrEr
        ld      a,#55
        ld      (hl),a
        cp      (hl)
        scf
        jr      nz,PrEr
        ex      de,hl

        ; copy
        ldir
        xor     a

PrEr:
; save flag (CF - fail)
        push    af
        ei

        ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT                  ; Select Main-RAM at bank 8000h~BFFFh
        pop     af
        exx
        ret


B1ON:   db      #F8,#50,#00,#85,#03,#40
B2ON:   db      #F0,#70,#01,#15,#7F,#80
B23ON:  db      #F0,#80,#00,#04,#7F,#80
        db      #F0,#A0,#00,#34,#7F,#A0


;-------------------------------
TTAB:
;       ld      b,(DMAP)
        inc     b
        ld      hl,CARTTAB
        ld      de,64
TTAB1:  dec     b
        ret     z
        add     hl,de
        xor     a
        cp      (hl)
        ret     z
        jr      TTAB1


FrErr:
; file close
        ld      de,FCB
        ld      c,_FCLOSE
        call    DOS
; print error
        ld      de,FR_ER_S
        ld      c,_STROUT
        call    DOS
; return main
        ld      a,(F_A)
        or      a
        jr      nz,Exit                 ; Automatic exit
        jp      MainM

Exit:
        ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT

        xor     a
        ld      (CURSF),a

        ld      de,Exit_S
        jp      termdos



;-----------------------------------------------------------------------------

FnameP:
; File Name prepearing
; input ix - buffer file name
; output - FCB
        ld      b,8+3
        ld      hl,FCB
        ld      (hl),0
fnp3:   inc     hl
        ld      (hl)," "
        djnz    fnp3

        ld      bc,24                   ; Prepare the FCB
        ld      de,FCB+13
        ld      hl,FCB+12
        ld      (hl),b
        ldir                            ; Initialize the second half with zero
;
; File name processing
        ld      hl,FCB+1
;       ld      ix,BUFFER

        ld      b,8
        ld      a,(ix+1)
        cp      ":"
        jr      nz,fnp0
; device name
        ld      a,(ix)
        and     a,%11011111
        sub     #40
        ld      (FCB),a
        inc     ix
        inc     ix
; file name
fnp0:   ld      a,(ix)
        or      a
        ret     z
        cp      "."
        jr      z,fnp1
        ld      (hl),a
        inc     ix
        inc     hl
        djnz    fnp0
        ld      a,(ix)
        cp      "."
        jr      z,fnp1
        dec     ix
; file ext
fnp1:
        ld      hl,FCB+9
        ld      b,3
fnp2:   ld      a,(ix+1)
        or      a
        ret     z
        ld      (hl),a
        inc     ix
        inc     hl
        djnz    fnp2

        ret


F_Key:
; Input A - Num parameter
; Output C,Z Flags, set key variable

        ld      de,BUFFER
        call    EXTPAR
        ret     c                       ; no parameter C- Flag
        ld      hl,BUFFER
        ld      a,(hl)
fkey01: cp      "/"
        ret     nz                      ; no Flag NZ - Flag
        inc     hl
        ld      a,(hl)
        and     %11011111
        cp      "P"
        jr      nz,fkey02
        ld      a,1
        ld      (F_P),a
        ret
fkey02: ld      hl,BUFFER+1
        ld      a,(hl)
        and     %11011111
        cp      "A"
        jr      nz,fkey03
        inc     hl
        ld      a,(hl)
        or      a
        jr      nz,fkey03
        ld      a,2
        ld      (F_A),a
        ret
fkey03: ld      hl,BUFFER+1
        ld      a,(hl)
        and     %11011111
        cp      "V"
        jr      nz,fkey04
        inc     hl
        ld      a,(hl)
        or      a
        jr      nz,fkey04
        ld      a,3
        ld      (F_V),a                 ; verbose mode flag
        ret
fkey04: ld      hl,BUFFER+1
        ld      a,(hl)
        and     %11011111
        cp      "M"
        jr      nz,fkey05
        inc     hl
        ld      a,(hl)
        or      a
        jr      z,fkeyill
        ld      (F_M),a                 ; mapper type
        inc     hl
        ld      a,(hl)
        or      a
        ret     z
fkey05: ld      hl,BUFFER+1
        ld      a,(hl)
        and     %11011111
        cp      "H"
        jr      nz,fkey06
        inc     hl
        ld      a,(hl)
        or      a
        jr      nz,fkey06
        ld      a,4
        ld      (F_H),a                 ; show help
        ret
fkey06:
        ld      hl,BUFFER+1
        ld      a,(hl)
        and     %11011111
        cp      "R"
        jr      nz,fkey07
        inc     hl
        ld      a,(hl)
        or      a
        jr      nz,fkey07
        ld      a,4
        ld      (F_R),a                 ; no reset after loading ROM
        ret
fkey07:
fkeyill:
        xor     a
        dec     a                       ; S - Illegal flag
        ret


;------------------------------------------------------------------------------

; Mapper and directory data areas

RSTCFG:
        db      #F8,#50,#00,#85,#03,#40
        db      0,0,0,0,0,0
        db      0,0,0,0,0,0
        db      0,0,0,0,0,0
        db      #FF,#30

CARTTAB: ; (N x 64 byte)
        db      "U"                                     ;1
        db      "Unknown mapper type              $"    ;34
        db      #F8,#50,#00,#A4,#FF,#40                 ;6
        db      #F8,#70,#01,#A4,#FF,#60                 ;6
        db      #F8,#90,#02,#A4,#FF,#80                 ;6
        db      #F8,#B0,#03,#A4,#FF,#A0                 ;6
        db      #FF,#BC,#00,#02,#FF                     ;5

CRTT1:  db      "k"
        db      "Konami (Konami 4)                $"
        db      #F8,#50,#00,#24,#FF,#40
        db      #F8,#60,#01,#A4,#FF,#60
        db      #F8,#80,#02,#A4,#FF,#80
        db      #F8,#A0,#03,#A4,#FF,#A0
        db      #FF,#AC,#00,#02,#FF
CRTT2:  db      "K"
        db      "Konami SCC (Konami 5)            $"
        db      #F8,#50,#00,#A4,#FF,#40
        db      #F8,#70,#01,#A4,#FF,#60
        db      #F8,#90,#02,#A4,#FF,#80
        db      #F8,#B0,#03,#A4,#FF,#A0
        db      #FF,#BC,#00,#02,#FF
CRTT3:  db      "a"
        db      "ASCII 8                          $"
        db      #F8,#60,#00,#A4,#FF,#40
        db      #F8,#68,#00,#A4,#FF,#60
        db      #F8,#70,#00,#A4,#FF,#80
        db      #F8,#78,#00,#A4,#FF,#A0
        db      #FF,#AC,#00,#02,#FF
CRTT4:  db      "A"
        db      "ASCII 16                         $"
        db      #F8,#60,#00,#A5,#FF,#40
        db      #F8,#70,#00,#A5,#FF,#80
        db      #F8,#60,#00,#A5,#FF,#C0
        db      #F8,#70,#00,#A5,#FF,#00
        db      #FF,#8C,#00,#01,#FF
CRTT5:  db      "M"
        db      "Mini ROM (without mapper)        $"
        db      #F8,#60,#00,#26,#7F,#40
        db      #F8,#70,#01,#28,#7F,#80
        db      #F8,#70,#02,#28,#3F,#C0
        db      #F8,#78,#03,#28,#3F,#A0
        db      #FF,#8C,#07,#01,#FF

        db      0                       ; end of mapper table

;
;Variables
;
protect:
        db      1
DOS2:   db      0
ShadowMDR
        db      #21
ERMSlt  db      1
Binpsl  db      2,0,"1",0
slot:   db      1
DMAP:   db      0
DMAPt:  db      1
BMAP:   ds      2
C8k:    dw      0
PreBnk: db      0
EBlock: db      0
ROMEXT: db      ".ROM",0

Bi_FNAM db      14,0,"D:FileName.ROM",0
;--- File Control Block
FCB:    db      0
        db      "           "
        ds      28
        db      0

FCBRCP: db      0
        db      "           "
        ds      28
        db      0

RCPExt: db      "RCP"

FILENAME:
        db      "                                $"
        db      0
Size:   db      0,0,0,0
Record: ds      #40
SRSize: db      0
multi   db      0
ROMABCD:
        db      0
ROMJT0: db      0
ROMJT1: db      0
ROMJT2: db      0
ROMJI0: db      0
ROMJI1: db      0
ROMJI2: db      0

DIRCNT: db      0,0
DIRPAG: db      0,0
CURPAG: db      0,0

; /-flags parameter
F_H     db      0
F_P     db      0
F_A     db      0
F_V     db      0
F_M     db      0
F_R     db      0
p1e     db      0

ZeroB:  db      0

Space:
        db      " $"
Bracket:
        db      " ",124," $"

FCBROM:
        db      0
        db      "????????ROM"
        ds      28

BUFFER: ds      256
        db      0,0,0


;------------------------------------------------------------------------------

;
; Text strings
;

DESCR:  db      "CMFCCFRC"
ABCD:   db      "0123456789ABCDEF"

ssrMAP: db      "64kb or more (mapper is required)$"
ssr64:  db      "64kb$"
ssr48:  db      "48kb$"
ssr32:  db      "32kb$"
ssr16:  db      "16kb$"
ssr08:  db      "8kb or less$"

MAIN_S: db      13,10
        db      "Main Menu",13,10
        db      "---------",13,10
        db      " 1 - Write ROM image into cartridge's RAM with protection",13,10
        db      " 2 - Write ROM image into cartridge's RAM without protection",13,10
        db      " 3 - Restart the computer",13,10
        db      " 0 - Exit to MSX-DOS",13,10,"$"

ADD_RI_S:
        db      13,10,"Input full ROM's file name or just press Enter to select files: $"
SelMode:
        db      10,13,"Selection mode: TAB - next file, ENTER - select, ESC - exit",10,13,"Found file(s):",9,"$"
NoMatch:
        db      10,13,"No ROM files found in the current directory!",10,13,"$"
OpFile_S:
        db      10,13,"Opening file: ","$"
UsingRCP:
        db      "Autodetection ignored, using data from RCP file...",10,13,"$"
F_NOT_F_S:
        db      "File not found!",13,10,"$"
F_NOT_FS:
        db      13,10,"File not found!","$"
FSizE_S:
        db      "File size error!",13,10,"$"
FR_ER_S:
        db      "File read error!",13,10,"$"
FR_ERS:
        db      13,10,"File read error!","$"
FR_ERW_S:
        db      13,10,"File write error!","$"
FR_ERC_S:
        db      13,10,"File create error!","$"
Analis_S:
        db      "Detecting ROM's mapper type: $"
SelMapT:
        db      "Selected ROM's mapper type: $"
NoAnalyze:
        db      "The ROM's mapper type is set to: $"
MROMD_S:
        db      "ROM's file size: $"
CTC_S:  db      "Do you confirm this mapper type? (y/n)",10,13,"$"
CoTC_S: db      10,13,"Manual mapper type selection:",13,10,"$"
Num_S:  db      "Your selection - $"
FileOver_S:
        db      "File is too big to be loaded into the cartridge's RAM!",13,10
        db      "You can only upload ROM files up to 720kb into RAM.",13,10
        db      "Please select another file...",13,10,"$"
MRSQ_S: db      10,13,"The ROM's size is between 32kb and 64kb. Create Mini ROM entry? (y/n)",13,10,"$"
Strm_S: db      "MMROM-CSRM: $"
FNRE_S: db      "Using Record-FBlock-NBank for Mini ROM",#0D,#0A
        db      "[Multi ROM entry] - $"
FDE_S:  db      "Found free directory entry at: $"
NR_I_S: db      "Name of directory entry: $"
FileSZH:
        db      "File size (hexadecimal): $"
NR_L_S: db      "Press ENTER to confirm or input a new name below:",13,10,"$"
LFRI_S: db      "Writing ROM image, please wait...",13,10,"$"
Prg_Su_S:
        db      13,10,"The ROM image was successfully written into cartridge's RAM!","$"
Prg_Reb_S:
        db      13,10,"Your MSX will reboot now ...",13,10,"$"
Exit_S:
        db      13,10,"The program will now exit",10,13,"$"
FL_er_S:
        db      13,10,"Writing into cartridge's RAM failed!",13,10,"$"
FL_erd_S:
        db      13,10,"Writing directory entry failed!",13,10,"$"
TWO_NL_S:
        db      13,10
ONE_NL_S:
        db      13,10,"$"
CLS_S:  db      27,"E$"
CLStr_S:
        db      27,"K$"
MD_Fail:
        db      "FAILED...",13,10,"$"
TestRDT:
        db      "ROM's descriptor table:",10,13,"$"

PRESENT_S:
        db      3
        db      "Carnivore2 MultiFunctional Cartridge RAM Loader v1.40",13,10
        db      "(C) 2015-2023 RBSC. All rights reserved",13,10,13,10,"$"
NSFin_S:
        db      "Carnivore2 cartridge was not found. Please specify its slot number - $"
Findcrt_S:
        db      "Found Carnivore2 cartridge in slot(s): $"
M_Wnvc:
        db      10,13,"WARNING!",10,13
        db      "Uninitialized cartridge or wrong version of Carnivore cartridge found!",10,13
        db      "Only Carnivore2 cartridge is supported. The program will now exit.",10,13,"$"

SltN_S: db      13,10,"Using slot - $"

I_FLAG_S:
        db      "Incorrect flag!",13,10,13,10,"$"
I_PAR_S:
        db      "Incorrect parameter!",13,10,13,10,"$"
I_MPAR_S:
        db      "Too many parameters!",13,10,13,10,"$"
H_PAR_S:
        db      "Usage:",13,10,13,10
        db      " c2ramldr [filename.rom] [/h] [/v] [/mN] [/a] [/p] [/r]",13,10,13,10
        db      "Command line options:",13,10
        db      " /h  - this help screen",13,10
        db      " /v  - verbose mode (show detailed information)",13,10
        db      " /m[1..4] - mapper select",13,10
        db      "   (1 = Konami 4, 2 = Konami 5 SCC, 3 = ASCII 8, 4 = ASCII 16)",13,10
        db      " /p  - switch RAM protection off after copying the ROM",10,13
        db      " /a  - do not ask configrmation (no user interaction)",13,10
        db      " /r  - do not restart the computer after uploading the ROM",10,13,"$"

RCPData:
        db      0
        ds      29

        db      0,0,0
        db      "RBSC:PTERO/WIERZBOWSKY/DJS3000/PYHESTY/GREYWOLF/SUPERMAX/VWARLOCK/TNT23:2023"
        db      0,0,0

BUFTOP:
;
; End of code, further space is reserved for working with data and cartridge's registers
;

