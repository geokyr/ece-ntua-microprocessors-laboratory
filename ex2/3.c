#include <avr/io.h>
#include <avr/interrupt.h>

volatile unsigned char PA, PB, counter, flag = 0x01;

ISR(INT0_vect) {
    PA = PINA & 0x04;
    PB = PINB;

    if(PA) {
        counter = 0x00;
        for (int i = 0; i < 8; i++) {
            if(PB & 0x01) {
                counter++;
            }
            PB = PB >> 1;
        }
        PORTC = counter;
    }
    else {
        counter = 0x00;
        for (int i = 0; i < 8; i++) {
            if(PB & 0x01) {
                counter = counter << 1;
                counter++;
            }
            PB = PB >> 1;
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