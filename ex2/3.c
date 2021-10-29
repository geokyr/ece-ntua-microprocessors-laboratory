#include <avr/io.h>
#include <avr/interrupt.h>

volatile unsigned char A, B, counter, flag = 1;

ISR(INT0_vect) {
    A = PINA & 0x04;                    // keep only PA2
    B = PINB;                           // load input from B

    if(A) {                             // if PA2 is ON
        counter = 0x00;                 // initialize counter
        for (int i = 0; i < 8; i++) {   // for loop 8 times
            if(B & 0x01) {              // if LSB is 1
                counter++;              // increase counter
            }
            B = B >> 1;                 // rotate input right
        }
        PORTC = counter;                // output counter to C
    }
    else {                              // if PA2 is OFF
        counter = 0x00;                 // initialize counter
        for (int i = 0; i < 8; i++) {   // for loop 8 times
            if(B & 0x01) {              // if LSB is 1
                counter = counter << 1; // shift counter left
                counter++;              // increase counter
            }
            B = B >> 1;                 // rotate input right
        }
        PORTC = counter;                // output counter to C
    }
}

int main(void) {
    MCUCR = 0x03;                       // rising edge of INT0
    GICR = 0x40;                        // enable INT0

    DDRA = 0x00;                        // input from A
    DDRB = 0x00;                        // input from B
    DDRC = 0xFF;                        // output at C

    while(flag) {                       // infinite loop
        sei();                          // enable interrupts
    }
}