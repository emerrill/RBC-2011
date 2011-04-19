#ifndef _TRACKS_H_
#define _TRACKS_H_

#define TRACK_TABLE_MAX_SZ 128
#define FILE_NAME_MAX_SZ 16

class DateCode
{
  public:
    
    union
    {
     long whole;
     struct
     {
      int low_word;
      int high_word;
     };
    } value;
    
    DateCode();
    DateCode(long);
    DateCode(int, int);
    int set_str(char *);
    void set(int, int);
    int get_filename(char *);
    bool operator>(DateCode);
    bool operator<(DateCode);
    long operator-(DateCode);
    int epoch(void);
    int year(void);
};


#endif

