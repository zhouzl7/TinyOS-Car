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
#define MOTOR_RAD_DELTA (500)

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
#define CYC_PER_MSEC (TIMER_PERIOD_MILLI / 100000.0)

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

		interface Timer<TMilli> as Timer_light;
		interface Read<uint16_t> as ReadJoyStickX;
		interface Read<uint16_t> as ReadJoyStickY;
		interface Read<uint16_t> as LightRead;
		interface Button;
	}
}
implementation {
	uint16_t tcounter = 0;
	bool busy = FALSE;
	message_t pkt;
	uint8_t MOTOR_TYPE_BIT[3] = {0x01, 0x07, 0x08};

	uint8 serialdata[SERIAL_LEN] = {0x01, 0x02, 0x00, 0x00, 0x00, 0xff, 0xff, 0x00};
	uint16 delay_cnt;

	uint16_t joyX;
	uint16_t joyY;
	uint16_t btA;
    uint16_t btB;
    uint16_t btC;
    uint16_t btD;
    uint16_t btE;
	uint16_t btF;
	uint16_t luminance;
	uint8_t lightBool;
	double test_lum;
		
	void delay_ms(uint16 msec)
	{
		delay_cnt = msec;//(double)msec * CYC_PER_MSEC;
		while(delay_cnt);
	}

	event void Boot.booted() {
		call AMControl.start();
		call Timer_delay.startPeriodic( TIMER_PERIOD_MILLI  >> 3);
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
	event void Timer_light.fired() {
		call LightRead.read();
//		call Leds.led2Toggle();
	}
	
	event void Timer_delay.fired()
	{
//		call Leds.led1Toggle();
//		call Leds.led2Toggle();
		if(delay_cnt) --delay_cnt;
	}
	/*
	task void try_delay()
	{
			set_next_state(-1, 1);
			call Timer0.stop();	
			call Leds.led0On();
		//	delay_ms(30);
			call Leds.led0Off();
		//	delay_ms(30);
			call Leds.led0On();
		//	delay_ms(30);
	}
*/
  	event void Timer0.fired() 
  	{
//		call Leds.led0Toggle();
  		if (!busy)
  		{
			uint8_t i = 0;
			RadioMsg* btrpkt = (RadioMsg*)(call Packet.getPayload(&pkt, sizeof (RadioMsg)));

			call ReadJoyStickX.read();
			// call Leds.led2Toggle();

	    	//to get info. and send 
			memset(btrpkt, 0, sizeof(RadioMsg));
//			for(i = 0; i ^ 3; ++i)
//			{
				//TODO : getgpio_keys
				// setmotor(btrpkt->motors, i, 0, getapio(i, 0))
				// setmotor(btrpkt->motors, i, 1, getapio(i, 1))
				
//	    	}
			
			btA = 1 - btA;
			btB = 1 - btB;
			btC = 1 - btC;
			btD = 1 - btD;
			btE = 1 - btE;
			btF = 1 - btF;

			btD = 0;
			call Leds.led0Toggle();

			//clear_leds();

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
			

			setmotor(btrpkt->motors, 0, 0, btA);
			setmotor(btrpkt->motors, 0, 1, btB);
			setmotor(btrpkt->motors, 1, 0, btC);
			setmotor(btrpkt->motors, 1, 1, btD);
			setmotor(btrpkt->motors, 2, 0, btE);
			setmotor(btrpkt->motors, 2, 1, btF);
			
			
			call LightRead.read();
/*			if(lightBool == 1)
			{
				setmotor(btrpkt->motors, 0, 0, 1);
				setmotor(btrpkt->motors, 0, 1, 1);
				setmotor(btrpkt->motors, 1, 0, 1);
				setmotor(btrpkt->motors, 1, 1, 1);
				setmotor(btrpkt->motors, 2, 0, 1);
				setmotor(btrpkt->motors, 2, 1, 1);
				//call Leds.led1Toggle();			
			}
			if(btE)
			{
				// call Leds.led2Toggle();
			}
*/			
			// TODO: getgpio_adc
			btrpkt->movlr = -((nx_int16_t)joyX-0xB00);
			btrpkt->movfb = -((nx_int16_t)joyY-0xA00);
			//if(btrpkt->movlr > 0)
				//call Leds.led0Toggle();
			//if(btrpkt->movfb > 0)
				//call Leds.led1Toggle();
			
			if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(RadioMsg)) == SUCCESS) 
			{
				busy = TRUE;
			}
  		}
  	}

	event void LightRead.readDone(error_t result, uint16_t val) {
		if(result == SUCCESS) {
			luminance = (2.5*6250.0/4096.0)*val;
			test_lum = (2.5*6250.0/4096.0)*val;
			if(val < 5) {
//				call Leds.led1On();
				call Leds.led1On();
				lightBool = 1;
			} else {
				call Leds.led1Off();
				lightBool = 0;
			}
		} else {
			call Leds.led0Off();
		}
	}

	event void ReadJoyStickX.readDone(error_t err, uint16_t val) {
		if (err == SUCCESS) {
			joyX = val;
			call ReadJoyStickY.read();
		}
		else
		{
			call ReadJoyStickX.read();
		}
	}
	event void ReadJoyStickY.readDone(error_t err, uint16_t val) {
		if (err == SUCCESS) {
			joyY = val;
			call Button.getButtonA();
		}
		else
		{
			call ReadJoyStickY.read();
		}
	}

	 event void Button.getButtonADone(bool isHighPin) {
        btA = isHighPin;
        call Button.getButtonB();
    }

    event void Button.getButtonBDone(bool isHighPin) {
        btB = isHighPin;
        call Button.getButtonC();
    }

    event void Button.getButtonCDone(bool isHighPin) {
        btC = isHighPin;
        call Button.getButtonD();
    }

    event void Button.getButtonDDone(bool isHighPin) {
        btD = isHighPin;
        call Button.getButtonE();
    }

    event void Button.getButtonEDone(bool isHighPin) {
        btE = isHighPin;
        call Button.getButtonF();
    }

    event void Button.getButtonFDone(bool isHighPin) {
        btF = isHighPin;
        //printf("%u %u %u %u %u %u.\n", btA, btB, btC, btD, btE, btF);

    }


	event void Button.startDone() {
         call Timer0.startPeriodic(TIMER_PERIOD_MILLI >> 1);
	}

  
	event void AMControl.startDone(error_t err) {
		if (err == SUCCESS) {
		//	call Timer0.startPeriodic(TIMER_PERIOD_MILLI);		
			call Button.start();
		}
		else {
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err) {
	}


	event void AMSend.sendDone(message_t* msg, error_t error) {
		if (&pkt == msg) {
			busy = FALSE;
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) 
	{
		receive_event_end:
		return msg;
	}

}
