#include <Timer.h>
#include "car.h"

configuration carAppC {
}
implementation {
    components MainC;
    components LedsC;
    components car as App;
    components new TimerMilliC() as Timer0;
	components new TimerMilliC() as Timer_delay;
    components new Msp430Uart0C() as UartC;
    components HplMsp430Usart0C;

    components ActiveMessageC;
    components new AMSenderC(AM_BLINKTORADIO);

    components new AMReceiverC(AM_BLINKTORADIO);

    App.Boot -> MainC;
    App.Leds -> LedsC;
    App.Timer0 -> Timer0;
    App.Packet -> AMSenderC;
    App.AMPacket -> AMSenderC;
    App.AMSend -> AMSenderC;
    App.AMControl -> ActiveMessageC;
    App.Receive -> AMReceiverC;

    App.Resource->UartC.Resource;
    App.HplMsp430Usart -> HplMsp430Usart0C.HplMsp430Usart;

	App.Timer_delay -> Timer_delay;
}
