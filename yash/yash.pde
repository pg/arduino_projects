/*
  LiquidCrystal Library - display() and noDisplay()
 
 Demonstrates the use a 16x2 LCD display.  The LiquidCrystal
 library works with all LCD displays that are compatible with the 
 Hitachi HD44780 driver. There are many of them out there, and you
 can usually tell them by the 16-pin interface.
 
 This sketch prints "Hello World!" to the LCD and uses the 
 display() and noDisplay() functions to turn on and off
 the display.
 
 The circuit:
 * LCD RS pin to digital pin 8
 * LCD Enable pin to digital pin 9
 * LCD D4 pin to digital pin 10
 * LCD D5 pin to digital pin 11
 * LCD D6 pin to digital pin 12
 * LCD D7 pin to digital pin 13
 * LCD R/W pin to ground
 * 10K resistor:
 * ends to +5V and ground
 * wiper to LCD VO pin (pin 3)
 
 Library originally added 18 Apr 2008
 by David A. Mellis
 library modified 5 Jul 2009
 by Limor Fried (http://www.ladyada.net)
 example added 9 Jul 2009
 by Tom Igoe 
 modified 22 Nov 2010
 by Tom Igoe

 This example code is in the public domain.

 http://www.arduino.cc/en/Tutorial/LiquidCrystal
 */

// Libraries
#include <LiquidCrystal.h>
#include <PID_v1.h>
#include <SimpleTimer.h>
#include <Tone.h>

// Control button pin settings
#define UpButton 0
#define DownButton 1
#define ModeButton 2
#define SelectButton 3

// Crock Pot pin settings
#define CrockSelect 4
#define CrockOff 5

// Buzzer pin setting
#define Buzzer 6

// Temperature sensor pin setting
#define TempSensor 0

// LCD pin settings
#define LCD_RS 8
#define LCD_E 9
#define LCD_D4 10
#define LCD_D5 11
#define LCD_D6 12
#define LCD_D7 13

// PID variables
double Input, Output, Setpoint;

// Heat state of the Crock Pot
// 0: Off
// 1: Low
// 2: High
// 3: Keep Warm
int CrockState = 0;

// LCD Display Mode
// 0: Status
// 1: Set Temp
// 2: Set Time
int DisplayMode = 0;

// Countdown time in seconds
int Time = 7200;

// Variables will change:
int UpButtonState;             // the current reading from the input pin
int lastUpButtonState = LOW;   // the previous reading from the input pin
int DownButtonState;             // the current reading from the input pin
int lastDownButtonState = LOW;   // the previous reading from the input pin
int ModeButtonState;             // the current reading from the input pin
int lastModeButtonState = LOW;   // the previous reading from the input pin
int SelectButtonState;             // the current reading from the input pin
int lastSelectButtonState = LOW;   // the previous reading from the input pin

// the following variables are long's because the time, measured in miliseconds,
// will quickly become a bigger number than can be stored in an int.
long lastUpDebounceTime = 0;  // the last time the output pin was toggled
long lastDownDebounceTime = 0;  // the last time the output pin was toggled
long lastModeDebounceTime = 0;  // the last time the output pin was toggled
long lastSelectDebounceTime = 0;  // the last time the output pin was toggled
long debounceDelay = 50;    // the debounce time; increase if the output flickers

// initialize the LCD with the numbers of the interface pins
LiquidCrystal lcd(LCD_RS, LCD_E, LCD_D4, LCD_D5, LCD_D6, LCD_D7);

// initialize the PID with its variables and tuning parameters
PID pid(&Input, &Output, &Setpoint, 2, 5, 1, DIRECT);

long startTime;
SimpleTimer timer;

Tone buzzer;

void setup() {
  // set up the input control buttons
  pinMode(UpButton, INPUT);
  pinMode(DownButton, INPUT);
  pinMode(ModeButton, INPUT);
  pinMode(SelectButton, INPUT);
  
  pinMode(Buzzer, OUTPUT);
  
  // set up the crock pot outputs
  pinMode(CrockSelect, OUTPUT);
  pinMode(CrockOff, OUTPUT);
  digitalWrite(CrockSelect, HIGH);
  digitalWrite(CrockOff, HIGH);
  setCrockState(0);
  
  // set up the LCD's number of columns and rows: 
  lcd.begin(16, 2);
  
  // print a welcome message to the LCD.
  lcd.print("Welcome to YASH");
  lcd.setCursor(0, 1);
  lcd.print("Sylvia & Peter");
  delay(3000);
  lcd.clear();
  
  // initialize PID values
  Input = TempSensorToFahren(analogRead(TempSensor));
  Setpoint = 105;
  pid.SetMode(AUTOMATIC);
  startTime = millis();
  updateLCD();
  
  timer.setInterval(1000, updateLCD);
  
  buzzer.begin(Buzzer);
}

void loop() {
  if(secsLeft() > 0) {
    // read temp and compute PID output
    Input = TempSensorToFahren(analogRead(TempSensor));
    pid.Compute();
    adjustCrockPot(Output);
  } else {
    // turn off Crock Pot
    setCrockState(0);
    playBuzzer();
    delay(3000);
  }
  
  readInputButtons();
  
  // LCD update timer to refresh the LCD when its in a running state
  timer.run();
}

void playBuzzer() {
  buzzer.play(NOTE_FS6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_E6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_D6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_CS6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_B6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_A6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_B6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_CS6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_D6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_CS6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_B6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_A6);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_G5);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_FS5);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_G5);
  delay(1000);
  buzzer.stop();
  buzzer.play(NOTE_E5);
  delay(1000);
  buzzer.stop();
  delay(3000);
  buzzer.play(NOTE_C7);
  delay(3000);
  buzzer.stop();
}

void adjustCrockPot(double Output) {
  if(Output <= 60) {
   setCrockState(0);
  } else if(Output > 60 && Output <= 120) {
    setCrockState(3);
  } else if(Output > 120 && Output <= 200) {
    setCrockState(1); 
  } else {
    setCrockState(2); 
  }
}

void setCrockState(int newState) {
  // do nothing if we're attempting to change back to the same state
  if(newState == CrockState) {
    return;
  }
  
  // Set to OFF
  if(newState == 0) {
    digitalWrite(CrockOff, LOW);
    delay(500);
    digitalWrite(CrockOff, HIGH);
  } else {
    int presses = 0;
    
    if(newState < CrockState) {
      presses = 3 - (CrockState - newState);
    } else {
      presses = newState - CrockState;
    }
    
    for(int i = 0; i < presses; i++) {    
      digitalWrite(CrockSelect, LOW);
      delay(500);
      digitalWrite(CrockSelect, HIGH);
    }
  }
  
  // We reached the new state
  CrockState = newState;
}

void readInputButtons() {
 //readUpButton();
 readDownButton();
 readModeButton();
 readSelectButton();
}

// Read debounced Up button
void readUpButton() {
    // read the state of the switch into a local variable:
  int reading = digitalRead(UpButton);

  // check to see if you just pressed the button 
  // (i.e. the input went from LOW to HIGH),  and you've waited 
  // long enough since the last press to ignore any noise:  

  // If the switch changed, due to noise or pressing:
  if (reading != lastUpButtonState) {
    // reset the debouncing timer
    lastUpDebounceTime = millis();
  } 
  
  if ((millis() - lastUpDebounceTime) > debounceDelay) {
    // whatever the reading is at, it's been there for longer
    // than the debounce delay, so take it as the actual current state:
    if(reading == HIGH && UpButtonState == LOW) {
      UpButtonState = HIGH;
      
      // switch action based on which DisplayMode we are in
      switch(DisplayMode) {
       case 1:
         Setpoint += 5;
         break;
       case 2:
         Time += 300;
         startTime = millis();
         break;
      }
      
      updateLCD();
    }
    if(reading == LOW) {
      UpButtonState = LOW;
    }
  }

  // save the reading.  Next time through the loop,
  // it'll be the lastButtonState:
  lastUpButtonState = reading;
}

// Read debounced Up button
void readDownButton() {
    // read the state of the switch into a local variable:
  int reading = digitalRead(DownButton);

  // check to see if you just pressed the button 
  // (i.e. the input went from LOW to HIGH),  and you've waited 
  // long enough since the last press to ignore any noise:  

  // If the switch changed, due to noise or pressing:
  if (reading != lastDownButtonState) {
    // reset the debouncing timer
    lastDownDebounceTime = millis();
  } 
  
  if ((millis() - lastDownDebounceTime) > debounceDelay) {
    // whatever the reading is at, it's been there for longer
    // than the debounce delay, so take it as the actual current state:
    if(reading == HIGH && DownButtonState == LOW) {
      DownButtonState = HIGH;
      
      // switch action based on which DisplayMode we are in
      switch(DisplayMode) {
       case 1:
         if(Setpoint >= 5) {
           Setpoint -= 5;
         }
         break;
       case 2:
         if(Time >= 300) {
           Time -= 300;
         }
         startTime = millis();
         break;
      }
      
      updateLCD();
    }
    if(reading == LOW) {
     DownButtonState = LOW; 
    }
  }

  // save the reading.  Next time through the loop,
  // it'll be the lastButtonState:
  lastDownButtonState = reading;
}

// Read debounced Up button
void readModeButton() {
    // read the state of the switch into a local variable:
  int reading = digitalRead(ModeButton);

  // check to see if you just pressed the button 
  // (i.e. the input went from LOW to HIGH),  and you've waited 
  // long enough since the last press to ignore any noise:  

  // If the switch changed, due to noise or pressing:
  if (reading != lastModeButtonState) {
    // reset the debouncing timer
    lastModeDebounceTime = millis();
  } 
  
  if ((millis() - lastModeDebounceTime) > debounceDelay) {
    // whatever the reading is at, it's been there for longer
    // than the debounce delay, so take it as the actual current state:
    if(reading == HIGH && ModeButtonState == LOW) {
      ModeButtonState = HIGH;
      
      // increment display mode due to Mode button press
      if(DisplayMode == 2) {
        DisplayMode = 0;
      } else {
        DisplayMode++;
      }
      
      updateLCD();
    }
    if(reading == LOW) {
     ModeButtonState = LOW; 
    }
  }

  // save the reading.  Next time through the loop,
  // it'll be the lastButtonState:
  lastModeButtonState = reading;
}

// Read debounced Up button
void readSelectButton() {
    // read the state of the switch into a local variable:
  int reading = digitalRead(SelectButton);

  // check to see if you just pressed the button 
  // (i.e. the input went from LOW to HIGH),  and you've waited 
  // long enough since the last press to ignore any noise:  

  // If the switch changed, due to noise or pressing:
  if (reading != lastSelectButtonState) {
    // reset the debouncing timer
    lastSelectDebounceTime = millis();
  } 
  
  if ((millis() - lastSelectDebounceTime) > debounceDelay) {
    // whatever the reading is at, it's been there for longer
    // than the debounce delay, so take it as the actual current state:
    if(reading == HIGH && SelectButtonState == LOW) {
      SelectButtonState = HIGH;
      lcd.print("3");
    }
    if(reading == LOW) {
      SelectButtonState = LOW;
    }
  }

  // save the reading.  Next time through the loop,
  // it'll be the lastButtonState:
  lastSelectButtonState = reading;
}

void updateLCD() {
   // clear LCD for new mode to be displayed
  lcd.clear();
  
  // switch LCD output to match selected Display Mode
  switch(DisplayMode) {
   case 0:
     printStatus();
     break;
   case 1: 
     printSetSetpoint();
     break;
   case 2: 
     printSetTime();
     break;
  } 
}

void printStatus() {
  int timeLeft = secsLeft();  
  int hoursLeft = timeLeft / 3600;
  timeLeft = timeLeft % 3600;
  int minsLeft = timeLeft / 60;
  int secsLeft = timeLeft % 60;
  lcd.print("Set: ");
  lcd.print((int)Setpoint);
  lcd.print(" Tp: ");
  lcd.print((int)Input);
  lcd.setCursor(0, 1);
  lcd.print("Time: ");
  if(hoursLeft < 10) {
    lcd.print("0");
  }
  lcd.print(hoursLeft);
  lcd.print(":");
  if(minsLeft < 10) {
    lcd.print("0");
  }
  lcd.print(minsLeft);
  lcd.print(":");
  if(secsLeft < 10) {
    lcd.print("0");
  }
  lcd.print(secsLeft);
}

void printSetSetpoint() {
  lcd.print("Choose Setpoint: ");
  lcd.setCursor(0, 1);
  lcd.print((int)Setpoint);
}

void printSetTime() {
  lcd.print("Choose Time: ");
  lcd.setCursor(0, 1);
  
  // show time in minutes
  lcd.print(Time/60);
}

// calculate how many minutes are left based on the set Time and the measured elapsed time
int secsLeft() {
  int tempTime = Time;
  
  // calculate the elapsed milliseconds, and then convert to number of seconds elapsed
  tempTime -= (millis() - startTime) / 1000;
  
  if(tempTime < 0) {
    return 0;
  } else {
    return tempTime;
  }
}

// Convert analog value from temp. sensor into Fahrenheit temp. value
float TempSensorToFahren(float analogVal) {
  // 5/1023 is the ratio of volts to analog pin value
  // multiply by 100 to scale sensor mV/K output
  // subtract 273.15 to convert Kelvin to Celsius
  // multiply by 9/5 and add 32 to convert Celsius to Fahrenheit
  // ex.  2.95V from sensor is about 72degF
  return ((((0.004888 * analogVal) * 100.0) - 273.15) * 1.87) + 32.0;
}

