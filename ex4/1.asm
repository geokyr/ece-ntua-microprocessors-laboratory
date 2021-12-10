.DSEG
_tmp_: .byte 2					; initialize _tmp_ for RAM

.CSEG
.include "m16def.inc"

.org 0x00
rjmp main                       ; main program
.org 0x10
rjmp ISR_TIMER1_OVF             ; TIMER1 overflow interrupt routine
.org 0x1c
rjmp ISR_ADC                    ; ADC convertion interrupt routine

main:
    ldi r24, low(RAMEND)		; initialize stack pointer
    out SPL, r24
    ldi r24, high(RAMEND)
    out SPH, r24

    rcall lcd_init_sim			; initialize lcd screen
    rcall ADC_init              ; initialize ADC

	ldi r24, (1 << TOIE1)		; enable overflow interrupt
	out TIMSK, r24				; for TIMER1
	ldi r24, (1 << CS12) | (0 << CS11) | (1 << CS10)
	out TCCR1B, r24				; set TCNT1 prescaler to CK/1024
	ldi r24, 0xfc				; interrupt every 100 ms so calculate
	out TCNT1H, r24				; initial value as 65536 - 0.1 *  
	ldi r24, 0xf3				; 8000000 / 1024 = 65536 - 781.25 =
	out TCNT1L, r24				; 64754.75 -> 64755 = 0xfcf3
	sei							; enable interrupts

	ser r24
    out DDRB, r24				; set PORTB as output
    out DDRD, r24				; set PORTD as output

    ldi r24, (1 << PC7) | (1 << PC6) | (1 << PC5) | (1 << PC4)
    out DDRC, r24				; set PORTC[7:4] as output

first:
    rcall scan_keypad_rising_edge_sim ; scan keypad
    clr r20						; add 2 registers with button values 
    or r20, r24					; to r20 and check if it is 0
    or r20, r25					; if it is 0 no button was pressed
    cpi r20, 0					; so repeat reading
    breq first					; else, continue

    mov r19, r25				; store buttons pressed to r19r18
    mov r18, r24

second:		
    rcall scan_keypad_rising_edge_sim ; scan keypad
    clr r20						; add 2 registers with button values 
    or r20, r24					; to r20 and check if it is 0
    or r20, r25					; if it is 0 no button was pressed
    cpi r20, 0					; so repeat reading
    breq second					; else, continue

    cpi r19, 0x40				; compare r19r18 to right value 3
    brne wrong_team				; that is 0x40 on r19 and 0x00 on r18
    cpi r18, 0					; if any register doesn't have the
    brne wrong_team				; right value, go to wrong_team
    cpi r25, 0x40				; since the 2 digits are not the 
    brne wrong_team				; right ones, else continue to
    cpi r24, 0					; correct team
    brne wrong_team				; also, do the same for r25r24

correct_team:
	rcall welcome

    ldi r20, 0x80
    out PORTB, r20				; turn PB7 on
    ldi r21, 0x50				; initialize counter to 80 for delay

    rcall delay_between			; call 50ms delay routine (4000ms)

    ldi r24, 0x01
	rcall lcd_command_sim		; clear display (1530 us delay)
	clr r20
    out PORTB, r20				; turn PB7 off

	; what happens with lcd and gas??

    rjmp first					; restart from the beginning

wrong_team:
	ldi r22, 0x04				; initialize counter for 4 blinks

led_blink:
    ldi r20, 0x80
    out PORTB, r20				; turn PB7 on
    ldi r21, 0x0a				; initialize counter to 10 for delay

    rcall delay_between			; call 50ms delay routine (500ms)

    clr r20
    out PORTB, r20				; turn PB7 off
    ldi r21, 0x0a				; initialize counter to 10 for delay

    rcall delay_between			; call 50ms delay routine (500ms)

    dec r22						; decrement blinking counter
    cpi r22, 0					; if it is not 0 repeat
    brne led_blink				; else continue

    rjmp first					; restart from the beginning

delay_between:
    rcall scan_keypad_rising_edge_sim ; scan keypad (15ms)
    ldi r24, low(35)			; set registers for 35ms delay
    ldi r25, high(35)			; so 15+35ms is equal to 50ms delay
    rcall wait_msec				; call the msec delay routine
    dec r21						; decrement delay counter
    cpi r21, 0					; if it is not 0 repeat
    brne delay_between			; else continue
    ret

welcome:
	rcall lcd_init_sim			; initialize lcd screen
    ldi r24,'W'					; print the required message 
	rcall lcd_data_sim			; 'WELCOME' character by character
	ldi r24,'E'
	rcall lcd_data_sim
	ldi r24,'L'
	rcall lcd_data_sim
	ldi r24,'C'
	rcall lcd_data_sim
	ldi r24,'O'
	rcall lcd_data_sim
	ldi r24,'M'
	rcall lcd_data_sim
	ldi r24,'E'
	rcall lcd_data_sim
	ret

; ================================================================= ;

ISR_TIMER1_OVF:
	push r24					; push r24 to stack
	in r24, ADCSRA				; get ADCSRA register status
	ori r24, (1 << ADSC)		; start the conversion by changing
	out ADCSRA, r24				; only the ADSC bit to 1.
	ldi r24, 0xfc				; reset the 100 ms interrupt timer
	out TCNT1H, r24
	ldi r24, 0xf3
	out TCNT1L, r24
	pop r24						; restore r24
	ret

; For the following routine we have used these equations:
;
; Vin = ADC * Vref / 1024 = ADC * 5 / 1024 = ADC / 204.8
; M = 129 * 10^2 * 10^(-9) * 10^3 = 129 * 10^(-4) = 129 / 10^4
; Cx = (1 / M) * (Vgas - Vags0) = (10^4 / 129) * (Vin - 0.1) =
; = (10^4 / 129) * ((ADC / 204.8) - 0.1) =>
; ((ADC / 204.8) - 0.1) = Cx * 129 / 10^4 =>
; ADC = ((Cx * 129 / 10^4) + 0.1) * 204.8 =>
; ADC = ((Cx / 77.52) + 0.1) * 204.8
;
; By solving the final equation for various Cx (ppm), we find the
; corresponding ADC values for the comparisons.
;
; Also we have 8 levels for the ADC 10 bit value (0 to 1023):
; 0 to 127 (0 leds), 128 to 255 (1 led), 256 to 383 (2 leds),
; 384 to 511 (3 leds), 512 to 639 (4 leds), 640 to 767 (5 leds),
; 768 to 895 (6 leds) and 896 to 1023 (7 leds).
;
; For Cx = 70 ppm we get ADC = 205.41 which rounds down to
; ADC = 205. So for ADC > 205 or ADC >= 206 we need to blink the 
; LEDs and print GAS DETECTED to the LCD Screen.
ISR_ADC:
	push r24					; push r24 to stack
	push r25					; push r25 to stack
	push r26					; push r26 to stack
	in r24, ADCL				; read ADC value from register
	in r25, ADCH				; low first, then high.
	andi r25, 0x03				; keep 2 LSBs from high (10 bit ADC)

	cpi r25, 0x00				; check if r25 = 0 meaning ADC < 256
	brne two_plus				; if it's not, then lowest level is 2
	cpi r24, 0x80				; compare r24 with threshold
	brlo level_zero				; if r24 < 128, level is 0
	rjmp level_one				; if r24 >= 128, level is 1
two_plus:
	cpi r25, 0x01				; check if r25 = 01 meaning ADC < 512
	brne four_plus				; if it's not, then lowest level is 4
	cpi r24, 0x80				; compare r24 with threshold
	brlo level_two				; if r24 < 128, level is 2
	rjmp level_three			; if r24 >= 128, level is 3
four_plus:
	cpi r25, 0x02				; check if r25 = 10 meaning ADC < 768
	brne six_plus				; if it's not, then lowest level is 6
	cpi r24, 0x80				; compare r24 with threshold
	brlo level_four				; if r24 < 128, level is 4
	rjmp level_five				; if r24 >= 128, level is 5
six_plus:
	cpi r24, 0x80				; compare r24 with threshold
	brlo level_six				; if r24 < 128, level is 6
level_seven:
	ldi r26, 0x7f				; turn on all 7 LEDs (PB0 to PB6)
	rjmp check_ppm
level_six:
	ldi r26, 0x3f				; turn on 6 LEDs (PB0 to PB5)
	rjmp check_ppm
level_five:
	ldi r26, 0x1f				; turn on 5 LEDs (PB0 to PB4)
	rjmp check_ppm
level_four:
	ldi r26, 0x0f				; turn on 4 LEDs (PB0 to PB3)
	rjmp check_ppm
level_three:
	ldi r26, 0x07				; turn on 3 LEDs (PB0 to PB2)
	rjmp check_ppm
level_two:
	ldi r26, 0x03				; turn on 2 LEDs (PB0 and PB1)
	rjmp check_ppm
level_one:
	ldi r26, 0x01				; turn on 1 LED (PB0)
	rjmp check_ppm
level_zero:
	ldi r26, 0x00				; dont turn on any LED
check_ppm:
	cpi r24, 0xce				; check if r24 >= 206 (Cx > 70)
	brsh blinking				; if it is go to blinking routine
	out PORTB, r26				; else just output the LEDs
blinking:
	

; ================================================================= ;

ADC_init:
    ldi r24,(1<<REFS0) ; Vref: Vcc
    out ADMUX,r24 ;MUX4:0 = 00000 for A0.
    ;ADC is Enabled (ADEN=1)
    ;ADC Interrupts are Enabled (ADIE=1)
    ;Set Prescaler CK/128 = 62.5Khz (ADPS2:0=111)
    ldi r24,(1<<ADEN)|(1<<ADIE)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    out ADCSRA,r24
    ret

scan_row_sim:
	out PORTC, r25              ; η αντίστοιχη γραμμή τίθεται στο λογικό ‘1’
	push r24                    ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25                    ; λειτουργία του προγράμματος απομακρυσμένης
	ldi r24,low(500)            ; πρόσβασης
    ldi r25,high(500)
	rcall wait_usec
	pop r25
	pop r24                     ; τέλος τμήμα κώδικα
	nop
	nop                         ; καθυστέρηση για να προλάβει να γίνει η αλλαγή κατάστασης
	in r24, PINC                ; επιστρέφουν οι θέσεις (στήλες) των διακοπτών που είναι πιεσμένοι
	andi r24 ,0x0f              ; απομονώνονται τα 4 LSB όπου τα ‘1’ δείχνουν που είναι πατημένοι
	ret                         ; οι διακόπτες

scan_keypad_sim:
	push r26                    ; αποθήκευσε τους καταχωρητές r27:r26 γιατί τους
	push r27                    ; αλλάζουμε μέσα στην ρουτίνα
	ldi r25 , 0x10              ; έλεγξε την πρώτη γραμμή του πληκτρολογίου (PC4: 1 2 3 A)
	rcall scan_row_sim
	swap r24                    ; αποθήκευσε το αποτέλεσμα
	mov r27, r24                ; στα 4 msb του r27
	ldi r25 ,0x20               ; έλεγξε τη δεύτερη γραμμή του πληκτρολογίου (PC5: 4 5 6 B)
	rcall scan_row_sim
	add r27, r24                ; αποθήκευσε το αποτέλεσμα στα 4 lsb του r27
	ldi r25 , 0x40              ; έλεγξε την τρίτη γραμμή του πληκτρολογίου (PC6: 7 8 9 C)
	rcall scan_row_sim
	swap r24                    ; αποθήκευσε το αποτέλεσμα
	mov r26, r24                ; στα 4 msb του r26
	ldi r25 ,0x80               ; έλεγξε την τέταρτη γραμμή του πληκτρολογίου (PC7: * 0 # D)
	rcall scan_row_sim
	add r26, r24                ; αποθήκευσε το αποτέλεσμα στα 4 lsb του r26
	movw r24, r26               ; μετέφερε το αποτέλεσμα στους καταχωρητές r25:r24
	clr r26                     ; προστέθηκε για την απομακρυσμένη πρόσβαση
	out PORTC,r26               ; προστέθηκε για την απομακρυσμένη πρόσβαση
	pop r27                     ; επανάφερε τους καταχωρητές r27:r26
	pop r26
	ret

scan_keypad_rising_edge_sim:
	push r22                    ; αποθήκευσε τους καταχωρητές r23:r22 και τους
	push r23                    ; r26:r27 γιατί τους αλλάζουμε μέσα στην ρουτίνα
	push r26
	push r27
	rcall scan_keypad_sim       ; έλεγξε το πληκτρολόγιο για πιεσμένους διακόπτες
	push r24                    ; και αποθήκευσε το αποτέλεσμα
	push r25
	ldi r24 ,15                 ; καθυστέρησε 15 ms (τυπικές τιμές 10-20 msec που καθορίζεται από τον
	ldi r25 ,0                  ; κατασκευαστή του πληκτρολογίου – χρονοδιάρκεια σπινθηρισμών)
	rcall wait_msec
	rcall scan_keypad_sim       ; έλεγξε το πληκτρολόγιο ξανά και απόρριψε
	pop r23                     ; όσα πλήκτρα εμφανίζουν σπινθηρισμό
	pop r22
	and r24 ,r22
	and r25 ,r23
	ldi r26 ,low(_tmp_)         ; φόρτωσε την κατάσταση των διακοπτών στην
	ldi r27 ,high(_tmp_)        ; προηγούμενη κλήση της ρουτίνας στους r27:r26
	ld r23 ,X+
	ld r22 ,X
	st X ,r24                   ; αποθήκευσε στη RAM τη νέα κατάσταση
	st -X ,r25                  ; των διακοπτών
	com r23
	com r22                     ; βρες τους διακόπτες που έχουν «μόλις» πατηθεί
	and r24 ,r22
	and r25 ,r23
	pop r27                     ; επανάφερε τους καταχωρητές r27:r26
	pop r26                     ; και r23:r22
	pop r23
	pop r22
	ret 

keypad_to_ascii_sim:
	push r26                    ; αποθήκευσε τους καταχωρητές r27:r26 γιατί τους
	push r27                    ; αλλάζουμε μέσα στη ρουτίνα
	movw r26 ,r24               ; λογικό ‘1’ στις θέσεις του καταχωρητή r26 δηλώνουν
	                            ; τα παρακάτω σύμβολα και αριθμούς
	ldi r24 ,'*'
                                ; r26
                                ;C 9 8 7 D # 0 *
	sbrc r26 ,0
	rjmp return_ascii
	ldi r24 ,'0'
	sbrc r26 ,1
	rjmp return_ascii
	ldi r24 ,'#'
	sbrc r26 ,2
	rjmp return_ascii
	ldi r24 ,'D'
	sbrc r26 ,3                 ; αν δεν είναι ‘1’παρακάμπτει την ret, αλλιώς (αν είναι ‘1’)
	rjmp return_ascii           ; επιστρέφει με τον καταχωρητή r24 την ASCII τιμή του D.
	ldi r24 ,'7'
	sbrc r26 ,4
	rjmp return_ascii
	ldi r24 ,'8'
	sbrc r26 ,5
	rjmp return_ascii
	ldi r24 ,'9'
	sbrc r26 ,6
	rjmp return_ascii ;
	ldi r24 ,'C'
	sbrc r26 ,7
	rjmp return_ascii
	ldi r24 ,'4'                ; λογικό ‘1’ στις θέσεις του καταχωρητή r27 δηλώνουν
	sbrc r27 ,0                 ; τα παρακάτω σύμβολα και αριθμούς
	rjmp return_ascii
	ldi r24 ,'5'
                                ;r27
                                ;Α 3 2 1 B 6 5 4
	sbrc r27 ,1
	rjmp return_ascii
	ldi r24 ,'6'
	sbrc r27 ,2
	rjmp return_ascii
	ldi r24 ,'B'
	sbrc r27 ,3
	rjmp return_ascii
	ldi r24 ,'1'
	sbrc r27 ,4
	rjmp return_ascii ;
	ldi r24 ,'2'
	sbrc r27 ,5
	rjmp return_ascii
	ldi r24 ,'3' 
	sbrc r27 ,6
	rjmp return_ascii
	ldi r24 ,'A'
	sbrc r27 ,7
	rjmp return_ascii
	clr r24
	rjmp return_ascii
return_ascii:
	pop r27                     ; επανάφερε τους καταχωρητές r27:r26
	pop r26
	ret 

write_2_nibbles_sim:
	push r24                    ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25                    ; λειτουργία του προγράμματος απομακρυσμένης
	ldi r24 ,low(6000)          ; πρόσβασης
    ldi r25 ,high(6000)
	rcall wait_usec
	pop r25
	pop r24                     ; τέλος τμήμα κώδικα
	push r24                    ; στέλνει τα 4 MSB
	in r25, PIND                ; διαβάζονται τα 4 LSB και τα ξαναστέλνουμε
	andi r25, 0x0f              ; για να μην χαλάσουμε την όποια προηγούμενη κατάσταση
	andi r24, 0xf0              ; απομονώνονται τα 4 MSB και
	add r24, r25                ; συνδυάζονται με τα προϋπάρχοντα 4 LSB
	out PORTD, r24              ; και δίνονται στην έξοδο
	sbi PORTD, PD3              ; δημιουργείται παλμός Enable στον ακροδέκτη PD3
	cbi PORTD, PD3              ; PD3=1 και μετά PD3=0
	push r24                    ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25                    ; λειτουργία του προγράμματος απομακρυσμένης
	ldi r24 ,low(6000)          ; πρόσβασης
    ldi r25 ,high(6000)
	rcall wait_usec
	pop r25
	pop r24                     ; τέλος τμήμα κώδικα
	pop r24                     ; στέλνει τα 4 LSB. Ανακτάται το byte.
	swap r24                    ; εναλλάσσονται τα 4 MSB με τα 4 LSB
	andi r24 ,0xf0              ; που με την σειρά τους αποστέλλονται
	add r24, r25
	out PORTD, r24
	sbi PORTD, PD3              ; Νέος παλμός Enable
	cbi PORTD, PD3
	ret

lcd_data_sim:
	push r24
	push r25
	sbi PORTD,PD2
	rcall write_2_nibbles_sim
	ldi r24,43
	ldi r25,0
	rcall wait_usec
	pop r25
	pop r24
	ret

lcd_command_sim:
	push r24                    ; αποθήκευσε τους καταχωρητές r25:r24 γιατί τους
	push r25                    ; αλλάζουμε μέσα στη ρουτίνα
	cbi PORTD, PD2              ; επιλογή του καταχωρητή εντολών (PD2=0)
	rcall write_2_nibbles_sim   ; αποστολή της εντολής και αναμονή 39μsec
	ldi r24, 39                 ; για την ολοκλήρωση της εκτέλεσης της από τον ελεγκτή της lcd.
	ldi r25, 0                  ; ΣΗΜ.: υπάρχουν δύο εντολές, οι clear display και return home,
	rcall wait_usec             ; που απαιτούν σημαντικά μεγαλύτερο χρονικό διάστημα.
	pop r25                     ; επανάφερε τους καταχωρητές r25:r24
	pop r24
	ret 

lcd_init_sim:
	push r24                    ; αποθήκευσε τους καταχωρητές r25:r24 γιατί τους
	push r25                    ; αλλάζουμε μέσα στη ρουτίνα

	ldi r24, 40                 ; Όταν ο ελεγκτής της lcd τροφοδοτείται με
	ldi r25, 0                  ; ρεύμα εκτελεί την δική του αρχικοποίηση.
	rcall wait_msec             ; Αναμονή 40 msec μέχρι αυτή να ολοκληρωθεί.
	ldi r24, 0x30               ; εντολή μετάβασης σε 8 bit mode
	out PORTD, r24              ; επειδή δεν μπορούμε να είμαστε βέβαιοι
	sbi PORTD, PD3              ; για τη διαμόρφωση εισόδου του ελεγκτή
	cbi PORTD, PD3              ; της οθόνης, η εντολή αποστέλλεται δύο φορές
	ldi r24, 39
	ldi r25, 0                  ; εάν ο ελεγκτής της οθόνης βρίσκεται σε 8-bit mode
	rcall wait_usec             ; δεν θα συμβεί τίποτα, αλλά αν ο ελεγκτής έχει διαμόρφωση
	                            ; εισόδου 4 bit θα μεταβεί σε διαμόρφωση 8 bit
	push r24                    ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25                    ; λειτουργία του προγράμματος απομακρυσμένης
	ldi r24,low(1000)           ; πρόσβασης
    ldi r25,high(1000)
	rcall wait_usec
	pop r25
	pop r24                     ; τέλος τμήμα κώδικα
	ldi r24, 0x30
	out PORTD, r24
	sbi PORTD, PD3
	cbi PORTD, PD3
	ldi r24,39
	ldi r25,0
	rcall wait_usec 
	push r24                    ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25                    ; λειτουργία του προγράμματος απομακρυσμένης
	ldi r24 ,low(1000)          ; πρόσβασης
    ldi r25 ,high(1000)
	rcall wait_usec
	pop r25
	pop r24                     ; τέλος τμήμα κώδικα
	ldi r24,0x20                ; αλλαγή σε 4-bit mode
	out PORTD, r24
	sbi PORTD, PD3
	cbi PORTD, PD3
	ldi r24,39
	ldi r25,0
	rcall wait_usec
	push r24                    ; τμήμα κώδικα που προστίθεται για τη σωστή
	push r25                    ; λειτουργία του προγράμματος απομακρυσμένης
	ldi r24 ,low(1000)          ; πρόσβασης
    ldi r25 ,high(1000)
	rcall wait_usec
	pop r25
	pop r24                     ; τέλος τμήμα κώδικα
	ldi r24,0x28                ; επιλογή χαρακτήρων μεγέθους 5x8 κουκίδων
	rcall lcd_command_sim       ; και εμφάνιση δύο γραμμών στην οθόνη
	ldi r24,0x0c                ; ενεργοποίηση της οθόνης, απόκρυψη του κέρσορα
	rcall lcd_command_sim
	ldi r24,0x01                ; καθαρισμός της οθόνης
	rcall lcd_command_sim
	ldi r24, low(1530)
    ldi r25, high(1530)
	rcall wait_usec
	ldi r24 ,0x06               ; ενεργοποίηση αυτόματης αύξησης κατά 1 της διεύθυνσης
	rcall lcd_command_sim       ; που είναι αποθηκευμένη στον μετρητή διευθύνσεων και
	                            ; απενεργοποίηση της ολίσθησης ολόκληρης της οθόνης
	pop r25                     ; επανάφερε τους καταχωρητές r25:r24
	pop r24
	ret

wait_msec:
    push r24                    ; 2 κύκλοι (0.250 μsec)
    push r25                    ; 2 κύκλοι
    ldi r24 , low(998)          ; φόρτωσε τον καταχ. r25:r24 με 998 (1 κύκλος - 0.125 μsec)
    ldi r25 , high(998)         ; 1 κύκλος (0.125 μsec)
    rcall wait_usec             ; 3 κύκλοι (0.375 μsec), προκαλεί συνολικά καθυστέρηση 998.375 μsec
    pop r25                     ; 2 κύκλοι (0.250 μsec)
    pop r24                     ; 2 κύκλοι
    sbiw r24 , 1                ; 2 κύκλοι
    brne wait_msec              ; 1 ή 2 κύκλοι (0.125 ή 0.250 μsec)
    ret                         ; 4 κύκλοι (0.500 μsec)

wait_usec:
    sbiw r24 ,1                 ; 2 κύκλοι (0.250 μsec)
    nop                         ; 1 κύκλος (0.125 μsec)
    nop                         ; 1 κύκλος (0.125 μsec)
    nop                         ; 1 κύκλος (0.125 μsec)
    nop                         ; 1 κύκλος (0.125 μsec)
    brne wait_usec              ; 1 ή 2 κύκλοι (0.125 ή 0.250 μsec)
    ret                         ; 4 κύκλοι (0.500 μsec)