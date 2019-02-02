#include <Msp430Adc12.h>

configuration JoyStickC {
    provides {
        interface Read<uint16_t> as ReadJoyStickX;
        interface Read<uint16_t> as ReadJoyStickY;
    }
}

implementation {
    components JoyStickP;
    components new AdcReadClientC() as AdcReadClientX;
    components new AdcReadClientC() as AdcReadClientY;

    ReadJoyStickX = AdcReadClientX.Read;
    ReadJoyStickY = AdcReadClientY.Read;

    AdcReadClientX.AdcConfigure -> JoyStickP.AdcConfigureX;
    AdcReadClientY.AdcConfigure -> JoyStickP.AdcConfigureY;
}
