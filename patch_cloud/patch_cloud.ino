#include <WiFi.h>
#include <HTTPClient.h>
#include <time.h>
#include <Preferences.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define WIFI_SSID "ZTE-aeedc2_EXT"
#define WIFI_PASSWORD "e4ca12ae"
#define DATABASE_URL "https://smartpatch-medical-default-rtdb.firebaseio.com"

#define GLUCOSE_PIN 34
#define UREA_PIN 35
#define CREATININE_PIN 32

float glucose = 0, urea = 0, creatinine = 0, dcrs = 0;
unsigned long lastPush = 0;
String patientId = "PAT001";  // 🔥 DYNAMIC PATIENT ID
Preferences preferences;
BLEServer* pServer = NULL;

// 🔥 BLE CONFIG UUID (matches your Flutter app)
#define SERVICE_UUID "12345678-1234-1234-1234-123456789abc"
#define CONFIG_UUID "12345678-1234-1234-1234-123456789abd"
BLECharacteristic* pConfigCharacteristic = NULL;
bool wifiUpdate = false;
String pendingSsid = "", pendingPassword = "";

const long gmtOffset_sec = 19800;
const int daylightOffset_sec = 0;
const char* ntpServer = "pool.ntp.org";

// 🔥 BLE CALLBACK - Receives Patient ID + WiFi
class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    uint8_t* data = pCharacteristic->getData();
    size_t length = pCharacteristic->getLength();
    
    if (length > 0 && length < 100) {
      char buffer[100] = {0};
      memcpy(buffer, data, length);
      String message = String(buffer);
      
      Serial.printf("📶 BLE: %s\n", message.c_str());
      
      // 🔥 PATIENT ID: "PATIENT:PAT001"
      if (message.startsWith("PATIENT:")) {
        patientId = message.substring(8);
        patientId.toUpperCase();
        
        preferences.begin("config", false);
        preferences.putString("patient_id", patientId);
        preferences.end();
        
        Serial.printf("👤 Patient ID: %s ✅\n", patientId.c_str());
        pCharacteristic->setValue(("OK:Patient=" + patientId).c_str());
        pCharacteristic->notify();
      }
      
      // 🔥 WIFI: "WIFI:ssid,password"
      if (message.startsWith("WIFI:")) {
        int comma = message.indexOf(',');
        if (comma > 5) {
          pendingSsid = message.substring(5, comma);
          pendingPassword = message.substring(comma + 1);
          wifiUpdate = true;
          Serial.printf("📡 WiFi update: %s\n", pendingSsid.c_str());
        }
      }
    }
  }
};

float calculateDCRS(float g, float u, float c) {
  float glucoseRisk = g >= 200 ? 1.0 : g >= 126 ? 0.8 : g >= 100 ? 0.4 : 0.1;
  float ureaRisk = u >= 80 ? 1.0 : u >= 50 ? 0.7 : u >= 30 ? 0.3 : 0.1;
  float creatinineRisk = c >= 3.0 ? 1.0 : c >= 1.8 ? 0.8 : c >= 1.2 ? 0.4 : 0.1;
  return (0.5 * glucoseRisk + 0.25 * ureaRisk + 0.25 * creatinineRisk);
}

void sendFirebaseData(String path, float g, float u, float c, float d, String r) {
  HTTPClient http;
  
  // 🔥 YOUR EXACT WORKING METHOD FROM v4.4
  String url = DATABASE_URL;  // https://smartpatch...
  url += "/";                 // /
  url += path;                // patients/PAT001/current  
  url += ".json";             // .json
  
  Serial.println("🔗 " + url);
  
  // 🔥 ADD TIMEOUT - Prevents hanging
  http.setTimeout(5000);  // 5 seconds max
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  
  time_t now = time(nullptr);
  String json = "{";
  json += "\"glucose\":" + String(g,1);
  json += ",\"urea\":" + String(u,1);
  json += ",\"creatinine\":" + String(c,2);
  json += ",\"dcrs\":" + String(d,2);
  json += ",\"risk\":\"" + r + "\"";
  json += ",\"timestamp\":" + String(now);
  json += ",\"device_id\":\"PATCH_v4.5\"";
  json += "}";
  
  int code = http.PUT(json);
  
  // 🔥 BETTER DEBUG
  if(code > 0) {
    Serial.printf("✅ [%s] HTTP:%d\n", patientId.c_str(), code);
  } else {
    Serial.printf("❌ [%s] HTTP:%d\n", patientId.c_str(), code);
    Serial.println("🔍 WiFi OK? " + String(WiFi.status() == WL_CONNECTED));
  }
  http.end();
}


void setup() {
  Serial.begin(115200);
  Serial.println("\n🚀 SMART PATCH v4.5 - BLE + WORKING FIREBASE!");
  
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  
  // 🔥 LOAD SAVED PATIENT ID
  preferences.begin("config", true);
  patientId = preferences.getString("patient_id", "PAT001");
  preferences.end();
  
  Serial.printf("👤 Patient: %s\n", patientId.c_str());
  
  // WiFi (your working code)
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("📡 WiFi");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi: " + WiFi.localIP().toString());
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    
    struct tm timeinfo;
    if (getLocalTime(&timeinfo)) {
      Serial.printf("🕐 %02d:%02d:%02d\n", 
                   timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
    }
  }
  
  // 🔥 BLE SERVER (Patient app sends Patient ID here)
  BLEDevice::init("SmartPatch_" + patientId);
  pServer = BLEDevice::createServer();
  
  BLEService* pService = pServer->createService(SERVICE_UUID);
  pConfigCharacteristic = pService->createCharacteristic(
    CONFIG_UUID,
    BLECharacteristic::PROPERTY_READ | 
    BLECharacteristic::PROPERTY_WRITE | 
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pConfigCharacteristic->setCallbacks(new ConfigCallbacks());
  pConfigCharacteristic->setValue(("READY:Patient=" + patientId).c_str());
  pService->start();
  
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->start();
  
  Serial.println("🔗 BLE Ready - Connect from app!");
}

void loop() {
  // 🔥 APPLY WIFI CHANGES
  if (wifiUpdate) {
    wifiUpdate = false;
    preferences.begin("config", false);
    preferences.putString("ssid", pendingSsid);
    preferences.putString("pass", pendingPassword);
    preferences.end();
    Serial.println("🔄 WiFi saved - RESTARTING");
    delay(2000);
    ESP.restart();
  }
  
  if (millis() - lastPush > 5000) {
    lastPush = millis();
    
    int gRaw = analogRead(GLUCOSE_PIN);
    int uRaw = analogRead(UREA_PIN);
    int cRaw = analogRead(CREATININE_PIN);
    
    glucose = 70 + (gRaw * 330.0 / 4095);
    urea = 10 + (uRaw * 110.0 / 4095);
    creatinine = 0.5 + (cRaw * 4.5 / 4095);
    
    dcrs = calculateDCRS(glucose, urea, creatinine);
    String risk = dcrs >= 0.7 ? "RED" : dcrs >= 0.4 ? "ORANGE" : "GREEN";
    
    Serial.printf("📊 G:%.1f U:%.1f C:%.2f | DCRS:%.2f (%s) | Patient: %s\n", 
                 glucose, urea, creatinine, dcrs, risk.c_str(), patientId.c_str());
    
    if (WiFi.status() == WL_CONNECTED) {
      sendFirebaseData("patients/" + patientId + "/current", 
                      glucose, urea, creatinine, dcrs, risk);
      
      if (dcrs >= 0.4) {
        String alertPath = "patients/" + patientId + "/alerts/" + String(time(nullptr));
        sendFirebaseData(alertPath, glucose, urea, creatinine, dcrs, risk);
        Serial.println("🚨 ALERT!");
      }
    }
  }
  delay(100);
}
