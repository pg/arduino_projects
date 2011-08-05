/* 
 tempsense
 
 Basic temperature sensor providing current, max, and min Fahrenheit temperature 
 values across serial link (or LiquidCrystal display).  
 
 Using the LiquidCrystal display library to output to a 16x2 LCD display with a 
 Hitachi HD44780 driver.
 
 The circuit:
 * Temperature sensor attached to analog pin 0
 * LCD RS pin to digital pin 12
 * LCD Enable pin to digital pin 11
 * LCD D4 pin to digital pin 5
 * LCD D5 pin to digital pin 4
 * LCD D6 pin to digital pin 3
 * LCD D7 pin to digital pin 2
 * LCD R/W pin to ground
 
 created 19 March 2011
 by Peter Gebhard
 
 */
 
#include <LiquidCrystal.h>

#define TEMP 0

// Variables will change:
int tempPinVal = 0;      // analog pin value read from tempPin
int oldTempPinVal = 0;   // old analog pin value read from tempPin
float tempVal = 0;       // the current temperature value calculated from the tempPinVal
float tempMax = -9000;   // Maximum temperature that has been measured (initialized to low starting value)
float tempMin = 9000;    // Minimum temperature that has been measured (initialized to high starting value)

// Define LCD parameters
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

// Convert analog value from temp. sensor into Fahrenheit temp. value
float TempSensorToFahren(float analogVal) {
  // 5/1023 is the ratio of volts to analog pin value
  // multiply by 100 to scale sensor mV/K output
  // subtract 273.15 to convert Kelvin to Celsius
  // multiply by 9/5 and add 32 to convert Celsius to Fahrenheit
  // ex.  2.95V from sensor is about 72degF
  return ((((0.004888 * analogVal) * 100.0) - 273.15) * 1.87) + 32.0;
}

// Print temp. values to LCD
void print_to_lcd() {
  // Convert float temp. values to integer and decimal portions (1 decimal precision)
  int tempMaxI = int(tempMax);
  int tempMaxD = int((tempMax - tempMaxI) * 10);
  int tempMinI = int(tempMin);
  int tempMinD = int((tempMin - tempMinI) * 10);
  int tempValI = int(tempVal);
  int tempValD = int((tempVal - tempValI) * 10);
  
  // Clear the LCD
  lcd.clear();
  
  // Print the Max and Min temp. values recorded so far
  lcd.print("Mx:");
  lcd.print(tempMaxI);
  lcd.print(".");
  lcd.print(tempMaxD);
  lcd.print(" Mn:");
  lcd.print(tempMinI);
  lcd.print(".");
  lcd.print(tempMinD);
  
  // Print the current temp. value on the second line
  lcd.setCursor(0, 1);
  lcd.print("Cur:");
  lcd.print(tempValI);
  lcd.print(".");
  lcd.print(tempValD);
}

// Print temp. values to Serial link
void print_to_serial() {
  Serial.print("Current temp is: ");
  Serial.println(tempVal);
  Serial.print("Min temp seen is: ");
  Serial.println(tempMin);
  Serial.print("Max temp seen is: ");
  Serial.println(tempMax);
}

void setup() {
  // Set up the LCD's column and row count
  lcd.begin(16, 2);
  
  // Opens the serial port to send data back to the computer at 9600bps
  Serial.begin(9600);
}

void loop() {
  // read the state of the temperature sensor, adjust for analog ratio, 
  // convert from kelvin to celsius then to fahrenheit:
  tempPinVal = analogRead(TEMP);
  
  // only do something if the temp. changed
  if(tempPinVal != oldTempPinVal) {
    // convert temp. pin val to Fahrenheit val
    tempVal = TempSensorToFahren(float(tempPinVal));
    
    // find max and min
    tempMax = max(tempMax, tempVal);
    tempMin = min(tempMin, tempVal);
    
    // set current temp. pin val as old temp. pin val
    oldTempPinVal = tempPinVal;
  }
  
  print_to_lcd();
  print_to_serial();
  
  delay(2000);
}
