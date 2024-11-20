;-------------------------------------------------------
; Mega mapper functions
;-------------------------------------------------------

FindSlot:
; Auto-detection
        ld      b,3                     ; B=Primary Slot
BCLM:
        ld      c,0                     ; C=Secondary Slot
BCLMI:
        push    bc
        call    AutoSeek
        pop     bc
        jr      z,BCTSF1
        inc     c
        bit     7,a
        jr      z,BCLM2                 ; not extended slot
        ld      a,c
        cp      4
        jr      nz,BCLMI                ; Jump if Secondary Slot < 4
BCLM2:  dec     b
        jp      p,BCLM                  ; Jump if Primary Slot < 0
        print   NSFin_S                 ; "Carnivore2 cartridge was not found ..."

; input slot number
        ld      de,Binpsl
        ld      c,_BUFIN
        call    DOS
        ld      a,(Binpsl+1)
        or      a
        jr      z,BCTSF                 ; no input slot
        ld      a,(Binpsl+2)
        sub     a,"0"
        and     3
        ld      (ERMSlt),a
        ld      a,(Binpsl+1)
        cp      2
        jr      nz,BCTSF                ; no extended
        ld      a,(Binpsl+3)
        sub     a,"0"
        and     3
        rlc     a
        rlc     a
        ld      hl,ERMSlt
        or      (hl)
        or      #80
        ld      (hl),a
BCTSF:
        print   SltN_S

; Print result
BCTSF1:
        print   Findcrt_S               ; "Found Carnivore2 cartridge in slot(s): "
        ld      a,(ERMSlt)
        ld      b,a
        cp      #80
        jr      nc,Trp01
        ; only primary
        and     3
        add     a,"0"
        ld      e,a
        ld      c,_CONOUT
        call    DOS
        xor     a
        ret
Trp01:  rrc     a
        rrc     a
        and     %11000000
        ld      c,a
        ld      a,b
        and     %00001100
        or      c
        rrc     a
        rrc     a
Trp02:  call    HEXOUT
        print   ONE_NL_S
        xor     a
        ret

AutoSeek:
; return reg A - slot
        ld      a,b
        xor     3                       ; Reverse the bits to reverse the search order (0 to 3)
        ld      hl,MNROM
        ld      d,0
        ld      e,a
        add     hl,de
        bit     7,(hl)
        jr      z,primSlt               ; Jump if slot is not expanded
        or      (hl)                    ; Set flag for secondary slot
        sla     c
        sla     c
        or      c                       ; Add secondary slot value to format FxxxSSPP
primSlt:
        ld      (ERMSlt),a
        call    testsl1
        ld      a,(ERMSlt)
        ret

Testslot:
        ld      a,(ERMSlt)
testsl1:
        ld      h,#40
        call    ENASLT
        ld      hl,#4000                ; detect using card detect register
        ld      a,(hl)
        push    af
        ld      a,'c'                   ; open card detect register by writing sequence 'cv2'
        ld      (hl),a
        ld      a,'v'
        ld      (hl),a
        ld      a,'2'
        ld      (hl),a
        ld      a,'C'                   ; check if we read back sequence 'CV2'
        cp      (hl)
        jr      nz,cnotf
        ld      a,'V'
        cp      (hl)
        jr      nz,cnotf
        ld      a,'2'
        cp      (hl)
cnotf:
        pop     de
        ld      (hl),d                  ; restore original content for in case this was ram,
        push    af                      ; this also closes the register again when it was a hit
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
        pop     af
        ret

