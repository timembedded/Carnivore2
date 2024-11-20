;
; Address definitions for BIOS / DOS / System
;

;--- System calls and variables

DOS:    equ     #0005           ; DOS function calls entry point
ENASLT: equ     #0024           ; BIOS Enable Slot
WRTSLT: equ     #0014           ; BIOS Write to Slot
CALLSLT:equ     #001C           ; Inter-slot call
SCR0WID equ     #F3AE           ; Screen0 width
CURSF   equ     #FCA9

TPASLOT1:       equ     #F342
TPASLOT2:       equ     #F343
CSRY    equ     #F3DC
CSRX    equ     #F3DD
ARG:    equ     #F847
EXTBIO: equ     #FFCA
MNROM:  equ     #FCC1           ; Main-ROM Slot number & Secondary slot flags table

CardMDR:        equ     #4F80
AddrM0: equ     #4F80+1
AddrM1: equ     #4F80+2
AddrM2: equ     #4F80+3
DatM0:  equ     #4F80+4

AddrFR: equ     #4F80+5

R1Mask: equ     #4F80+6
R1Addr: equ     #4F80+7
R1Reg:  equ     #4F80+8
R1Mult: equ     #4F80+9
B1MaskR:        equ     #4F80+10
B1AdrD: equ     #4F80+11

R2Mask: equ     #4F80+12
R2Addr: equ     #4F80+13
R2Reg:  equ     #4F80+14
R2Mult: equ     #4F80+15
B2MaskR:        equ     #4F80+16
B2AdrD: equ     #4F80+17

R3Mask: equ     #4F80+18
R3Addr: equ     #4F80+19
R3Reg:  equ     #4F80+20
R3Mult: equ     #4F80+21
B3MaskR:        equ     #4F80+22
B3AdrD: equ     #4F80+23

R4Mask: equ     #4F80+24
R4Addr: equ     #4F80+25
R4Reg:  equ     #4F80+26
R4Mult: equ     #4F80+27
B4MaskR:        equ     #4F80+28
B4AdrD: equ     #4F80+29

CardMod:        equ     #4F80+30

CardMDR2:       equ     #4F80+31
ConfFl: equ     #4F80+32
ADESCR: equ     #4010

;--- Important constants

L_STR:  equ     16              ; number of entries on the screen
MAPPN:  equ     5               ; max number of currently supported mappers

;--- DOS function calls

_TERM0: equ     #00             ; Program terminate
_CONIN: equ     #01             ; Console input with echo
_CONOUT:        equ     #02     ; Console output
_DIRIO: equ     #06             ; Direct console I/O
_INNOE: equ     #08             ; Console input without echo
_STROUT:        equ     #09     ; String output
_BUFIN: equ     #0A             ; Buffered line input

_CONST: equ     #0B             ; Console status
_FOPEN: equ     #0F             ; Open file
_FCLOSE equ     #10             ; Close file
_FSEARCHF       equ     #11     ; File Search First
_FSEARCHN       equ     #12     ; File Search Next
_FCREATE        equ     #16     ; File Create
_SDMA:  equ     #1A             ; Set DMA address
_RBWRITE        equ     #26     ; Random block write
_RBREAD:        equ     #27     ; Random block read
_TERM:  equ     #62             ; Terminate with error code
_DEFAB: equ     #63             ; Define abort exit routine
_DOSVER:        equ     #6F     ; Get DOS version
