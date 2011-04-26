//Modify the wire library for 400KHz - described here: http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1241668644


#include <Wire.h>
//#include <Servo.h>
#include <RogueMP3.h>
#include <NewSoftSerial.h>
#include "tracks.h"


#define FAIL  0
#define SUCCESS  1

#define DOWN  0 //Direction used for seeking. Default is down
#define UP  1

#define MOT_DOWN -1
#define MOT_STOP 0
#define MOT_UP 1
#define MOT_DRV_UP 0
#define MOT_DRV_DOWN 1
#define MOT_MAX 570 //TODO
#define MOT_DEF_SPD 170
#define MOT_MIN_SPD 140
#define MOT_MAX_SPD 200

//===================================================
//Pins and addressed
//===================================================
#define SDIO_PIN     18 //SDA/A4 on Arduino
#define SCLK_PIN     19 //SCL/A5 on Arduino

#define FM_RST_PIN   17 //A3

#define TX2_PIN      7
#define RX2_PIN      6

#define ENCODER_A_PIN 2 //Interupt pin
#define ENCODER_B_PIN 4

#define PHOTO_1_PIN  3 //Interupt pin
#define MOT_LIM_PIN  5

#define MOT_PIN      9 //Should be hardware PWM - only spot left after SPI
#define MOT_DIR_PIN  8

#define SCK_PIN      13
#define MISO_PIN     12
#define MOSI_PIN     11
#define SS1_PIN      10
#define SS2_PIN      16 //A2

#define FM_ADDY 0x10
#define POT_1_ADDY 0x28
#define POT_2_ADDY 0x29

#define IO_1_ADDY 0x26
#define IO_2_ADDY 0x27

DateCode track_table[TRACK_TABLE_MAX_SZ];
int track_table_sz;

#define MAX_ENCODER  2000
#define MIN_ENCODER  0


//===================================================
//Variables
//===================================================
uint16_t fm_registers[16];


volatile int needlePos = 0;
volatile int needleDir = UP;
volatile int encoderPos = 0;
volatile byte encoderDir = UP;
volatile int destPos = 0;

volatile byte a = LOW;
volatile byte b = LOW;

volatile int motSpeed = MOT_DEF_SPD;
volatile unsigned long motLast = 0;

volatile int currTrackIdx = -1;
volatile int newTrackIdx = -1;

volatile int pending = 0;

volatile long newYear = 0;
long curYear = 0;

//Servo servo;
NewSoftSerial mp3Serial(RX2_PIN, TX2_PIN);
RogueMP3 mp3(mp3Serial);

void setup() {
  Serial.begin(57600);
  
  //Rotary Encoder
  pinMode(ENCODER_A_PIN, INPUT);
  pinMode(ENCODER_B_PIN, INPUT);
  attachInterrupt(0, encoderChange, FALLING); 
  
  //Photo Gates
  pinMode(PHOTO_1_PIN, INPUT);
  pinMode(MOT_LIM_PIN, INPUT);
  digitalWrite(MOT_LIM_PIN, HIGH); //Set pull up
  attachInterrupt(1, needleChange, CHANGE);

  //Motor
  pinMode(MOT_PIN, OUTPUT);
  digitalWrite(MOT_PIN, LOW);
  pinMode(MOT_DIR_PIN, OUTPUT);
  digitalWrite(MOT_DIR_PIN, LOW);
  
  
  
  //FM
  fm_init();
  fm_seek(UP);
  //Wire.begin();//Temp
  display_init();
  displayYear(12345);
  
  setVolume(0, 0xaa); //FM
  setVolume(65, 0xa9); //MP3
  
  //mp3
  mp3_init();
  
  
  Serial.print("Free RAM: ");
  Serial.println(get_free_memory());
  tracks_init();
  Serial.print("Free RAM: ");
  Serial.println(get_free_memory());
  //Serial.println(mp3.getsetting('D'));
  Serial.print(track_table_sz);
  Serial.println(" tracks on the card");
  
  mp3Serial.print("ST V 30");

  mp3Serial.print("\n");
  
  calibrateMotor();

}

int trackIdx=0;

void loop() {
  
  /*Serial.print("Free RAM: ");
  Serial.println(get_free_memory());
  
  delay(250);
  //return;
  
  int val = 0;
  */
  //char c;
  
  /*if(Serial.available() > 6)
  {
    //c = Serial.read();
    //val = (int)(Serial.read() - '0') * 1000;
    val = (int)(Serial.read() - '0') * 100;
    val += (int)(Serial.read() - '0') * 10;
    val += (int)(Serial.read() - '0') * 1;
    motSpeed = val;
    Serial.print("Updating to spd ");
    Serial.print(val);
    val = (int)(Serial.read() - '0') * 100;
    val += (int)(Serial.read() - '0') * 10;
    val += (int)(Serial.read() - '0') * 1;
    
    Serial.read();
    
    destPos = val;
    
    Serial.print(" dest ");
    Serial.println(destPos);
    motLast = millis();
    updateMotor();
  }*/
  
  /*if (needleDir != MOT_STOP) {
    if ((motLast + 500) <= millis()) {
      motLast = millis();
      motorStop();
      delay(100);
      calibrateMotor();
    }
  }*/
  /*setVolume(65);
  delay(1000);
  setVolume(30);
  delay(1000);
  setVolume(10);
  delay(1000);
  setVolume(5);
  delay(1000);
  setVolume(1);
  delay(1000);
  setVolume(0);
  delay(10000);*/
  //char filename[FILE_NAME_MAX_SZ];
  /*displayYear(0);
  delay(500);
  displayYear(11111);
  delay(500);
  displayYear(22222);
  delay(500);
  displayYear(33333);
  delay(500);
  displayYear(44444);
  delay(500);
  displayYear(55555);
  delay(500);
  displayYear(66666);
  delay(500);
  displayYear(77777);
  delay(500);
  displayYear(88888);
  delay(500);
  displayYear(99999);
  delay(500);
  
  
  
  displayYear(88888);
  delay(10000);*/
  /*Serial.print("Encoder: ");
  Serial.println(encoderPos);
  //Serial.print("Needle : ");
  //Serial.println(needlePos);
  
  Serial.print("Free RAM: ");
  Serial.println(get_free_memory());

  Serial.print("play file: ");
  track_table[trackIdx].get_filename(filename);
  Serial.println(filename);
  
  play_track_idx(trackIdx);
  
  delay(5000);
  
  trackIdx++;
  trackIdx %= track_table_sz;*/
  
  if (pending == 1) {
    if (newTrackIdx != -1) {
      if (newTrackIdx == -2) {
        Serial.println("Detune");
        
        stopPlay();
        currTrackIdx = -1;
      } else {
        char filename[FILE_NAME_MAX_SZ];
    
        track_table[newTrackIdx].get_filename(filename);
        
        Serial.print("Free RAM: ");
        Serial.println(get_free_memory());
        Serial.println(filename);
        
        playTrack(newTrackIdx);
        currTrackIdx = newTrackIdx;
  
      }
      
      delay(250);
      pending = 0;
      newTrackIdx = -1;
    }
  }
  
  if (newYear != curYear) {
    displayYear(((newYear*10)+3));
    curYear = newYear;
  }
  
  delay(100);
  /*char filename[FILE_NAME_MAX_SZ];
  
  Serial.print("play file: ");
  track_table[trackIdx].get_filename(filename);
  Serial.println(filename);
  
  playTrack(trackIdx);
  
  delay(5000);
  
  trackIdx++;
  trackIdx %= track_table_sz;*/
  
}



//Interupt Service Routine for Encoder
void encoderChange() {
  a = digitalRead(ENCODER_A_PIN);
  b = digitalRead(ENCODER_B_PIN);
  
  if (b != a) {
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
  
  destPos = encoderPos;
  //Serial.println(destPos);
  updateMotor();
  
  /*
  if (pending == 0) {
    char filename[FILE_NAME_MAX_SZ];
    long yr = (int)posToYear(encoderPos);
    DateCode dc(yr);
    int idx = find_track_idx(dc);
    //track_table[idx].get_filename(filename);
  

  
    if ((currTrackIdx >= 0) && (abs(track_table[currTrackIdx] - dc) >= 3) && (newTrackIdx != -2)) {
      newTrackIdx = -2;
      
      Serial.println("Unset");
      //setVolume(0, 0xaa);
      //setVolume(65, 0xa9);
      pending = 1;
    }
    
    if (abs(track_table[idx] - dc) < 1) {
      if ((currTrackIdx != idx) && (newTrackIdx != idx)) {
        Serial.println("Set");
        //Serial.println(get_free_memory());
        //Serial.println(filename);
        newTrackIdx = idx;
        pending = 1;
        //play_track_idx(idx);
      }
    }
  }*/
  
}

//Interupt Service Routine for Photo Gate
void needleChange() {
  a = digitalRead(MOT_LIM_PIN);
  motLast = millis();
  
  needlePos += needleDir; // 1, 0, -1
  //Serial.println(needlePos);
  
  if (needlePos < 0) {
    needlePos = 0;
  }
  
  if (a == LOW) {
    needlePos = 0;
    //Serial.println("Low Limit");
    if (needleDir == MOT_DOWN) {
      //Serial.println("Mot Stop");
      motorStop();
    }
    return;
  }
  
  if (needlePos >= MOT_MAX) {
    //needlePos = MOT_MAX;
    //Serial.println("High Limit");
    if (needleDir == MOT_UP) {
      motorStop();
    }
    return;
  }
  
  long yr = (int)posToYear(needlePos);
  newYear = yr;
  
  if (pending != 1) {
    char filename[FILE_NAME_MAX_SZ];
    
    DateCode dc(yr);
    int idx = find_track_idx(dc);
    //track_table[idx].get_filename(filename);
    
    updateMotor();
    
    if ((currTrackIdx >= 0) && (abs(track_table[currTrackIdx] - dc) >= 3) && (newTrackIdx != -2)) {
      pending = 1;
      newTrackIdx = -2;
      //Serial.println("Detune");
      //setVolume(0, 0xaa);
      //setVolume(65, 0xa9);
    }
    
    if (abs(track_table[idx] - dc) < 1) {
      if ((currTrackIdx != idx) && (newTrackIdx != idx)) {
        pending = 1;
        //Serial.print("Set");
        //Serial.println(get_free_memory());
        //Serial.println(filename);
        newTrackIdx = idx;
        //play_track_idx(idx);
      }
    }
  }
  

}

void playTrack(int idx) {
  play_track_idx(idx);
  delay(250);
  setVolume(65, 0xaa);
  setVolume(0, 0xa9);
}

void stopPlay() {
  setVolume(0, 0xaa);
  setVolume(65, 0xa9);
  //mp3.stop();
}

//===================================================
//Date stuff
//===================================================
long posToYear(int pos) {
  return map((long)pos, 0, MOT_MAX, 1850, 2050);
}
//===================================================
//Motor stuff
//===================================================

void motorStop() {
  analogWrite(MOT_PIN, 0);
  needleDir = MOT_STOP;
}

void updateMotor() {
  if ((destPos == 0) && (needleDir == MOT_DOWN)) {
    if (needlePos < 0) {
      needlePos = 0;
    }
    return;
  }
  
  if ((needlePos <= (destPos + 1)) && (needlePos >= (destPos - 1))) {
    analogWrite(MOT_PIN, 0);
    needleDir = MOT_STOP;
    return;
  }
  
  if (needlePos < destPos) {
    digitalWrite(MOT_DIR_PIN, MOT_DRV_UP); 
    needleDir = MOT_UP;
    analogWrite(MOT_PIN, motSpeed); //TODO Speed
    return;
  }
  
  if (needlePos > destPos) {
    digitalWrite(MOT_DIR_PIN, MOT_DRV_DOWN);
    needleDir = MOT_DOWN;
    analogWrite(MOT_PIN, motSpeed); //TODO Speed
    return;
  }
}

void calibrateMotor() {
  a = digitalRead(MOT_LIM_PIN);
  
  if (a == LOW) {
    needlePos = 0;
    return;
  }
  
  needlePos = MOT_MAX * 2;
  destPos = 0;
  
  updateMotor();
  
}

//===================================================
//Audio pot stuff
//===================================================
void setVolume(byte vol, byte pot) {
  Wire.beginTransmission(POT_1_ADDY);
  Wire.send(pot);
  Wire.send(vol);
  
  Wire.endTransmission();
}


//===================================================
//Display Stuff
//===================================================
void displayYear(long yr) {
  int digit1 = 0;
  int digit2 = 0;
  byte out = 0;
  
  digit1 = (yr/1000) % 10;
  digit2 = (yr/100) % 10;
  
  out = digit1 << 4;
  out = out | digit2;
  //out = 0x88;
  Wire.beginTransmission(IO_1_ADDY);
  Wire.send(0x13);
  Wire.send(out);
  Wire.endTransmission();
  Serial.print(out, HEX);
  
  digit1 = (yr/10) % 10;
  digit2 = yr % 10;
  
  out = digit1 << 4;
  out = out | digit2;
  //out = 0x88;
  Wire.beginTransmission(IO_2_ADDY);
  Wire.send(0x13);
  Wire.send(out);
  Wire.endTransmission();
  
  Serial.print(out, HEX);
  
  digit1 = yr/10000;
  
  out = digit1 << 4;
  //`out = 0x88;
  Wire.beginTransmission(IO_2_ADDY);
  Wire.send(0x12);
  Wire.send(out);
  Wire.endTransmission();
  Serial.println(out, HEX);
  
}

void display_init() {
  Wire.beginTransmission(IO_1_ADDY);
  Wire.send(0x00);
  Wire.send(0x00);
  Wire.send(0x00);
  Wire.endTransmission();
  Wire.beginTransmission(IO_2_ADDY);
  Wire.send(0x00);
  Wire.send(0x00);
  Wire.send(0x00);
  Wire.endTransmission();
}




//===================================================
//MP3 Radio Stuff
//===================================================
void mp3_init() {
  mp3Serial.begin(4800);
  
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
  fm_registers[SYSCONFIG2] |= 0x0004; //Set volume to lowest
  
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
