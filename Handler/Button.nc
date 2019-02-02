interface Button {
    command void start();
    event void startDone();

    command void getButtonA();
    event void getButtonADone(bool isHighPin);
    command void getButtonB();
    event void getButtonBDone(bool isHighPin);
    command void getButtonC();
    event void getButtonCDone(bool isHighPin);
    command void getButtonD();
    event void getButtonDDone(bool isHighPin);
    command void getButtonE();
    event void getButtonEDone(bool isHighPin);
    command void getButtonF();
    event void getButtonFDone(bool isHighPin);
}
