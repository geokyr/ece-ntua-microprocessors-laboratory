.include "m16def.inc"

.org 0x0
    rjmp reset
.org 0x4
    rjmp ISR1

.DEF COUNTER = r20
.DEF TEMP = r21

reset:
    ldi r24 , low(RAMEND)                 ; initialize stack pointer
    out SPL , r24
    ldi r24 , high(RAMEND)
    out SPH , r24

    ldi r23, (1 << ISC11)|(1 << ISC10)    ; rising edge of INT1
    out MCUCR, r23
    ldi r23, (1 << INT1)                  ; enable INT1
    out GICR, r23
    sei                                   ; enable interrupts
IO_set:
    clr r26
    out DDRA, r26                         ; input from A
    ser r26
    out DDRC, r26                         ; output at C
    out DDRB, r26                         ; output at B (INT COUNTER)
    clr r26                               ; initialize counter
    clr COUNTER                           ; initialize INT COUNTER
loop:
    out PORTC, r26                        ; sent counter to output
    inc r26                               ; increase counter
    rjmp loop                             ; repeat until interrupt

ISR1:
    push r26                              ; save r26
    in r26, SREG
    push r26                              ; save SREG

    inc COUNTER                           ; increase INT COUNTER
    in TEMP, PINA                         ; load input to TEMP
    andi TEMP, 0xC0                       ; keep only A7 and A6
    cpi TEMP, 0xC0                        ; check if A7 and A6 are on
    brne EXITINT                          ; if they are not exit

    out PORTB, COUNTER                    ; display it on PORTB LEDs
EXITINT:
    pop r26                               ; restore SREG
    out SREG, r26
    pop r26                               ; restore r26
    reti                                  ; return and enable INTs
