/*
 * Medicep ESP32 Firmware v1.0
 * Components: ESP32, 16x2 LCD (I2C), Buzzer, RTC DS3231, 2x Push Buttons
 * Libraries: 
 * - Firebase ESP Client (by Mobizt)
 * - LiquidCrystal_I2C
 */

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <time.h>

// --- Configuration ---
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#define API_KEY "YOUR_FIREBASE_API_KEY"
#define FIREBASE_PROJECT_ID "YOUR_PROJECT_ID"
#define USER_UID "YOUR_USER_UID" // Hardware belongs to this user

// --- Pin Definitions ---
#define PIN_BUZZER 18
#define PIN_BTN_OK 19
#define PIN_BTN_SNOOZE 4

// --- Objects ---
LiquidCrystal_I2C lcd(0x27, 16, 2);
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// --- State Variables ---
bool isAlarming = false;
String currentMedName = "";
String currentDosage = "";
unsigned long alarmStartTime = 0;
unsigned long snoozeEndTime = 0;
int snoozeIntervalMinutes = 5; // Default from app
bool isSnoozed = false;

// Time sync vars
const char* ntpServer = "pool.ntp.org";
const long  gmtOffset_sec = 19800; // GMT+5:30 for India
const int   daylightOffset_sec = 0;
unsigned long lastFetchTime = 0;
const unsigned long fetchInterval = 60000; // Fetch medicines every 60 seconds

struct Medicine {
  String name;
  String dosage;
  String time; // Format: "HH:mm AM/PM"
};
std::vector<Medicine> medicines;

void setup() {
  Serial.begin(115200);
  
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_BTN_OK, INPUT_PULLUP);
  pinMode(PIN_BTN_SNOOZE, INPUT_PULLUP);
  
  Wire.begin(21, 22); // Start I2C explicitly for ESP32 (SDA=21, SCL=22)
  
  // LCD Setup
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Medicep Starting");

  // WiFi Setup
  lcd.setCursor(0, 1);
  lcd.print("Connecting WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    attempts++;
    if (attempts > 30) { // 15 seconds
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("WiFi Failed!");
      while(1); // Stop here if no WiFi
    }
  }
  Serial.println("\nWiFi Connected");

  // Firebase Setup
  config.api_key = API_KEY;
  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Sync time from NTP
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  struct tm timeinfo;
  lcd.clear();
  lcd.print("Syncing Time...");
  if (getLocalTime(&timeinfo, 10000)) { // wait up to 10 sec
    Serial.println("Time Synced from NTP");
  } else {
    Serial.println("Failed to obtain time");
  }

  fetchProfileSettings();
  fetchMedicines();
}

void loop() {
  struct tm timeinfo;
  if(!getLocalTime(&timeinfo)){
    Serial.println("Failed to obtain time");
    return;
  }
  String currentTimeStr = formatTime(timeinfo);

  if (millis() - lastFetchTime >= fetchInterval) {
    lastFetchTime = millis();
    fetchMedicines();
  }

  if (!isAlarming && !isSnoozed) {
    checkSchedule(currentTimeStr);
  }

  if (isAlarming) {
    handleAlarm();
  } else if (isSnoozed) {
    if (millis() >= snoozeEndTime) {
      isSnoozed = false;
      isAlarming = true;
      triggerAlarm(currentMedName, currentDosage);
    }
  } else {
    updateIdleDisplay(timeinfo);
  }

  delay(100);
}

void fetchProfileSettings() {
  String path = "users/" + String(USER_UID);
  if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "(default)", path.c_str(), "")) {
    FirebaseJson json;
    json.setJsonData(fbdo.payload().c_str());
    FirebaseJsonData jsonData;
    if (json.get(jsonData, "fields/profile/mapValue/fields/snoozeInterval/integerValue")) {
      snoozeIntervalMinutes = jsonData.intValue;
      Serial.printf("Snooze Interval: %d min\n", snoozeIntervalMinutes);
    }
  }
}

void fetchMedicines() {
  String path = "users/" + String(USER_UID) + "/medicines";
  // listDocuments expects 9 arguments: fbdo, projectId, databaseId, collectionId, pageSize, pageToken, orderBy, mask, showMissing
  if (Firebase.Firestore.listDocuments(&fbdo, FIREBASE_PROJECT_ID, "(default)", path.c_str(), 0, "", "", "", false)) {
    FirebaseJson json;
    json.setJsonData(fbdo.payload().c_str());
    FirebaseJsonData jsonData;
    
    // Get the documents array
    if (json.get(jsonData, "documents")) {
      FirebaseJsonArray documents;
      jsonData.getArray(documents);
      medicines.clear();
      
      for (size_t i = 0; i < documents.size(); i++) {
        FirebaseJsonData docData;
        documents.get(docData, i);
        FirebaseJson doc;
        docData.getJSON(doc);
        
        Medicine med;
        if (doc.get(docData, "fields/name/stringValue")) med.name = docData.stringValue;
        if (doc.get(docData, "fields/dosage/stringValue")) med.dosage = docData.stringValue;
        
        // Parse the 'times' array
        if (doc.get(docData, "fields/times/arrayValue/values")) {
          FirebaseJsonArray timesArray;
          docData.getArray(timesArray);
          for (size_t j = 0; j < timesArray.size(); j++) {
            FirebaseJsonData timeData;
            timesArray.get(timeData, j);
            FirebaseJson timeObj;
            timeData.getJSON(timeObj);
            if (timeObj.get(timeData, "stringValue")) {
              med.time = timeData.stringValue; // Adds each time as a separate alarm entry
              medicines.push_back(med);
            }
          }
        }
      }
      Serial.printf("Fetched %d medication slots\n", medicines.size());
    }
  } else {
    Serial.println(fbdo.errorReason());
  }
}

void checkSchedule(String time) {
  for (const auto& med : medicines) {
    if (med.time == time) {
      triggerAlarm(med.name, med.dosage);
      break;
    }
  }
}

void triggerAlarm(String name, String dosage) {
  isAlarming = true;
  currentMedName = name;
  currentDosage = dosage;
  alarmStartTime = millis();
  
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("TAKE: " + name);
  lcd.setCursor(0, 1);
  lcd.print("DOSE: " + dosage);
}

void handleAlarm() {
  // Beep Buzzer
  digitalWrite(PIN_BUZZER, (millis() / 500) % 2);

  // Check OK Button
  if (digitalRead(PIN_BTN_OK) == LOW) {
    stopAlarm();
    Serial.println("Dose Taken (OK Pressed)");
  }

  // Check Snooze Button
  if (digitalRead(PIN_BTN_SNOOZE) == LOW) {
    snoozeAlarm();
    Serial.println("Snoozed");
  }
}

void stopAlarm() {
  isAlarming = false;
  isSnoozed = false;
  digitalWrite(PIN_BUZZER, LOW);
  lcd.clear();
  lcd.print("Dose Logged!");
  delay(2000);
}

void snoozeAlarm() {
  isAlarming = false;
  isSnoozed = true;
  digitalWrite(PIN_BUZZER, LOW);
  snoozeEndTime = millis() + (snoozeIntervalMinutes * 60000);
  lcd.clear();
  lcd.print("Snoozed for");
  lcd.setCursor(0, 1);
  lcd.print(String(snoozeIntervalMinutes) + " mins");
}

void updateIdleDisplay(struct tm timeinfo) {
  lcd.setCursor(0, 0);
  lcd.print("Time: " + formatTime(timeinfo));
  lcd.setCursor(0, 1);
  lcd.print("Stay Healthy!   ");
}

String formatTime(struct tm timeinfo) {
  int hour = timeinfo.tm_hour;
  String period = "AM";
  if (hour >= 12) {
    period = "PM";
    if (hour > 12) hour -= 12;
  }
  if (hour == 0) hour = 12;
  
  char buffer[15];
  sprintf(buffer, "%d:%02d %s", hour, timeinfo.tm_min, period.c_str());
  return String(buffer);
}
