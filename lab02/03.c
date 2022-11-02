#include <avr/io.h>
#include <avr/interrupt.h>

volatile unsigned char A, B, counter, flag = 1;

ISR(INT0_vect) {
    A = PINA & 0x04;                    // keep only PA2
    B = PINB;                           // load input from B

    counter = 0x00;                     // initialize counter
    if(A) {                             // if PA2 is ON
        for (int i = 0; i < 8; i++) {   // for loop 8 times
            if(B & 0x01) {              // if LSB is 1
                counter++;              // increase counter
            }
            B = B >> 1;                 // rotate input right
        }
    }
    else {                              // if PA2 is OFF
        for (int i = 0; i < 8; i++) {   // for loop 8 times
            if(B & 0x01) {              // if LSB is 1
                counter = counter << 1; // shift counter left
                counter++;              // increase counter
            }
            B = B >> 1;                 // rotate input right
        }
    }
    PORTC = counter;                    // output counter to C
}

int main(void) {
    MCUCR = (1 << ISC01) | (1 << ISC00);// rising edge of INT0
    GICR = (1 << INT0);                 // enable INT0

    DDRA = 0x00;                        // input from A
    DDRB = 0x00;                        // input from B
    DDRC = 0xFF;                        // output at C

    sei();                              // enable interrupts

    while(1) {                          // infinite loop
        flag = 1                        // just an operation
    }
}