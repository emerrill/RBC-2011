// Probably some code should go in here or something.

int SDIO_PIN = A4; //SDA/A4 on Arduino
int SCLK_PIN = A5; //SCL/A5 on Arduino

int FM_RST_PIN = A3;

int TX2_PIN = 7;
int RX2_PIN = 6;

int ENCODE_A_PIN = 3; //Interupt pin
int ENCODE_B_PIN = 2;

int PHOTO_1_PIN = 4; //Interupt pin
int PHOTO_2_PIN = 5;

int SERVO_PIN = 9; //Should be hardware PWM - only spot left after SPI

int SCK_PIN = 13;
int MISO_PIN = 12;
int MOSI_PIN = 11;
int SS1_PIN = 10;
int SS2_PIN = 8;

#define FM_ADDY 0x10
#define POT_1_ADDY 0x28
#define POT_1_ADDY 0x29
