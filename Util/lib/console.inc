;-------------------------------------------------------
;-- Console functions
;-------------------------------------------------------

;--- Macro for printing a $-terminated string
        macro print msg
        ld      de,msg
        ld      c,_STROUT
        call    DOS
        endm


; Clear screen and set screen 0
CLRSCR:
        xor     a
        rst     #30
   if SPC=0
        db      0
   else
        db      #80
   endif
        dw      #005F

        xor     a
        ld      (CURSF),a

        ret

; Hide functional keys
KEYOFF:
        rst     #30
   if SPC=0
        db      0
   else
        db      #80
   endif
        dw      #00CC
        ret

; Unhide functional keys
KEYON:
        rst     #30
   if SPC=0
        db      0
   else
        db      #80
   endif
        dw      #00CF
        ret


;---- Out to conlose HEX byte
; A - byte
HEXOUT:
        push    af
        rrc     a
        rrc     a
        rrc     a
        rrc     a
        and     #0F
        ld      b,0
        ld      c,a
        ld      hl,ABCD
        add     hl,bc
        ld      e,(hl)
        ld      c,_CONOUT
        call    DOS
        pop     af
        and     #0F
        ld      b,0
        ld      c,a
        ld      hl,ABCD
        add     hl,bc
        ld      e,(hl)
        ld      c,_CONOUT
        call    DOS
        ret
HEX:
;--- HEX
; input  a- Byte
; output a - H hex symbol
;        b - L hex symbol
        ld      c,a
        and     #0F
        add     a,48
        cp      58
        jr      c,he2
        add     a,7
he2:    ld      b,a
        ld      a,c
        rrc     a
        rrc     a
        rrc     a
        rrc     a
        and     #0F
        add     a,48
        cp      58
        ret     c
        add     a,7
        ret

