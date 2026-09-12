#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiManager.h>
#include <ArduinoJson.h>
#include "LoRa_E22.h"

// ============================================================
// KONFIGURASI PIN LORA E22-400T22D
// ============================================================
#define LORA_RX_PIN 17
#define LORA_TX_PIN 18
#define LORA_M0_PIN 10
#define LORA_M1_PIN 11
#define LORA_AUX_PIN 21

// Konfigurasi Alamat LoRa (Sesuaikan dengan Pengirim)
#define LORA_ADDH 0x00
#define LORA_ADDL 0x01
#define LORA_CHAN 0x17

HardwareSerial SerialLoRa(2);
LoRa_E22 lora(&SerialLoRa, LORA_AUX_PIN, LORA_M0_PIN, LORA_M1_PIN);

// ============================================================
// KONFIGURASI SUPABASE
// ============================================================
const char* SUPABASE_URL = "https://iksvryrzectfaxmuxjwr.supabase.co"; // GANTI DENGAN URL SUPABASE ANDA
const char* SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlrc3ZyeXJ6ZWN0ZmF4bXV4andyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc1NzQ1NTQsImV4cCI6MjEwMzE1MDU1NH0.F1D0Gw-rAw1ITbLSVN_Al1bjeb-V6-18ZUQiYpmGKGw"; // GANTI DENGAN ANON KEY ANDA

// Endpoint tabel
String telemetryEndpoint = String(SUPABASE_URL) + "/rest/v1/telemetry";
String roverOpsEndpoint = String(SUPABASE_URL) + "/rest/v1/rover_operations";

// Device ID Default
String deviceId = "Rover_Bridge";

// ============================================================
// DEKLARASI FUNGSI
// ============================================================
void setupWiFi();
void setupLoRa();
void sendToSupabase(String endpoint, String jsonPayload);
void parseAndSendTelemetry(String loraData);

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("=== SENAGARDA LORA TO WIFI BRIDGE ===");

  // 1. Setup WiFi menggunakan WiFiManager
  setupWiFi();

  // 2. Setup LoRa
  setupLoRa();
}

void loop() {
  // Mengecek apakah ada data dari LoRa
  if (lora.available() > 1) {
    ResponseContainer rs = lora.receiveMessage();
    
    if (rs.status.code != 1) {
      Serial.println(rs.status.getResponseDescription());
    } else {
      String loraData = rs.data;
      Serial.println("[LoRa] Data Diterima: " + loraData);
      
      // Parse data dan kirim ke Supabase
      parseAndSendTelemetry(loraData);
    }
  }
}

// ============================================================
// IMPLEMENTASI FUNGSI
// ============================================================

void setupWiFi() {
  WiFiManager wm;

  // Set default WiFi Kelurahan (WiFiManager akan mencoba ini terlebih dahulu)
  // Jika tidak ditemukan atau gagal terkoneksi, dia akan masuk ke mode AP
  // Nama AP: "Senagarda_Bridge_AP"
  
  Serial.println("[WiFi] Mencoba koneksi...");
  
  // wm.resetSettings(); // Buka komentar ini jika ingin menghapus credential tersimpan (untuk testing)
  
  // Set timeout portal (misalnya 180 detik)
  wm.setConfigPortalTimeout(180);

  // Coba connect dengan kredensial yang tersimpan, jika gagal buat AP "Senagarda_Bridge_AP"
  // WiFiManager secara default akan menyimpan SSID & Password yang dimasukkan via Captive Portal
  bool res = wm.autoConnect("Senagarda_Bridge_AP", "12345678"); 

  if (!res) {
    Serial.println("[WiFi] Gagal connect atau hit timeout, sistem akan restart");
    // ESP.restart(); // Jika ingin restart setelah timeout
  } else {
    Serial.println("[WiFi] Terhubung!");
    Serial.print("[WiFi] IP Address: ");
    Serial.println(WiFi.localIP());
  }
}

void setupLoRa() {
  SerialLoRa.begin(9600, SERIAL_8N1, LORA_RX_PIN, LORA_TX_PIN);
  
  if (lora.begin()) {
    Serial.println("[LoRa] Modul E22 terdeteksi dan diinisialisasi.");
    
    // Setting Address dan Channel
    ResponseStructContainer c = lora.getConfiguration();
    Configuration cfgLora = *(Configuration *)c.data;
    cfgLora.ADDH = LORA_ADDH;
    cfgLora.ADDL = LORA_ADDL;
    cfgLora.CHAN = LORA_CHAN;
    
    // Opsi Transmisi Fixed/Transparent dsb bisa diatur di sini
    // cfgLora.OPTION.fixedTransmission = FT_TRANSPARENT_TRANSMISSION;
    
    lora.setConfiguration(cfgLora, WRITE_CFG_PWR_DWN_SAVE);
    c.close();
    
    Serial.println("[LoRa] E22 siap.");
  } else {
    Serial.println("[LoRa] GAGAL diinisialisasi. Cek koneksi pin (M0, M1, AUX, RX, TX).");
  }
}

void sendToSupabase(String endpoint, String jsonPayload) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(endpoint);
    
    // Header Wajib untuk Supabase REST API
    http.addHeader("Content-Type", "application/json");
    http.addHeader("apikey", SUPABASE_ANON_KEY);
    http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
    http.addHeader("Prefer", "return=minimal"); // Untuk meminimalkan response data

    Serial.println("[HTTP] Mengirim Data: " + jsonPayload);
    
    int httpResponseCode = http.POST(jsonPayload);
    
    if (httpResponseCode > 0) {
      Serial.print("[HTTP] Response Code: ");
      Serial.println(httpResponseCode);
      
      // Jika butuh membaca balasan dari Supabase:
      // String response = http.getString();
      // Serial.println(response);
    } else {
      Serial.print("[HTTP] Error pada pengiriman: ");
      Serial.println(httpResponseCode);
    }
    
    http.end();
  } else {
    Serial.println("[WiFi] Koneksi terputus. Data tidak dikirim.");
  }
}

void parseAndSendTelemetry(String loraData) {
  // Data dari LoRa bisa bermacam-macam.
  // Contoh 1: Data mentah string "ALAT:1,PROX:0" -> Masukkan ke tabel telemetry
  // Contoh 2: Data koordinat GPS -> Masukkan ke tabel rover_operations
  
  StaticJsonDocument<512> doc;
  
  // Karena struktur data pasti dari rover belum sepenuhnya jelas,
  // Kita akan mencoba mem-parse data LoRa.
  // Jika formatnya JSON, masukkan ke 'payload' telemetry
  // Jika formatnya teks biasa, bungkus di dalam JSON object
  
  // Bikin payload untuk tabel `telemetry`
  // Skema: device_id (text), payload (jsonb)
  
  doc["device_id"] = deviceId;
  
  StaticJsonDocument<256> payloadDoc;
  
  // Coba parse jika loraData itu sudah berupa JSON
  DeserializationError error = deserializeJson(payloadDoc, loraData);
  
  if (!error) {
    // Jika sukses parse sebagai JSON, gunakan object tersebut
    doc["payload"] = payloadDoc;
  } else {
    // Jika teks biasa (contoh "ALAT:1,PROX:0"), masukkan sebagai string atau parsing manual
    payloadDoc["raw_data"] = loraData;
    
    // Opsional: Parsing manual untuk string khusus
    if(loraData.startsWith("ALAT:")) {
      int idxAlat = loraData.indexOf("ALAT:") + 5;
      int idxProx = loraData.indexOf(",PROX:");
      if(idxProx != -1) {
         String alatId = loraData.substring(idxAlat, idxProx);
         String proxVal = loraData.substring(idxProx + 6);
         payloadDoc["alat_id"] = alatId.toInt();
         payloadDoc["proximity"] = proxVal.toInt();
      }
    }
    doc["payload"] = payloadDoc;
  }
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  // Kirim ke endpoint telemetry
  sendToSupabase(telemetryEndpoint, jsonString);
}
