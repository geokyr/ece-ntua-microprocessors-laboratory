#include <avr/io.h>
#include <avr/interrupt.h>

volatile unsigned char A, B, counter, flag = 0x01;

ISR(INT0_vect) {
    A = PINA & 0x04;
    B = PINB;

    if(A) {
        counter = 0x00;
        for (int i = 0; i < 8; i++) {
            if(B & 0x01) {
                counter++;
            }
            B = B >> 1;
        }
        PORTC = counter;
    }
    else {
        counter = 0x00;
        for (int i = 0; i < 8; i++) {
            if(B & 0x01) {
                counter = counter << 1;
                counter++;
            }
            B = B >> 1;
        }
        PORTC = counter;
    }
}

int main(void) {
    MCUCR = 0x03;           // rising edge of INT0
    GICR = 0x40;            // enable INT0

    DDRA = 0x00;            // input from A
    DDRB = 0x00;            // input from B
    DDRC = 0xFF;            // output at C

    while(flag) {           // infinite loop
        sei();              // enable interrupts
    }
}