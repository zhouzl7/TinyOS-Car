#ifndef CAR_H
#define CAR_H

enum {
	AM_BLINKTORADIO = 6,
	TIMER_PERIOD_MILLI = 250,
	N_MOTOR = 3,
	SERIAL_LEN = 8
};


typedef nx_struct RadioMsg {
	nx_uint16_t motors; // the kth key: 
	nx_int16_t movfb;
	nx_int16_t movlr;
} RadioMsg;

typedef nx_struct SerialMsg {
	nx_uint8_t data[SERIAL_LEN];
}SerialMsg;

#endif

