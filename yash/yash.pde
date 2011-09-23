/*
 YASH - Yet Another Sous-vide Hack
   Author: Peter Gebhard
   Date: September 23, 2011
   Contact: pgebhard@gmail.com
   Website: www.petergebhard.com
   Github: https://github.com/pgebhard/
   Project: https://github.com/pgebhard/arduino_projects/tree/master/yash
    
   This sketch is used as the PID controller to convert
   a Crock Pot brand Smart-Pot slow-cooker into a
   sous-vide appliance.  It allows for a temperature
   setpoint and a countdown timer to be adjusted as needed.
   When the temperature setpoint is reached, the PID algorithm
   will attempt maintain the water bath in the Crock Pot around
   that setpoint.  Once the countdown timer expires, the 
   Crock Pot will be set to OFF, and the 'Done' buzzer
   will play Pachelbel's Canon indefinitely.
 
 License:
   GNU GPL v3

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
  
 Libraries used:
   LiquidCrystal (for the output LCD)
     Library originally added 18 Apr 2008
     by David A. Mellis
     library modified 5 Jul 2009
     by Limor Fried (http://www.ladyada.net)
     Website: http://www.arduino.cc/en/Tutorial/LiquidCrystal
   PID Library
     Arduino PID Library
     Author:  Brett Beauregard
     Contact: br3ttb@gmail.com
     Website: http://www.arduino.cc/playground/Code/PIDLibrary
     Website: http://code.google.com/p/arduino-pid-library/
     License: Creative Commons Attribution-ShareAlike 3.0 Unported License
   SimpleTimer
     Arduino SimpleTimer Library
     Author:  Marcello Romani
     Contact: mromani@ottotecnica.com
     Website: http://www.arduino.cc/playground/Code/SimpleTimer
     License: GNU LGPL v2.1+
   Tone
     Arduino Tone Library
     Author:  Rogue Robotics
     Contact: http://code.google.com/p/rogue-code/
     Website: http://code.google.com/p/rogue-code/wiki/ToneLibraryDocumentation
     License: GNU GPL v3
   
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
*/

// Libraries
#include <LiquidCrystal.h>
#include <PID_v1.h>
#include <SimpleTimer.h>
#include <Tone.h>

// Control button pin settings
#define UpButton 2
#define DownButton 3
#define ModeButton 4

// Crock Pot pin settings
#define CrockSelect 5
#define CrockOff 6

// Buzzer pin setting
#define Buzzer 7

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

// Countdown time in seconds (default of 7200 seconds, or 2 hours)
int Time = 7200;

// Variables used for button handling
int UpButtonState;              // the current reading from the input pin
int lastUpButtonState = LOW;    // the previous reading from the input pin
int DownButtonState;            // the current reading from the input pin
int lastDownButtonState = LOW;  // the previous reading from the input pin
int ModeButtonState;            // the current reading from the input pin
int lastModeButtonState = LOW;  // the previous reading from the input pin
long lastUpDebounceTime = 0;    // the last time the output pin was toggled
long lastDownDebounceTime = 0;  // the last time the output pin was toggled
long lastModeDebounceTime = 0;  // the last time the output pin was toggled
long lastFastIncrementTime = 0; // the last time a fast increment occurred
long lastFastDecrementTime = 0; // the last time a fast decrement occurred
long debounceDelay = 50;        // the debounce time; increase if the output flickers
long buttonHeldDelay = 2000;    // the time that designates that a button is in a "held" state
long fastChangeDelay = 500;     // the time that designates how quickly we make fast 
                                //  increments/decrements when the button is being held

// initialize the LCD with the numbers of the interface pins
LiquidCrystal lcd(LCD_RS, LCD_E, LCD_D4, LCD_D5, LCD_D6, LCD_D7);

// initialize the PID with its variables and tuning parameters
PID pid(&Input, &Output, &Setpoint, 54, 60, 15, DIRECT);

// Timer variables
long startTime;
SimpleTimer timer;

// Count used to display number of sends to the Serial output
int serialSendCount = 0;

// Buzzer object used when playing the 'Done' buzzing
Tone buzzer;

void setup() {
  // set up the input control buttons
  pinMode(UpButton, INPUT);
  pinMode(DownButton, INPUT);
  pinMode(ModeButton, INPUT);
  
  // set up the buzzer output pin
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
  delay(2000);
  lcd.clear();
  
  // initialize PID values
  Input = TempSensorToFahren(analogRead(TempSensor));
  Setpoint = 130;
  pid.SetMode(AUTOMATIC);
  
  // set the start time used as the starting point for the countdown timer
  startTime = millis();
  
  // set up interrupts
  timer.setInterval(1000, updateLCD);
  timer.setInterval(30000, sendTemp);
  timer.setInterval(120000, zeroCrockPot);
  
  // set up the 'Done' buzzer for when it's needed
  buzzer.begin(Buzzer);
  
  // open serial connection to send back temp. data
  Serial.begin(9600);
}

void loop() {
  // if we still have time left on the countdown timer...
  if(secsLeft() > 0) {
    // read temp and compute PID output
    Input = TempSensorToFahren(analogRead(TempSensor));
    pid.Compute();
    adjustCrockPot();
  } else {
    // countdown timer is completed, turn off Crock Pot and play our buzzer indefinitely
    setCrockState(0);
    playBuzzer();
    delay(3000);
  }
  
  readInputButtons();
  
  // LCD update timer to refresh the LCD when its in a running state
  timer.run();
}

// Set Crock Pot state back to OFF
// - Used with interrupt timer to periodically clear any 
//   accidental human Crock Pot button presses
void zeroCrockPot() {
  setCrockState(0);
}

// Change the Crock Pot state based on the PID output
void adjustCrockPot() {
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

// Change the Crock Pot state
void setCrockState(int newState) {
  // Do nothing if we're attempting to change back to the same state
  if(newState == CrockState) {
    return;
  }
  
  // Set to OFF first to get to known state
  digitalWrite(CrockOff, LOW);
  delay(500);
  digitalWrite(CrockOff, HIGH);
  
  // "Press" CrockSelect button as many times as needed
  // to get to desired CrockState
  for(int i = 0; i < newState; i++) {    
    digitalWrite(CrockSelect, LOW);
    delay(500);
    digitalWrite(CrockSelect, HIGH);
  }
  
  // We reached the new state
  CrockState = newState;
}

void readInputButtons() {
 readUpButton();
 readDownButton();
 readModeButton();
}

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
    
  // whatever the reading is at, it's been there for longer
  // than the debounce delay, so take it as the actual current state
  if ((millis() - lastUpDebounceTime) > debounceDelay) {  
    // Button is read as HIGH (or "pressed")
    if(reading == HIGH) {
      // Transition from button being LOW to now being recognized as HIGH, 
      // so we perform a single increment
      if(UpButtonState == LOW) {
        UpButtonState = HIGH;
        
        // switch action based on which DisplayMode we are in
        switch(DisplayMode) {
         case 1:
           // Increment Setpoint temperature by one degree
           Setpoint += 1;
           break;
         case 2:
           // Increment Time by 60 seconds (1 minute)
           Time += 60;
           startTime = millis();
           break;
        }
        
        updateLCD();
      }
      
      // If the button is still being read as HIGH and the button has been recognized
      // in that state for longer than the buttonHeldDelay, we will perform a faster increment
      if((millis() - lastUpDebounceTime) > buttonHeldDelay && (millis() - lastFastIncrementTime) > fastChangeDelay) {
        // switch action based on which DisplayMode we are in
        switch(DisplayMode) {
         case 1:
           // Increment Setpoint temperature by 5 degrees
           Setpoint += 5;
           break;
         case 2:
           // Increment Time by 300 seconds (5 minutes)
           Time += 300;
           startTime = millis();
           break;
        }
        
        lastFastIncrementTime = millis();
        updateLCD();
      }
    }
    
    // Button is read as LOW (or "unpressed")
    if(reading == LOW) {
      UpButtonState = LOW;
    }
  }

  // save the reading.  Next time through the loop,
  // it'll be the lastButtonState
  lastUpButtonState = reading;
}

void readDownButton() {
    // read the state of the switch into a local variable
  int reading = digitalRead(DownButton);

  // check to see if you just pressed the button 
  // (i.e. the input went from LOW to HIGH),  and you've waited 
  // long enough since the last press to ignore any noise:  

  // If the switch changed, due to noise or pressing:
  if (reading != lastDownButtonState) {
    // reset the debouncing timer
    lastDownDebounceTime = millis();
  } 
  
  // whatever the reading is at, it's been there for longer
  // than the debounce delay, so take it as the actual current state
  if ((millis() - lastDownDebounceTime) > debounceDelay) {
    // Button is read as HIGH (or "pressed")
    if(reading == HIGH) {
      // Transition from button being LOW to now being recognized as HIGH, 
      // so we perform a single decrement
      if(DownButtonState == LOW) {
        DownButtonState = HIGH;
      
        // switch action based on which DisplayMode we are in
        switch(DisplayMode) {
         case 1:
           if(Setpoint >= 1) {
             // Decrement Setpoint temperature by one degree
             Setpoint -= 1;
           }
           break;
         case 2:
           if(Time >= 60) {
             // Decrement Time by 60 seconds (1 minute)
             Time -= 60;
           }
           startTime = millis();
           break;
        }
        
        updateLCD();
      }
      
      // If the button is still being read as HIGH and the button has been recognized
      // in that state for longer than the buttonHeldDelay, we will perform a faster decrement
      if((millis() - lastDownDebounceTime) > buttonHeldDelay && (millis() - lastFastDecrementTime) > fastChangeDelay) {
        // switch action based on which DisplayMode we are in
        switch(DisplayMode) {
         case 1:
           if(Setpoint >= 5) {
             // Decrement Setpoint temperature by 5 degrees
             Setpoint -= 5;
           } else {
             Setpoint = 0;
           }
           break;
         case 2:
           if(Time >= 300) {
             // Decrement Time by 300 seconds (5 minutes)
             Time -= 300;
           } else {
             Time = 0;
           }
           startTime = millis();
           break;
        }
        
        lastFastDecrementTime = millis();
        updateLCD();
      }
    }
    
    // Button is read as LOW (or "unpressed")
    if(reading == LOW) {
      DownButtonState = LOW;
    }
  }

  // save the reading.  Next time through the loop,
  // it'll be the lastButtonState:
  lastDownButtonState = reading;
}

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

  // whatever the reading is at, it's been there for longer
  // than the debounce delay, so take it as the actual current state
  if ((millis() - lastModeDebounceTime) > debounceDelay) {
    // Button is read as HIGH (or "pressed")
    // Transition from button being LOW to now being recognized as HIGH, 
    // so we perform a single Mode change
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
    
    // Button is read as LOW (or "unpressed")
    if(reading == LOW) {
     ModeButtonState = LOW; 
    }
  }

  // save the reading.  Next time through the loop,
  // it'll be the lastButtonState:
  lastModeButtonState = reading;
}

// Update the LCD output to show information for 
// whichever DisplayMode is currently selected
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
  
  // Print the Setpoint temperature
  lcd.print("Set: ");
  lcd.print((int)Setpoint);
  
  // Print current temperature
  lcd.print(" Tp: ");
  lcd.print((int)Input);
  
  // Go to second line of display
  lcd.setCursor(0, 1);
  
  // Print the time left
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
  lcd.print("Set Setpoint: ");
  lcd.setCursor(0, 1);
  lcd.print((int)Setpoint);
}

void printSetTime() {
  lcd.print("Set Time: ");
  lcd.setCursor(0, 1);
  
  // show time in minutes
  lcd.print(Time/60);
}

// Calculate how many seconds are left based on the Time variable and the measured elapsed time
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

// Plays Pachelbel's Canon on the buzzer (as the "Done" signal)
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

// Sends back current temperature sensor value over Serial for debugging purposes
void sendTemp() {
  // send back temp. data
  Serial.print(serialSendCount);
  Serial.print(" ");
  Serial.println(Input);
  serialSendCount++;
}

