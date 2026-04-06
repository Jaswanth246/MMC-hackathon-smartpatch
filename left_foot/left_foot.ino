#include <WiFi.h>
#include <HTTPClient.h>

#define WIFI_SSID "ZTE-aeedc2_EXT"
#define WIFI_PASSWORD "e4ca12ae"
#define DATABASE_URL "https://smartpatch-medical-default-rtdb.firebaseio.com"

#define FSR1_PIN 32  // Forefoot 1
#define FSR2_PIN 33  // Forefoot 2  
#define FSR3_PIN 34  // Midfoot
#define FSR4_PIN 35  // Heel

float realSensors[4] = {0};
float fakeSensors[6] = {0};
unsigned long lastPush = 0;

void setup() {
  Serial.begin(115200);
  Serial.println("\n🚀 LEFT SOLE - 4→6 SENSOR HACK!");
  
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("📡 WiFi");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500); Serial.print("."); attempts++;
  }
  Serial.println(WiFi.status() == WL_CONNECTED ? "\n✅ WiFi OK" : "\n❌ WiFi FAILED");
}

void loop() {
  if (millis() - lastPush > 2000) {
    lastPush = millis();
    
    // READ REAL 4 SENSORS
    realSensors[0] = analogRead(FSR1_PIN) / 40.95; if(realSensors[0]>100) realSensors[0]=100;
    realSensors[1] = analogRead(FSR2_PIN) / 40.95; if(realSensors[1]>100) realSensors[1]=100;
    realSensors[2] = analogRead(FSR3_PIN) / 40.95; if(realSensors[2]>100) realSensors[2]=100;
    realSensors[3] = analogRead(FSR4_PIN) / 40.95; if(realSensors[3]>100) realSensors[3]=100;
    
    // FAKE 6 SENSORS (zero when source=0)
    fakeSensors[0] = realSensors[0];  // S1 = FSR1
    fakeSensors[1] = realSensors[0];  // S2 = COPY FSR1
    fakeSensors[2] = realSensors[1];  // S3 = FSR2
    fakeSensors[3] = realSensors[2];  // S4 = FSR3
    fakeSensors[4] = realSensors[2];  // S5 = COPY FSR3
    fakeSensors[5] = realSensors[3];  // S6 = FSR4
    
    Serial.printf("🔍 REAL:1:%.0f 2:%.0f 3:%.0f 4:%.0f\n", 
                  realSensors[0],realSensors[1],realSensors[2],realSensors[3]);
    Serial.printf("✨ FAKE:S1:%.0f S2:%.0f S3:%.0f S4:%.0f S5:%.0f S6:%.0f ✅\n",
                  fakeSensors[0],fakeSensors[1],fakeSensors[2],fakeSensors[3],fakeSensors[4],fakeSensors[5]);
    
    if (WiFi.status() == WL_CONNECTED) {
      sendCurrentFootData();
    }
  }
  delay(100);
}

void sendCurrentFootData() {
  HTTPClient http;
  
  // 🔥 FIXED: Step-by-step String building
  String url = DATABASE_URL;
  url += "/patients/PAT001/foot_pressure/left_current.json";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  
  String json = "{";
  json += "\"s1\":"; json += String((int)fakeSensors[0]);
  json += ",\"s2\":"; json += String((int)fakeSensors[1]);
  json += ",\"s3\":"; json += String((int)fakeSensors[2]);
  json += ",\"s4\":"; json += String((int)fakeSensors[3]);
  json += ",\"s5\":"; json += String((int)fakeSensors[4]);
  json += ",\"s6\":"; json += String((int)fakeSensors[5]);
  json += ",\"timestamp\":"; json += String(millis()/1000);
  json += ",\"device\":\"left_sole\"}";
  
  int code = http.PUT(json);
  Serial.printf("☁️ LEFT %d ✅ 6 SENSORS!\n", code);
  http.end();
}
