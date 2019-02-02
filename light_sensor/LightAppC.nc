configuration LightAppC {
}

implementation {
	components MainC, LedsC;
	components LightC as App;
	App.Boot -> MainC;
	App.Leds -> LedsC;

	components new TimerMilliC() as LightTimer;
	App.LightTimer -> LightTimer;

	components new HamamatsuS10871TsrC() as LightSensor;
	App.LightRead -> LightSensor;
}
