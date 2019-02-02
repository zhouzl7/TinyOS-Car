configuration ButtonC {
    provides {
        interface Button;
    }
}

implementation {
    components ButtonP;
    components HplMsp430GeneralIOC as IOC;

    Button = ButtonP;

    ButtonP.ButtonIOA -> IOC.Port60;
    ButtonP.ButtonIOB -> IOC.Port21;
    ButtonP.ButtonIOC -> IOC.Port61;
    ButtonP.ButtonIOD -> IOC.Port23;
    ButtonP.ButtonIOE -> IOC.Port62;
    ButtonP.ButtonIOF -> IOC.Port26;
}
