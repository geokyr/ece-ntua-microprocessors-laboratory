.org 0x0
    rjmp reset
.org 0x4
    rjmp ISR1

.DEF COUNTER = r20
.DEF TEMP = r21

main:
    ldi r23, (1 << ISC11) | (1 << ISC10)
    out MCUCR, r23
    ldi r23, (1 << INT1)
    out GICR, r23
    sei
IO_set:
    clr r26
    out DDRA, r26       ; input
    ser r26
    out DDRC, r26       ; output
    out DDRB, r26       ; output
    clr r26             ; initialize counter
    clr COUNTER         ; initialize interrupts COUNTER
loop: 
    out PORTC, r26      ; sent counter to output                
    ldi r24 , low(100)  ; load r25:r24 with 100
    ldi r25 , high(100)
    ; rcall wait_msec     ; call the delay function
    inc r26             ; increase counter
    rjmp loop           ; repeat the above steps

ISR1:
    in TEMP, PINA       ; load input to TEMP
    andi TEMP, 0xC0     ; keep only A7 and A6
    cpi TEMP, 0xC0      ; check if A7 and A6 are on
    breq DISPLAY        ; if they are both display COUNTER
    reti                ; if not then just return

DISPLAY:
    inc COUNTER         ; increase COUNTER
    out PORTB, COUNTER  ; display it on PORTB LEDs
    reti                ; return