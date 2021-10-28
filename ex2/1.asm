.include "m16def.inc"

.DEF A = r16 
.DEF B = r17 
.DEF C = r18
.DEF D = r19
.DEF F0 = r20
.DEF F1 = r21
.DEF TEMP = r22
.DEF ANSWER = r23

IO_set: 
        clr r24
        out DDRC, r24   ; input 
        ser r24
        out DDRB, r24   ; output

main:   
        in A, PINC      ; load input on A
        mov TEMP, A     ; backup input on TEMP
        andi A, 0x01    ; LSB(A) = A

        mov B, TEMP     ; load input on B
        andi B, 0x02
        lsr B           ; LSB(B) = B

        mov C, TEMP     ; load input on C
        andi C, 0x04
        lsr C           
        lsr C           ; LSB(C) = C

        mov D, TEMP     ; load input on D
        andi D, 0x08
        lsr D
        lsr D           
        lsr D           ; LSB(D) = D

        mov TEMP, A     ; TEMP = A
        com TEMP        ; TEMP = A'
        and TEMP, B     ; TEMP = A'B
        mov F0, TEMP    ; F0 = A'B

        mov TEMP, B     ; TEMP = B
        com TEMP        ; TEMP = B'
        and TEMP, C     ; TEMP = B'C
        and TEMP, D     ; TEMP = B'CD

        or F0, TEMP     ; F0 = A'B + B'CD
        com F0          ; F0 = (A'B + B'CD)'

        mov TEMP, A     ; TEMP = A
        and TEMP, C     ; TEMP = AC
        mov F1, TEMP    ; F1 = AC

        mov TEMP, B     ; TEMP = B
        or TEMP, D      ; TEMP = B+D
        and F1, TEMP    ; F1 = (AC)(B+D)
        
        lsl F1          ; move F1 to 2nd LSB
        mov ANSWER, F1  ; ANSWER = 000000(F1)0
        or ANSWER, F0   ; ANSWER = 000000(F1)(F0)
        out PORTB, ANSWER

        rjmp main