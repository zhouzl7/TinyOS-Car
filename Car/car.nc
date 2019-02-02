#include <Timer.h>
#include "car.h"

#define uint16 uint16_t
#define int16 int16_t
#define uint8 uint8_t
//k: motor_id y:0 dec 1 inc  2 clear
#define setmotor(x, k, y, b) ((x) |= ((((b) << (y)) & 0x3) << ((k) << 1))) 
#define getmotor(x, k) (((x) >> ((k) << 1)) & 0x3)
#define MAX_MOTOR_ANGLE (5000)
#define MIN_MOTOR_ANGLE (1800)
#define timmer_frq (6) /* 2^k per sec*/
#define FULL_ANGLE_TIME (2) /*2^k sec*/
// #define MOTOR_RAD_DELTA ((MAX_MOTOR_ANGLE >> FULL_ANGLE_TIME) >> timmer_frq)
#define MOTOR_RAD_DELTA (400)

#define MAX_SPEED (800)
#define MAX_MOV_VAL (0x80) 
#define SPEED_delta ((double)MAX_SPEED / MAX_MOV_VAL)
#define MOV_VAL_ST (0x200)
#define ABS_WITHIN(a, st) (((st) > (a)) && (a) > (-st))
#define ABS_OUTOF(a, st) (((st) < (a)) || (a) < (-st))
#define FILL_SERIAL_DATA(type, data16) \
{	\
	serialdata[2] = (type); \
	serialdata[3] = (uint8)((data16) >> 8 ) & 0xff; \
	serialdata[4] = (uint8)((data16) & 0xff); \
}
//maxspeed * /movval 
//10000000

#define OP_FORWORD (0x02) 
#define OP_BACKWORD (0x03) 
#define OP_LEFT (0X04)
#define OP_RIGHT (0x05)
#define OP_STOP (0X06)

#define STAT_PRE 0
#define STAT_FORWARD 1
#define STAT_BACKWARD 2
#define STAT_LEFT 3
#define STAT_RIGHT 4
#define STAT_MOTOR1_MIN 5
#define STAT_MOTOR1_MAX 6
#define STAT_MOTOR2_MIN 7
#define STAT_MOTOR2_MAX 8
#define STAT_MOTOR0_MIN 9
#define STAT_MOTOR0_MAX 10
#define STAT_COMMAND 11
#define STAT_STOP 12
#define STAT_MOTOR0 13
#define STAT_MOTOR1 14
#define STAT_MOTOR2 15
#define STAT_COMMAND_DONE 16
#define CYC_PER_MSEC (2000 / TIMER_PERIOD_MILLI)

module car {
	uses {
		interface Boot;
		interface Leds;
		interface Timer<TMilli> as Timer0;
		interface Timer<TMilli> as Timer_delay;
		interface Packet;
		interface AMPacket;
		interface AMSend;
		interface SplitControl as AMControl;
		interface Receive;

		interface Resource;
		interface HplMsp430Usart;
	}
}
implementation {
	uint16_t tcounter = 0;
	bool busy = FALSE;
	message_t pkt;
	uint8_t MOTOR_TYPE_BIT[3] = {0x01, 0x07, 0x08};

	uint8 serialdata[SERIAL_LEN] = {0x01, 0x02, 0x00, 0x00, 0x00, 0xff, 0xff, 0x00};
	uint16 delay_cnt;

	uint8 stat = STAT_PRE;
	uint16 stat_cnt = 0;

	uint16 motor_angle[3] = {MIN_MOTOR_ANGLE, MIN_MOTOR_ANGLE, MIN_MOTOR_ANGLE};
		
	void delay_ms(uint16 msec)
	{
		delay_cnt = msec;//(double)msec * CYC_PER_MSEC;
		while(delay_cnt);
	}
		
	void set_next_state(uint8 state, double msec)
	{
		stat = state;
		stat_cnt = msec * CYC_PER_MSEC;
	}

	event void Boot.booted() {
		call AMControl.start();
		call Timer_delay.startPeriodic( TIMER_PERIOD_MILLI  >> 3);
		call Timer0.startPeriodic( TIMER_PERIOD_MILLI >> 1 );
	}

	msp430_uart_union_config_t msp430_uart_config = {{
		ubr : UBR_1MHZ_115200, // Baud rate (use enum msp430_uart_rate_t in msp430usart.h for predefined rates)
		umctl : UMCTL_1MHZ_115200, // Modulation (use enum msp430_uart_rate_t in msp430usart.h for predefined rates)
		ssel : 0x02, // Clock source (00=UCLKI; 01=ACLK; 10=SMCLK; 11=SMCLK)
		pena : 0, // Parity enable (0=disabled; 1=enabled)
		pev : 0, // Parity select (0=odd; 1=even)
		spb : 0, // Stop bits (0=one stop bit; 1=two stop bits)
		clen : 1, // Character length (0=7-bit data; 1=8-bit data)
		listen : 0, // Listen enable (0=disabled; 1=enabled, feed tx back to receiver)
		mm : 0, // Multiprocessor mode (0=idle-line protocol; 1=address-bit protocol)
		ckpl : 0, // Clock polarity (0=normal; 1=inverted)
		urxse : 0, // Receive start-edge detection (0=disabled; 1=enabled)
		urxeie : 1, // Erroneous-character receive (0=rejected; 1=recieved and URXIFGx set)
		urxwie : 0, // Wake-up interrupt-enable (0=all characters set URXIFGx; 1=only address sets URXIFGx)
		utxe : 1, // 1:enable tx module
		urxe : 1	// 1:enable rx module   
	}};

	void clear_leds()
	{
		call Leds.led0Off();
		call Leds.led1Off();
		call Leds.led2Off();
	}
	

	void set_leds(int k)
	{
		clear_leds();
		if(k&1) 
			call Leds.led0On();
		if(k&2)
			call Leds.led1On();
		if(k&4)
			call Leds.led2On();
	}
	
	event void Resource.granted() {
		uint8_t i=0;
		call HplMsp430Usart.setModeUart(&msp430_uart_config);
		call HplMsp430Usart.enableUart();
		atomic U0CTL &= ~SYNC;
		for(i=0;i<8;i++) {
			while(!(call HplMsp430Usart.isTxEmpty()));
			call HplMsp430Usart.tx(serialdata[i]);
			while(!(call HplMsp430Usart.isTxEmpty()));
		}
		call Resource.release();
	}

	event void Timer_delay.fired()
	{
		if(delay_cnt) --delay_cnt;
	}
	
  	event void Timer0.fired() 
  	{
		if(stat == STAT_PRE)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_FORWARD, 3);
			FILL_SERIAL_DATA(OP_FORWORD, 500);
			call Resource.request();
		}
		else if(stat == STAT_FORWARD)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_BACKWARD, 3);
			FILL_SERIAL_DATA(OP_BACKWORD, 500);
			call Resource.request();		
		}
		else if(stat == STAT_BACKWARD)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_LEFT, 3);
			FILL_SERIAL_DATA(OP_LEFT, 500);
			call Resource.request();
		}
		else if(stat == STAT_LEFT)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_RIGHT, 3);
			FILL_SERIAL_DATA(OP_RIGHT, 500);
			call Resource.request();
		}
		else if(stat == STAT_RIGHT)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_STOP, 0.6);
			FILL_SERIAL_DATA(OP_STOP, 0);
			call Resource.request();
		}
		else if(stat == STAT_STOP)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_MOTOR0_MIN, 1);
			FILL_SERIAL_DATA(MOTOR_TYPE_BIT[0], MIN_MOTOR_ANGLE);
			call Resource.request();
		}
		else if(stat == STAT_MOTOR0_MIN)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_MOTOR0_MAX, 1);		
			FILL_SERIAL_DATA(MOTOR_TYPE_BIT[0], MAX_MOTOR_ANGLE);
			call Resource.request();
		}
		else if(stat == STAT_MOTOR0_MAX)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_MOTOR1_MIN, 1);
			FILL_SERIAL_DATA(MOTOR_TYPE_BIT[1], MIN_MOTOR_ANGLE);
			call Resource.request();
		}
		else if(stat == STAT_MOTOR1_MIN)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_MOTOR1_MAX, 1);
			FILL_SERIAL_DATA(MOTOR_TYPE_BIT[1], MAX_MOTOR_ANGLE);
			call Resource.request();
		}
		else if(stat == STAT_MOTOR1_MAX)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_MOTOR2_MIN, 1);
			FILL_SERIAL_DATA(MOTOR_TYPE_BIT[2], MIN_MOTOR_ANGLE);
			call Resource.request();
		}
		else if(stat == STAT_MOTOR2_MIN)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_MOTOR2_MAX, 1);
			FILL_SERIAL_DATA(MOTOR_TYPE_BIT[2], MAX_MOTOR_ANGLE);
			call Resource.request();
		}
		else if(stat == STAT_MOTOR2_MAX)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_COMMAND, 1);
			FILL_SERIAL_DATA(OP_STOP, 0);
			call Resource.request();
		}

		else if(stat == STAT_MOTOR0)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_MOTOR1, 1);
			FILL_SERIAL_DATA(MOTOR_TYPE_BIT[0], MAX_MOTOR_ANGLE);
			call Resource.request();
		}
		else if(stat == STAT_MOTOR1)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_MOTOR2, 1);
			FILL_SERIAL_DATA(MOTOR_TYPE_BIT[1], MAX_MOTOR_ANGLE);
			call Resource.request();
		}
		else if(stat == STAT_MOTOR2)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_COMMAND, 1);
			FILL_SERIAL_DATA(MOTOR_TYPE_BIT[2], MAX_MOTOR_ANGLE);
			call Resource.request();
		}
		else if(stat == STAT_COMMAND)
		{
			if(stat_cnt)
			{
				--stat_cnt;
				goto timmer0_end;
			}
			set_next_state(STAT_COMMAND_DONE, 1);
		}

		timmer0_end:
			return ;
  	}
  
	event void AMControl.startDone(error_t err) {
		if (err == SUCCESS) {
		}
		else {
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err) {
	}


	event void AMSend.sendDone(message_t* msg, error_t error) {
	}

	void increase_motor(uint8 i)
	{
		uint16 angle = motor_angle[i] + MOTOR_RAD_DELTA;
		if(angle > MAX_MOTOR_ANGLE) 
			return ;
		motor_angle[i] = angle;
		FILL_SERIAL_DATA(MOTOR_TYPE_BIT[i], angle)
		call Resource.request();
	}

	void decrease_motor(uint8 i)
	{
		uint16 angle = motor_angle[i] - MOTOR_RAD_DELTA;
		if(angle < MIN_MOTOR_ANGLE) 
			return ;
		motor_angle[i] = angle;
		FILL_SERIAL_DATA(MOTOR_TYPE_BIT[i], angle)
		call Resource.request();
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) 
	{
		if(stat == STAT_COMMAND_DONE)
		{
			if (len == sizeof(RadioMsg)) 
			{
				uint8 motor_status = 0;
				uint8 i, otfb, otlr;
				uint16* pmotorangles;
				RadioMsg* btrpkt = (RadioMsg*)payload;
				uint16 motors = btrpkt->motors;
				int16 movfb = btrpkt->movfb;
				int16 movlr = btrpkt->movlr;
			
				uint8 btA, btB, btC, btD, btE, btF, btz;
				btA = getmotor(motors, 0) & 1;
				btB = (getmotor(motors, 0) & 2) >> 1;
				btC = getmotor(motors, 1) & 1;
				btD = (getmotor(motors, 1) & 2) >> 1;
				btE = getmotor(motors, 2) & 1;
				btF = (getmotor(motors, 2) & 2) >> 1;
				btz = (btA << 2) | (btB << 1) | btF;

			clear_leds();
//			set_leds(btz);
/*
			if(btA)
			{
				set_leds(1);
			}
			if(btB)
			{
				set_leds(2);
			}

			if(btC)
			{
				set_leds(3);
			}
			if(btD)
			{
				set_leds(4);
			}
			if(btE)
			{
				set_leds(5);
			}
			if(btF)
			{
				set_leds(6);
			}
			
*/
				switch(btz)
				{
					case 0:
						break;
					case 1:
						set_leds(5);
						increase_motor(0);
						goto receive_event_end;
						break;
					case 2:
						set_leds(5);
						decrease_motor(0);
						goto receive_event_end;
						break;
					case 3:
						set_leds(6);
						increase_motor(1);
						goto receive_event_end;
						break;
					case 4:
						set_leds(6);
						decrease_motor(1);
						goto receive_event_end;
						break;
					case 5:
						set_leds(7);
						increase_motor(2);
						goto receive_event_end;
						break;
					case 6:
						set_leds(7);
						decrease_motor(2);
						goto receive_event_end;
						break;
					case 7:
						set_next_state(STAT_MOTOR0, 1);				
						motor_angle[0] = motor_angle[1] = motor_angle[2] = MAX_MOTOR_ANGLE;
						FILL_SERIAL_DATA(MOTOR_TYPE_BIT[0], MAX_MOTOR_ANGLE);
						call Resource.request();
						goto receive_event_end;			
						break;
					default:
						break;
				}
			
				//check fb
				if((otfb = ABS_OUTOF(movfb, MOV_VAL_ST)))
				{
					if(movfb > 0)
					{
						set_leds(1);
						//FILL_SERIAL_DATA(OP_FORWORD, (uint16)((double)movfb * SPEED_delta))
						FILL_SERIAL_DATA(OP_FORWORD, 1000)
					}				
					else
					{
						set_leds(2);
						//FILL_SERIAL_DATA(OP_BACKWORD, (uint16)((double)-movfb * SPEED_delta))
						FILL_SERIAL_DATA(OP_BACKWORD, 1000)
					}
			  		call Resource.request();
					goto receive_event_end;

				}
				//check LR
				if((otlr = ABS_OUTOF(movlr, MOV_VAL_ST)))
				{
					//TODO: sento serial  
					if(movlr > 0)
					{
						set_leds(3);
						//FILL_SERIAL_DATA(OP_LEFT, (uint16)((double)movfb * SPEED_delta))
						FILL_SERIAL_DATA(OP_LEFT, 800)
					}					
					else
					{
						set_leds(4);
						//FILL_SERIAL_DATA(OP_RIGHT, (uint16)((double)-movfb * SPEED_delta))
						FILL_SERIAL_DATA(OP_RIGHT, 800)
					}
			  		call Resource.request();
					goto receive_event_end;
				}

				if(!(otfb | otlr))
				{
					//TODO: sendto serial
			
					set_leds(0);
					FILL_SERIAL_DATA(OP_STOP, 0);

			  		call Resource.request();
					goto receive_event_end;

					//stop
				}

			}	 
		}
		receive_event_end:
		return msg;
	}

}
