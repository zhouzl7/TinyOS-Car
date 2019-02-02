module ButtonP {
    uses {
        interface HplMsp430GeneralIO as ButtonIOA;
        interface HplMsp430GeneralIO as ButtonIOB;
        interface HplMsp430GeneralIO as ButtonIOC;
        interface HplMsp430GeneralIO as ButtonIOD;
        interface HplMsp430GeneralIO as ButtonIOE;
        interface HplMsp430GeneralIO as ButtonIOF;
    }

    provides {
        interface Button;
    }
}

implementation {
    task void task_start() {
        call ButtonIOA.clr();
        call ButtonIOB.clr();
        call ButtonIOC.clr();
        call ButtonIOD.clr();
        call ButtonIOE.clr();
        call ButtonIOF.clr();

        call ButtonIOA.makeInput();
        call ButtonIOB.makeInput();
        call ButtonIOC.makeInput();
        call ButtonIOD.makeInput();
        call ButtonIOE.makeInput();
        call ButtonIOF.makeInput();

        signal Button.startDone();
    }

    task void task_getButtonA() {
        signal Button.getButtonADone(call ButtonIOA.get());
    }

    task void task_getButtonB() {
        signal Button.getButtonBDone(call ButtonIOB.get());
    }

    task void task_getButtonC() {
        signal Button.getButtonCDone(call ButtonIOC.get());
    }

    task void task_getButtonD() {
        signal Button.getButtonDDone(call ButtonIOD.get());
    }

    task void task_getButtonE() {
        signal Button.getButtonEDone(call ButtonIOE.get());
    }

    task void task_getButtonF() {
        signal Button.getButtonFDone(call ButtonIOF.get());
    }

    command void Button.start() {
        post task_start();
    }

    command void Button.getButtonA() {
        post task_getButtonA();
    }

    command void Button.getButtonB() {
        post task_getButtonB();
    }

    command void Button.getButtonC() {
        post task_getButtonC();
    }

    command void Button.getButtonD() {
        post task_getButtonD();
    }

    command void Button.getButtonE() {
        post task_getButtonE();
    }

    command void Button.getButtonF() {
        post task_getButtonF();
    }
}
