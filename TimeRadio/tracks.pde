#include <NewSoftSerial.h>
#include <RogueMP3.h>
#include <limits.h>
#include "tracks.h"

#if 0
#define DEBUG_UMP3(x) Serial.println((x))
#else
#define DEBUG_UMP3(x) ;
#endif


    DateCode::DateCode(){};
    
    DateCode::DateCode(long v)
    {
      this->value.whole = v;
    }
    
    DateCode::DateCode(int y, int e)
    {
      this->set(y, e);
    }
        
    int DateCode::set_str(char * str)
    {
      int year;
      int epoch;
      
      sscanf(str, "%de%d.mp3", &year, &epoch);
    
      this->set(year, epoch);
    }
     
    void DateCode::set(int year, int epoch)
    {  
      if(year < 0)
        epoch = -epoch;

      this->value.high_word = epoch;
      this->value.low_word = year;      
    }
    
    int DateCode::get_filename(char * str)
    {
      int year, epoch;
      
      year = this->value.low_word;
      epoch = this->value.high_word;
      epoch = abs(epoch);     
      
      return sprintf(str, "%de%02d.mp3", year, epoch); 
    }
    
    bool DateCode::operator>(DateCode other)
    {
      return this->value.whole > other.value.whole;
    }

    bool DateCode::operator<(DateCode other)
    {
      return this->value.whole < other.value.whole;
    }

    long DateCode::operator-(DateCode other)
    {
      return this->value.whole - other.value.whole;
    }
    
    int DateCode::epoch()
    {
      return abs(this->value.high_word);
    }
    
    int DateCode::year()
    {
      return this->value.low_word;
    }




NewSoftSerial ump3_serial(RX2_PIN, TX2_PIN);
RogueMP3 ump3(ump3_serial);


#define LINE_BUF_SZ 64


//
//  tracks_init
//
//  Initialize the interface to the mp3 board.
//  Also populates the track table.
//
int tracks_init(void)
{
  int idx;
  long baud;
  char buf[LINE_BUF_SZ];
  char file_name[FILE_NAME_MAX_SZ];
  
  DEBUG_UMP3("tracks_init");

  while(4800 != soft_serial_auto_baud(&ump3_serial))
  {
    DEBUG_UMP3("settting baud rate to 4800");
    ump3_serial.print("STD6\r");
    delay(100);
    ump3_serial.end();
    ump3_serial.begin(4800);
  }

  idx = ump3.sync();
  DEBUG_UMP3(String("ump3.sync() ") + String(idx));
  ump3.stop();

  track_table_sz = 0;
  idx = 0;
  ump3_serial.print("FC L /\r");
  
  while(ump3_serial.peek() != '>')
  {
    idx = 0;
    
    // read the whole line
    do
    {
      while(!ump3_serial.available());
      buf[idx++] = ump3_serial.read();
    } while(buf[idx-1] != 0x0D);
    
    // replace the trailing CR with a null
    buf[idx-1] = 0;
    
    DEBUG_UMP3(String("uMP3 rx: ") + String(buf));
    //Serial.println(buf);

    if( 1 == sscanf(buf, "%*d %s", &file_name))
    {
      track_table[track_table_sz++].set_str(file_name);
    }
    
  }
  ump3_serial.read();

  return 0;
}



int find_track_idx(DateCode target)
{
  int idx;
  int closest_idx = 0;
  long diff;
  long closest_diff = LONG_MAX;
  
  // this is pretty dumb, i know.
  // but can we be sure that the table is sorted?
  for(idx=0; idx<track_table_sz; idx++)
  {
    diff = track_table[idx] - target;
    if(abs(diff) < abs(closest_diff))
    {
      closest_idx = idx;
      closest_diff = diff;
    }
  }

  return closest_idx;
}

void play_track_idx(int idx)
{

   char file_name[FILE_NAME_MAX_SZ];  
   track_table[idx].get_filename(file_name); 

   ump3.sync();
   
   ump3_serial.print("PC F /");
   ump3_serial.print(file_name);
   ump3_serial.print("\n");
   
   ump3.stop();

}

const long baud_table[]=
{
  2400,
  4800,
  9600,
  19200,
  38400,
  57600,
  115200
};
#define BAUD_TABLE_SZ (sizeof(baud_table)/sizeof(unsigned long))


long soft_serial_auto_baud(NewSoftSerial * pSerial)
{
  int idx, k;
  
  for(idx=0; idx<BAUD_TABLE_SZ; idx++)
  {
    pSerial->begin(baud_table[idx]);
    
    pSerial->print((char)0x0D); // CR
    
    for(k=0; k<10; k++)
    {
      if('>' == pSerial->read())
      {
        return baud_table[idx];
      }
      delay(10);
    }    
    
    pSerial->end();
  }
  
  return -1;
}
  
  
