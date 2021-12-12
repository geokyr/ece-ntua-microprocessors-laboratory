#define F_CPU 800000					// frequency of atmega16
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

unsigned char memory[2], keypad[2], first, second, leds;
int correct_team, blinker;

// scan a keyboard row defined by i
unsigned char scan_row(int i) {
	unsigned char r = (1 << (i + 3));   // set r to 1 shifted row + 3
	PORTC = r;                          // r bit of PORTC is output
	_delay_us(500);                     // delay 500 us for remote
	;                                   // nop
	;                                   // nop
	return PINC & 0x0F;                 // return the 4 isolated LSBs
}

// swap 4 LSBs with 4 MSBs
unsigned char swap(unsigned char x) {
	return ((x & 0x0F) << 4) | ((x & 0xF0) >> 4);
}

// scan all the keypad rows and store result in keypad
void scan_keypad() {
	unsigned char i;

	i = scan_row(1);                    // scan 1st row (PC4)
	keypad[1] = swap(i);                // store in 4 keypad[1] MSBs

	i = scan_row(2);                    // scan 2nd row (PC5)
	keypad[1] += i;                     // store in 4 keypad[1] LSBs

	i = scan_row(3);                    // scan 3rd row (PC6)
	keypad[0] = swap(i);                // store in 4 keypad[0] MSBs

	i = scan_row(4);                    // scan 4th row (PC7)
	keypad[0] += i;                     // store in 4 keypad[0] LSBs

	PORTC = 0x00;                       // remote
}

// scan keypad the right way
int scan_keypad_rising_edge() {
	scan_keypad();                      // scan and store keypad

	unsigned char temp[2];              // temporary register
	temp[0] = keypad[0];                // store the keypad data
	temp[1] = keypad[1];                // store the keypad data

	_delay_ms(15);                      // delay 15 ms for flashover

	scan_keypad();                      // scan and store keypad

	keypad[0] &= temp[0];               // keep pressed buttons
	keypad[1] &= temp[1];               // keep pressed buttons
	
	temp[0] = memory[0];                // get old buttons from RAM
	temp[1] = memory[1];                // get old buttons from RAM

	memory[0] = keypad[0];              // store new buttons in RAM
	memory[1] = keypad[1];              // store new buttons in RAM

	keypad[0] &= ~temp[0];              // keep new pressed buttons
	keypad[1] &= ~temp[1];              // keep new pressed buttons

	return (keypad[0] || keypad[1]);    // return new pressed buttons
}

// button pressed hex to ascii
unsigned char keypad_to_ascii() {
	if (keypad[0] & 0x01) {             // check every bit and if it
		return '*';                     // is 1 return the 
	}									// corresponding ascii code
	if (keypad[0] & 0x02) {
		return '0';
	}
	if (keypad[0] & 0x04) {
		return '#';
	}
	if (keypad[0] & 0x08) {
		return 'D';
	}
	if (keypad[0] & 0x10) {
		return '7';
	}
	if (keypad[0] & 0x20) {
		return '8';
	}
	if (keypad[0] & 0x40) {
		return '9';
	}
	if (keypad[0] & 0x80) {
		return 'C';
	}
	if (keypad[1] & 0x01) {
		return '4';
	}
	if (keypad[1] & 0x02) {
		return '5';
	}
	if (keypad[1] & 0x04) {
		return '6';
	}
	if (keypad[1] & 0x08) {
		return 'B';
	}
	if (keypad[1] & 0x10) {
		return '1';
	}
	if (keypad[1] & 0x20) {
		return '2';
	}
	if (keypad[1] & 0x40) {
		return '3';
	}
	if (keypad[1] & 0x80) {
		return 'A';
	}
	return 0;                           // if none pressed return 0
}

// initialize ADC
void ADC_init(void) {
	// Vref: Vcc
	// MUX4:0 = 00000 for A0
	ADMUX = (1 << REFS0);
	// ADC is Enable (ADEN=1)
	// ADC Interrupts are Enabled (ADIE=1)
	// Set Prescaler CK/128 = 62.5Khz (ADPS2:0=111)
	ADCSRA = (1 << ADEN) | (1 << ADIE) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
}

// timer1 interruption service routine
ISR(TIMER1_OVF_vect) {
	ADCRSA |= (1 << ADSC);				// set ADSC bit to 1
	TCNT1 = 64755;						// reset the 100 ms timer
}

// update LEDs based on new ADC value
void update_leds() {
	leds &= 0x80;						// keep only PB7 
	if (ADC < 128) leds |= 0x00;		// level 0, 0 LEDs
	else if (ADC < 256) leds |= 0x01;	// level 1, 1 LED
	else if (ADC < 384) leds |= 0x03;	// level 2, 2 LEDs
	else if (ADC < 512) leds |= 0x07;	// level 3, 3 LEDs
	else if (ADC < 640) leds |= 0x0f;	// level 4, 4 LEDs
	else if (ADC < 768) leds |= 0x1f;	// level 5, 5 LEDs
	else if (ADC < 896) leds |= 0x3f;	// level 6, 6 LEDs
	else leds |= 0x7f;					// level 7, 7 LEDs
}

// ADC interruption service routine
ISR(ADC_vect) {
	update_leds();						// update LEDs

	if (correct_team) {
		PORTB = leds;					// output LEDs
		return;							// correct_team, don't alarm
	}
	if (ADC >= 206) {
		if (blinker) {
			PORTB = leds;				// output LEDs
			blinker = 0;				// // set blinker to 0
		}
		else {
			PORTB = leds &= 0x80;		// output only PB7
			blinker = 1;				// set blinker to 1
		}
	}
}

// turn on LEDs for 4 secs
void correct() {
	correct_team = 1;					// set correct_team to 1
	
	leds |= 0x80;
	PORTB = leds;                       // turn PB7 on
	for(int i = 0; i < 80; i++) {       // 4000ms divided in 80*50ms
		scan_keypad_rising_edge();      // read/ignore keypad (15ms)
		_delay_ms(35);                  // 80*50ms is 80*(15+35)
	}
	leds &= 0x7f;
	PORTB = leds;                       // turn PB7 off
	correct_team = 0;					// set correct_team to 0
}

// blink LEDs every 0.5 sec for 4 secs
void wrong() {
	for(int i = 0; i < 8; i++) {        // loop 8 times (4 on/off)
		if(i % 2) {                     // if i is odd (1, 3, 5, 7)
			leds &= 0x7f;
			PORTB = leds;               // turn PB7 off
		}
		else {                          // if i is even (0, 2, 4, 6)
			leds |= 0x80;
			PORTB = leds;               // turn PB7 on
		}

		for(int j = 0; j < 10; j++) {   // 500ms divided in 10*50ms
			scan_keypad_rising_edge();  // read/ignore keypad (15 ms)
			_delay_ms(35);              // 10*50ms is 10*(15+35)
		}
	}
}

int main(void) {
	memory[0] = 0;                  	// initialize array for RAM
	memory[1] = 0;                  	// initialize array for RAM

	ADC_init();							// initialize ADC

	TIMSK = (1 << TOIE1)				// overflow interrupt TIMER1
	TCCR1B = (1 << CS12) | (0 << CS11) | (1 << CS10);// CK/1024
	TCNT1 = 64755						// interrupt every 100 ms
	sei();								// enable interrupts

	leds = 0x00;						// initialize leds
	correct_team = 0;					// initialize correct_team
	blinker = 0;						// initialize blinker

	DDRB = 0xFF;                        // PORTB is output
	DDRC = 0xF0;                        // [7:4] output [3:0] input

	while(1) {
		while(1) {						
			if(scan_keypad_rising_edge()) {// scan for button pressed
				first = keypad_to_ascii(); // get its ascii and break
				break;					
			}
		}

		while(1) {
			if(scan_keypad_rising_edge()) {// scan for button pressed
				second = keypad_to_ascii();// get its ascii and break
				break;
			}
		}

		if(first != '3' || second != '3') {
			wrong();                    // call wrong() if wrong
		}
		else {
			correct();                  // call correct() if correct
		}
	}
	return 0;
}