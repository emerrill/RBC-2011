//Modify the wire library for 400KHz - described here: http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1241668644


#include <Wire.h>
#include <Servo.h>
#include <RogueMP3.h>
#include <NewSoftSerial.h>

#define FAIL  0
#define SUCCESS  1

#define DOWN  0 //Direction used for seeking. Default is down
#define UP  1

//===================================================
//Pins and addressed
//===================================================
#define SDIO_PIN     18 //SDA/A4 on Arduino
#define SCLK_PIN     19 //SCL/A5 on Arduino

#define FM_RST_PIN   17

#define TX2_PIN      7
#define RX2_PIN      6

#define ENCODER_A_PIN 2 //Interupt pin
#define ENCODER_B_PIN 4

#define PHOTO_1_PIN  3 //Interupt pin
#define PHOTO_2_PIN  5

#define SERVO_PIN    9 //Should be hardware PWM - only spot left after SPI

#define SCK_PIN      13
#define MISO_PIN     12
#define MOSI_PIN     11
#define SS1_PIN      10
#define SS2_PIN      8

#define FM_ADDY 0x10
#define POT_1_ADDY 0x28
#define POT_1_ADDY 0x29


#define MAX_ENCODER  2000
#define MIN_ENCODER  0


//===================================================
//Variables
//===================================================
uint16_t fm_registers[16];


volatile int needlePos = 0;
volatile byte needleDir = UP;
volatile int encoderPos = 0;
volatile byte encoderDir = UP;

volatile byte a = LOW;
volatile byte b = LOW;

Servo servo;
NewSoftSerial mp3Serial(RX2_PIN, TX2_PIN);
RogueMP3 mp3(mp3Serial);

void setup() {
  Serial.begin(57600);
  
  //Rotary Encoder
  pinMode(ENCODER_A_PIN, INPUT);
  pinMode(ENCODER_B_PIN, INPUT);
  attachInterrupt(0, encoderChange, CHANGE);
  
  //Photo Gates
  pinMode(PHOTO_1_PIN, INPUT);
  pinMode(PHOTO_2_PIN, INPUT);
  attachInterrupt(1, needleChange, FALLING);

  //Servo
  servo.attach(SERVO_PIN);
  servo.writeMicroseconds(1500); //No movement
  
  //FM
  fm_init();
  fm_seek(UP);
  
  //mp3
  mp3_init();
  
  
}

void loop() {
  delay(500);
  Serial.print("Encoder: ");
  Serial.println(encoderPos);
  //Serial.print("Needle : ");
  //Serial.println(needlePos);
  
  Serial.print("Free RAM: ");
  Serial.println(get_free_memory());
}



//Interupt Service Routine for Encoder
void encoderChange() {
  a = digitalRead(ENCODER_A_PIN);
  b = digitalRead(ENCODER_B_PIN);
  
  if (b == a) {
    encoderDir = UP;
    encoderPos++;
  } else {
    encoderDir = DOWN;
    encoderPos--;
  }
  
  if (encoderPos > MAX_ENCODER) {
    encoderDir = DOWN;
    encoderPos = MAX_ENCODER;
  }
  
  if (encoderPos < MIN_ENCODER) {
    encoderDir = UP;
    encoderPos = MIN_ENCODER;
  }
  
  
  //TODO Update motor?
  
}

//Interupt Service Routine for Photo Gate
void needleChange() {
  if (needleDir == UP) {
    needlePos++;
  } else {
    needlePos--;
  }
  //TODO calibration on PIN 2
  //TODO Update motor?
  
}



//===================================================
//MP3 Radio Stuff
//===================================================
void mp3_init() {
  mp3Serial.begin(9600);
  
  //mp3.sync();
  //mp3.stop();
  
  //TODO load files
}


//===================================================
//FM Radio Stuff
//===================================================

//Copied from SparkFun Example.
//Define the register names
#define POWERCFG  0x02
#define CHANNEL  0x03
#define SYSCONFIG1  0x04
#define SYSCONFIG2  0x05
#define SYSCONFIG3  0x06
#define STATUSRSSI  0x0A
#define READCHAN  0x0B

//Register 0x02 - POWERCFG
#define SMUTE  15
#define DMUTE  14
#define SKMODE  10
#define SEEKUP  9
#define SEEK  8


//Register 0x04 - SYSCONFIG1
#define RDS  12
#define DE  11

//Register 0x05 - SYSCONFIG2
#define SPACE1  5
#define SPACE0  4

//Register 0x0A - STATUSRSSI
#define STC  14
#define SFBL  13



void fm_init() {
  Serial.println("Initializing FM");
  
  pinMode(FM_RST_PIN, OUTPUT);
  pinMode(SDIO_PIN, OUTPUT);
  digitalWrite(SDIO_PIN, LOW); //Low to tell the radio 2-wire mode
  digitalWrite(FM_RST_PIN, LOW); //Reset FM Module
  delay(1); //Some delays while we allow pins to settle
  digitalWrite(FM_RST_PIN, HIGH); //Bring DM out of reset with SDIO set to low and SEN pulled high with on-board resistor
  delay(1);
  
  Wire.begin();
  
  fm_readRegisters(); //Read the current register set
  fm_registers[0x07] = 0x8100; //Enable the oscillator, from AN230 page 9, rev 0.61
  fm_updateRegisters(); //Update
 
  
  delay(500); //Wait for clock to settle - from AN230 page 9

  fm_readRegisters(); //Read the current register set
  fm_registers[POWERCFG] = 0x4001; //Enable the IC
  fm_registers[POWERCFG] |= 0x2000; //Set mono
  //  fm_registers[POWERCFG] |= (1<<SMUTE) | (1<<DMUTE); //Disable Mute, disable softmute
  fm_registers[SYSCONFIG1] |= (1<<RDS); //Enable RDS

  fm_registers[SYSCONFIG2] &= ~(1<<SPACE1 | 1<<SPACE0) ; //Force 200kHz channel spacing for USA

  fm_registers[SYSCONFIG2] &= 0xFFF0; //Clear volume bits
  fm_registers[SYSCONFIG2] |= 0x0001; //Set volume to lowest
  
  fm_registers[SYSCONFIG3] |= 0x0034; // Set seek to be more strict
  fm_updateRegisters(); //Update

  delay(110);
}


byte fm_updateRegisters(void) {

  Wire.beginTransmission(FM_ADDY);
  //A write command automatically begins with register 0x02 so no need to send a write-to address
  //First we send the 0x02 to 0x07 control registers
  //In general, we should not write to registers 0x08 and 0x09
  for(int regSpot = 0x02 ; regSpot < 0x08 ; regSpot++) {
    byte high_byte = fm_registers[regSpot] >> 8;
    byte low_byte = fm_registers[regSpot] & 0x00FF;

    Wire.send(high_byte); //Upper 8 bits
    Wire.send(low_byte); //Lower 8 bits
  }

  //End this transmission
  byte ack = Wire.endTransmission();
 if(ack != 0) { //We have a problem! 
    Serial.print("Write Fail:"); //No ACK!
    Serial.println(ack, DEC); //I2C error: 0 = success, 1 = data too long, 2 = rx NACK on address, 3 = rx NACK on data, 4 = other error
    return(FAIL);
  }

  return(SUCCESS);
}


//Read the entire register control set from 0x00 to 0x0F
void fm_readRegisters(void){

  //FM begins reading from register upper register of 0x0A and reads to 0x0F, then loops to 0x00.
  Wire.requestFrom(FM_ADDY, 32); //We want to read the entire register set from 0x0A to 0x09 = 32 bytes.

  while(Wire.available() < 32) ; //Wait for 16 words/32 bytes to come back from slave I2C device
  //We may want some time-out error here

  //Remember, register 0x0A comes in first so we have to shuffle the array around a bit
  for(int x = 0x0A ; ; x++) { //Read in these 32 bytes
    if(x == 0x10) x = 0; //Loop back to zero
    fm_registers[x] = Wire.receive() << 8;
    fm_registers[x] |= Wire.receive();
    if(x == 0x09) break; //We're done!
  }
}



byte fm_seek(byte seekDirection){
  fm_readRegisters();

  //Set seek mode wrap bit
  fm_registers[POWERCFG] |= (1<<SKMODE); //Allow wrap
  //fm_registers[POWERCFG] &= ~(1<<SKMODE); //Disallow wrap - if you disallow wrap, you may want to tune to 87.5 first

  if(seekDirection == DOWN) fm_registers[POWERCFG] &= ~(1<<SEEKUP); //Seek down is the default upon reset
  else fm_registers[POWERCFG] |= 1<<SEEKUP; //Set the bit to seek up

  fm_registers[POWERCFG] |= (1<<SEEK); //Start seek

  fm_updateRegisters(); //Seeking will now start

  //Poll to see if STC is set
  while(1) {
    fm_readRegisters();
    if((fm_registers[STATUSRSSI] & (1<<STC)) != 0) break; //Tuning complete!

    Serial.print("Trying station:");
    Serial.println(fm_readChannel());
  }

  fm_readRegisters();
  int valueSFBL = fm_registers[STATUSRSSI] & (1<<SFBL); //Store the value of SFBL
  fm_registers[POWERCFG] &= ~(1<<SEEK); //Clear the seek bit after seek has completed
  fm_updateRegisters();

  //Wait for the si4703 to clear the STC as well
  while(1) {
    fm_readRegisters();
    if( (fm_registers[STATUSRSSI] & (1<<STC)) == 0) break; //Tuning complete!
    Serial.println("Waiting...");
  }

  if(valueSFBL) { //The bit was set indicating we hit a band limit or failed to find a station
    Serial.println("Seek limit hit"); //Hit limit of band during seek
    return(FAIL);
  }

  Serial.println("Seek complete"); //Tuning complete!
  return(SUCCESS);
}

int fm_readChannel(void) {
  fm_readRegisters();
  int channel = fm_registers[READCHAN] & 0x03FF; //Mask out everything but the lower 10 bits


  //Freq(MHz) = 0.200(in USA) * Channel + 87.5MHz
  //X = 0.2 * Chan + 87.5
  channel *= 2; //49 * 2 = 98


  channel += 875; //98 + 875 = 973
  return(channel);
}


//===================================================
//Misc
//===================================================
extern unsigned int __bss_end;
extern unsigned int *__brkval;

int get_free_memory()
{
  int free_memory;

  if((int)__brkval == 0)
    free_memory = ((int)&free_memory) - ((int)&__bss_end);
  else
    free_memory = ((int)&free_memory) - ((int)__brkval);

  return free_memory;
}
