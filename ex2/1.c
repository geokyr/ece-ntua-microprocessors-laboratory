#include <avr/io.h>

unsigned char A, B, C, D, notA, notB, F0, F1, answer, temp;

int main(void) {
    DDRC = 0x00;                    // input from C
    DDRB = 0xFF;                    // output at B

    while(1) {
        A = PINC & 0x01;            // keep LSB
        B = PINC & 0x02;            // keep 2nd LSB
        B = B >> 1;                 // shift it to LSB so LSB(B) = B
        C = PINC & 0x04;            // keep 3rd LSB
        C = C >> 2;                 // shift it to LSB so LSB(C) = C
        D = PINC & 0x08;            // keep 4th LSB
        D = D >> 3;                 // shift it to LSB so LSB(D) = D

        notA = A ^ 0x01;            // complement A
        notB = B ^ 0x01;            // complement B

        temp = ((notA & B) | 
                (notB & C & D));    // temp = (A'B + B'CD)
        F0 = temp ^ 0x01;           // complement temp to get F0
        
        F1 = ((A & C) & 
              (B | D));             // F1 = (AC)(B+D)
        F1 = F1 << 1;               // shift F1 to 2nd LSB
        answer = F0 + F1;           // add F1 and F0 to get output
        PORTB = answer;             // output answer at B
    }
}

/* 
   A B C D  F0 F1
   0 0 0 0  1  0
   0 0 0 1  1  0
   0 0 1 0  1  0
   0 0 1 1  0  0
   0 1 0 0  0  0
   0 1 0 1  0  0
   0 1 1 0  0  0
   0 1 1 1  0  0
   1 0 0 0  1  0
   1 0 0 1  1  0
   1 0 1 0  1  0
   1 0 1 1  0  1
   1 1 0 0  1  0
   1 1 0 1  1  0
   1 1 1 0  1  1
   1 1 1 1  1  1
*/