
;-------------------------------------------------------------------------
;--- NAME: EXTPAR
;      Extracts a parameter from the command line
;    INPUT:   A  = Parameter to extract (the first one is 1)
;             DE = Buffer to put the extracted parameter
;    OUTPUT:  A  = Total number of parameters in the command line
;             CY = 1 -> The specified parameter does not exist
;                       B undefined, buffer unmodified
;             CY = 0 -> B = Parameter length, not including the tailing 0
;                       Parameter extracted to DE, finished with a 0 byte
;                       DE preserved

EXTPAR: or      a                       ; Terminates with error if A = 0
        scf
        ret     z

        ld      b,a
        ld      a,(#80)                 ; Terminates with error if
        or      a                       ; there are no parameters
        scf
        ret     z
        ld      a,b

        push    af,hl
        ld      a,(#80)
        ld      c,a                     ; Adds 0 at the end
        ld      b,0                     ; (required under DOS 1)
        ld      hl,#81
        add     hl,bc
        ld      (hl),0
        pop     hl
        pop     af

        push    hl,de,ix
        ld      ix,0                    ; IXl: Number of parameter
        ld      ixh,a                   ; IXh: Parameter to be extracted
        ld      hl,#81

;* Scans the command line and counts parameters

PASASPC:
        ld      a,(hl)                  ; Skips spaces until a parameter
        or      a                       ; is found
        jr      z,ENDPNUM
        cp      " "
        inc     hl
        jr      z,PASASPC

        inc     ix                      ; Increases number of parameters
PASAPAR:        ld      a,(hl)          ; Walks through the parameter
        or      a
        jr      z,ENDPNUM
        cp      " "
        inc     hl
        jr      z,PASASPC
        jr      PASAPAR

;* Here we know already how many parameters are available

ENDPNUM:        ld      a,ixl           ; Error if the parameter to extract
        cp      ixh                     ; is greater than the total number of
        jr      c,EXTPERR               ; parameters available

        ld      hl,#81
        ld      b,1                     ; B = current parameter
PASAP2: ld      a,(hl)                  ; Skips spaces until the next
        cp      " "                     ; parameter is found
        inc     hl
        jr      z,PASAP2

        ld      a,ixh                   ; If it is the parameter we are
        cp      b                       ; searching for, we extract it,
        jr      z,PUTINDE0              ; else...

        inc     b
PASAP3: ld      a,(hl)                  ; ...we skip it and return to PASAP2
        cp      " "
        inc     hl
        jr      nz,PASAP3
        jr      PASAP2

;* Parameter is located, now copy it to the user buffer

PUTINDE0:
        ld      b,0
        dec     hl
PUTINDE:        inc     b
        ld      a,(hl)
        cp      " "
        jr      z,ENDPUT
        or      a
        jr      z,ENDPUT
        ld      (de),a                  ; Parameter is copied to (DE)
        inc     de
        inc     hl
        jr      PUTINDE

ENDPUT: xor     a
        ld      (de),a
        dec     b

        ld      a,ixl
        or      a
        jr      FINEXTP
EXTPERR:        scf
FINEXTP:        pop     ix
                pop     de
                pop     hl
        ret


termdos:
        ld      c,_STROUT
        call    DOS

        ld      c,_TERM0
        jp      DOS



;--- NAME: NUMTOASC
;      Converts a 16 bit number into an ASCII string
;    INPUT:      DE = Number to convert
;                HL = Buffer to put the generated ASCII string
;                B  = Total number of characters of the string
;                     not including any termination character
;                C  = Padding character
;                     The generated string is right justified,
;                     and the remaining space at the left is padded
;                     with the character indicated in C.
;                     If the generated string length is greater than
;                     the value specified in B, this value is ignored
;                     and the string length is the one needed for
;                     all the digits of the number.
;                     To compute length, termination character "$" or 00
;                     is not counted.
;                 A = &B ZPRFFTTT
;                     TTT = Format of the generated string number:
;                            0: decimal
;                            1: hexadecimal
;                            2: hexadecimal, starting with "&H"
;                            3: hexadecimal, starting with "#"
;                            4: hexadecimal, finished with "H"
;                            5: binary
;                            6: binary, starting with "&B"
;                            7: binary, finishing with "B"
;                     R   = Range of the input number:
;                            0: 0..65535 (unsigned integer)
;                            1: -32768..32767 (twos complement integer)
;                               If the output format is binary,
;                               the number is assumed to be a 8 bit integer
;                               in the range 0.255 (unsigned).
;                               That is, bit R and register D are ignored.
;                     FF  = How the string must finish:
;                            0: No special finish
;                            1: Add a "$" character at the end
;                            2: Add a 00 character at the end
;                            3: Set to 1 the bit 7 of the last character
;                     P   = "+" sign:
;                            0: Do not add a "+" sign to positive numbers
;                            1: Add a "+" sign to positive numbers
;                     Z   = Left zeros:
;                            0: Remove left zeros
;                            1: Do not remove left zeros
;    OUTPUT:    String generated in (HL)
;               B = Length of the string, not including the padding
;               C = Length of the string, including the padding
;                   Tailing "$" or 00 are not counted for the length
;               All other registers are preserved

NUMTOASC:
        push    af,ix,de,hl
        ld      ix,WorkNTOA
        push    af,af
        and     %00000111
        ld      (ix+0),a                ; Type
        pop     af
        and     %00011000
        rrca
        rrca
        rrca
        ld      (ix+1),a                ; Finishing
        pop     af
        and     %11100000
        rlca
        rlca
        rlca
        ld      (ix+6),a                ; Flags: Z(zero), P(+ sign), R(range)
        ld      (ix+2),b                ; Number of final characters
        ld      (ix+3),c                ; Padding character
        xor     a
        ld      (ix+4),a                ; Total length
        ld      (ix+5),a                ; Number length
        ld      a,10
        ld      (ix+7),a                ; Divisor = 10
        ld      (ix+13),l               ; User buffer
        ld      (ix+14),h
        ld      hl,BufNTOA
        ld      (ix+10),l               ; Internal buffer
        ld      (ix+11),h

ChkTipo:        ld      a,(ix+0)        ; Set divisor to 2 or 16,
        or      a                       ; or leave it to 10
        jr      z,ChkBoH
        cp      5
        jp      nc,EsBin
EsHexa: ld      a,16
        jr      GTipo
EsBin:  ld      a,2
        ld      d,0
        res     0,(ix+6)                ; If binary, range is 0-255
GTipo:  ld      (ix+7),a

ChkBoH: ld      a,(ix+0)                ; Checks if a final "H" or "B"
        cp      7                       ; is desired
        jp      z,PonB
        cp      4
        jr      nz,ChkTip2
PonH:   ld      a,"H"
        jr      PonHoB
PonB:   ld      a,"B"
PonHoB: ld      (hl),a
        inc     hl
        inc     (ix+4)
        inc     (ix+5)

ChkTip2:        ld      a,d             ; If the number is 0, never add sign
        or      e
        jr      z,NoSgn
        bit     0,(ix+6)                ; Checks range
        jr      z,SgnPos
ChkSgn: bit     7,d
        jr      z,SgnPos
SgnNeg: push    hl                      ; Negates number
        ld      hl,0                    ; Sign=0:no sign; 1:+; 2:-
        xor     a
        sbc     hl,de
        ex      de,hl
        pop     hl
        ld      a,2
        jr      FinSgn
SgnPos: bit     1,(ix+6)
        jr      z,NoSgn
        ld      a,1
        jr      FinSgn
NoSgn:  xor     a
FinSgn: ld      (ix+12),a

ChkDoH: ld      b,4
        xor     a
        cp      (ix+0)
        jp      z,EsDec
        ld      a,4
        cp      (ix+0)
        jp      nc,EsHexa2
EsBin2: ld      b,8
        jr      EsHexa2
EsDec:  ld      b,5

EsHexa2:        push    de
Divide: push    bc,hl                   ; DE/(IX+7)=DE, remaining A
        ld      a,d
        ld      c,e
        ld      d,0
        ld      e,(ix+7)
        ld      hl,0
        ld      b,16
BucDiv: rl      c
        rla
        adc     hl,hl
        sbc     hl,de
        jr      nc,$+3
        add     hl,de
        ccf
        djnz    BucDiv
        rl      c
        rla
        ld      d,a
        ld      e,c
        ld      a,l
        pop     hl
        pop     bc

ChkRest9:       cp      10              ; Converts the remaining
        jp      nc,EsMay9               ; to a character
EsMen9: add     a,"0"
        jr      PonEnBuf
EsMay9: sub     10
        add     a,"A"

PonEnBuf:       ld      (hl),a          ; Puts character in the buffer
        inc     hl
        inc     (ix+4)
        inc     (ix+5)
        djnz    Divide
        pop     de

ChkECros:       bit     2,(ix+6)        ; Checks if zeros must be removed
        jr      nz,ChkAmp
        dec     hl
        ld      b,(ix+5)
        dec     b                       ; B=num. of digits to check
Chk1Cro:        ld      a,(hl)
        cp      "0"
        jr      nz,FinECeros
        dec     hl
        dec     (ix+4)
        dec     (ix+5)
        djnz    Chk1Cro
FinECeros:      inc     hl

ChkAmp: ld      a,(ix+0)                ; Puts "#", "&H" or "&B" if necessary
        cp      2
        jr      z,PonAmpH
        cp      3
        jr      z,PonAlm
        cp      6
        jr      nz,PonSgn
PonAmpB:        ld      a,"B"
        jr      PonAmpHB
PonAlm: ld      a,"#"
        ld      (hl),a
        inc     hl
        inc     (ix+4)
        inc     (ix+5)
        jr      PonSgn
PonAmpH:        ld      a,"H"
PonAmpHB:       ld      (hl),a
        inc     hl
        ld      a,"&"
        ld      (hl),a
        inc     hl
        inc     (ix+4)
        inc     (ix+4)
        inc     (ix+5)
        inc     (ix+5)

PonSgn: ld      a,(ix+12)               ; Puts sign
        or      a
        jr      z,ChkLon
SgnTipo:        cp      1
        jr      nz,PonNeg
PonPos: ld      a,"+"
        jr      PonPoN
        jr      ChkLon
PonNeg: ld      a,"-"
PonPoN  ld      (hl),a
        inc     hl
        inc     (ix+4)
        inc     (ix+5)

ChkLon: ld      a,(ix+2)                ; Puts padding if necessary
        cp      (ix+4)
        jp      c,Invert
        jr      z,Invert
PonCars:        sub     (ix+4)
        ld      b,a
        ld      a,(ix+3)
Pon1Car:        ld      (hl),a
        inc     hl
        inc     (ix+4)
        djnz    Pon1Car

Invert: ld      l,(ix+10)
        ld      h,(ix+11)
        xor     a                       ; Inverts the string
        push    hl
        ld      (ix+8),a
        ld      a,(ix+4)
        dec     a
        ld      e,a
        ld      d,0
        add     hl,de
        ex      de,hl
        pop     hl                      ; HL=initial buffer, DE=final buffer
        ld      a,(ix+4)
        srl     a
        ld      b,a
BucInv: push    bc
        ld      a,(de)
        ld      b,(hl)
        ex      de,hl
        ld      (de),a
        ld      (hl),b
        ex      de,hl
        inc     hl
        dec     de
        pop     bc
        ld      a,b                     ; *** This part was missing on the
        or      a                       ; *** original routine
        jr      z,ToBufUs               ; ***
        djnz    BucInv
ToBufUs:
        ld      l,(ix+10)
        ld      h,(ix+11)
        ld      e,(ix+13)
        ld      d,(ix+14)
        ld      c,(ix+4)
        ld      b,0
        ldir
        ex      de,hl

ChkFin1:        ld      a,(ix+1)        ; Checks if "$" or 00 finishing is desired
        and     %00000111
        or      a
        jr      z,Fin
        cp      1
        jr      z,PonDolar
        cp      2
        jr      z,PonChr0

PonBit7:        dec     hl
        ld      a,(hl)
        or      %10000000
        ld      (hl),a
        jr      Fin

PonChr0:        xor     a
        jr      PonDo0
PonDolar:       ld      a,"$"
PonDo0: ld      (hl),a
        inc     (ix+4)

Fin:    ld      b,(ix+5)
        ld      c,(ix+4)
        pop     hl
        pop     de
        pop     ix
        pop     af
        ret

WorkNTOA:       defs    16
BufNTOA:        ds      10
