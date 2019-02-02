module LightC {
	uses {
		interface Boot;
		interface Leds;
		interface Timer<TMilli> as LightTimer;
		interface Read<uint16_t> as LightRead;
	}
}
implementation{
	uint16_t luminance;
	uint8_t lightBool;
	event void Boot.booted(){
		call LightTimer.startPeriodic(500);
		call Leds.led0On();
	}
	event void LightTimer.fired() {
		call Leds.led2Toggle();
		if(!(call LightRead.read() == SUCCESS))
			call Leds.led0Off();
	}

	event void LightRead.readDone(error_t result, uint16_t val) {
		if(result == SUCCESS) {
			luminance = (2.5*6250.0/4096.0)*val;
			if(luminance < 30) {
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
}
