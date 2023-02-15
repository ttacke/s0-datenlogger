#include <SPI.h>
#include <SD.h>

// Timeout: 1 / ([Max Watt: z.B. 10000] / (1000 / [U pro kWh] * 60)) * 60 * 0.05
// bei 75 U/kWh und 10.000 Watt max sind das 0.24 Sekunden maximale Zeit zwischen den Abtastungen
// hier wird zur Sicherheit mit 0.20 Sekunden gearbeitet

File myFile;
const int ledPin = D8;
const int analogInPin = A0;

void setup() {
  Serial.begin(9600);
  // Serial.setTimeout(2000);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }
 
  Serial.println("start");
  if (!SD.begin(4)) {
    Serial.println("SD init failed!");
  } else {  
    myFile = SD.open("time.log", FILE_WRITE);
    if (myFile) {
      myFile.println((String)"time:" + millis() + " - new Start");
      myFile.close();
    } else {
      Serial.println("error opening file");
    }
  }
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin,HIGH);//AN
  // digitalWrite(ledPin,LOW);//AUS - LED muss immer an bleiben, sonst ist der Verbrauch zu gering und der Akkupack schaltet sich einfach aus
  // ESP.deepSleep(20e3);// Leider mit meinem Board nutzlos. Das Ding wacht leider nie wieder auf: https://github.com/esp8266/Arduino/issues/5892 
}

int sensorValue = 0;
int oldValue = 0;
int loopCount = 0;
void loop() {
  loopCount = loopCount + 1;
  sensorValue = analogRead(analogInPin);
  if (oldValue != sensorValue || loopCount > 50) {// Min. alle 10 Sekunden eine Schreibaktion
    loopCount = 0;
    myFile = SD.open("time.log", FILE_WRITE);
    if (myFile) {
      Serial.println("write");
      myFile.println((String)"" + millis() + ";" + sensorValue);
      myFile.close();
    } else {
      Serial.println("error opening file");
    }
    oldValue = sensorValue;
  }
  Serial.println("loop");
  Serial.flush();
  delay(200);// 200 ms, siehe ganz oben
}
