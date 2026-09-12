// ============================================================
// SENAGARDA ROVER - MODE REMOTE WIFI (WEBSOCKET)
// ============================================================
// KONFIGURASI MOTOR PARALEL:
// - KIRI: M1 & M3 paralel (pin PWM sama)
// - KANAN: M2 & M4 paralel (pin PWM sama)
// ============================================================
#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include "DFRobot_GNSS.h"
#include <math.h>
#include "LoRa_E22.h"
#include <WiFi.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <esp_now.h>
#include <esp_wifi.h>
// ============================================================
// KONFIGURASI PIN
// ============================================================
// MOTOR KIRI
#define M1_RPWM 5
#define M1_LPWM 4

// MOTOR KANAN
#define M2_RPWM 15
#define M2_LPWM 7

// ENABLE
#define EN_LEFT 6
#define EN_RIGHT 16

// PWM CHANNEL
#define CH_M1_RPWM 0
#define CH_M1_LPWM 1
#define CH_M2_RPWM 2
#define CH_M2_LPWM 3

#define IMU_SDA 8
#define IMU_SCL 9
#define IMU_ADDR 0x28

#define PWM_FREQ 20000
#define PWM_RESOLUTION 8

#define PID_KP 1.0f
#define PID_KI 0.2f
#define PID_KD 1.6f

// --- RELAY DUAL CHANNEL ---
#define RELAY_IN1 47
#define RELAY_IN2 48
// Set true jika modul relay Anda aktif-LOW (kebanyakan modul relay 2-channel
// generik seperti ini — LOW = relay ON/kontak nyambung, HIGH = OFF).
// Set false kalau modul relay Anda aktif-HIGH.
#define RELAY_ACTIVE_LOW true

#if RELAY_ACTIVE_LOW
  #define RELAY_ON  LOW
  #define RELAY_OFF HIGH
#else
  #define RELAY_ON  HIGH
  #define RELAY_OFF LOW
#endif

// NAIK dari 70 -> 90: respon motor jalan lurus lebih kencang / tidak
// terlalu "lemas" di kecepatan rendah.
#define MIN_MOTOR_SPEED 90

// NAIK dari 150 -> 220: kecepatan default gerak (manual F/B & jalan
// lurus otonom PLAY) dinaikkan mendekati maksimal (255) supaya rover
// lebih responsif/cepat.
#define DRIVE_PWM_SPEED 220

// --- PWM BELOK (pivotTurn) ---
// Skema baru: satu sisi motor maju dgn PWM MAKSIMAL, sisi lainnya
// maju dgn PWM SANGAT RENDAH -- bukan lagi "pwm+200 / pwm-40" seperti
// sebelumnya. Ini bikin belok jauh lebih tajam/cepat.
#define TURN_PWM_FAST 220
#define TURN_PWM_SLOW 50

#define TURN_TOLERANCE_DEG 3.0f
#define TURN_TIMEOUT_MS 20000UL

#define TURN_SLOWDOWN_DEG 40.0f
#define TURN_MIN_RATIO 0.45f
#define GPS_SLOWDOWN_M 4.0
#define GPS_MIN_SPEED_RATIO 0.50f
#define PIN_ESTOP 0

// --- BATERAI ---
#define VOLTAGE_PIN 1

// --- LoRa E22-400T ---
#define LORA_RX_PIN 17
#define LORA_TX_PIN 18
#define LORA_M0_PIN 10
#define LORA_M1_PIN 11
#define LORA_AUX_PIN 21
#define LORA_ADDH 0x00
#define LORA_ADDL 0x01
#define LORA_CHAN 0x17
#define FAILSAFE_MS 1500UL

HardwareSerial SerialLoRa(2);
LoRa_E22 lora(&SerialLoRa, LORA_AUX_PIN, LORA_M0_PIN, LORA_M1_PIN);

// --- WIFI ---
const char* ssid = "Senagarda_Rover";         // Ganti dengan nama WiFi/Tethering Anda
const char* password = "karangtengah2026";  // Ganti dengan password WiFi/Tethering Anda

// --- KONFIGURASI IP STATIS ---
// WAJIB DISESUAIKAN:
// 3 angka pertama HARUS SAMA dengan pengaturan router/tethering Anda.
// Angka terakhir (250) adalah IP permanen untuk ESP32 ini.
IPAddress local_IP(192, 168, 0, 250);
IPAddress gateway(192, 168, 0, 1);
IPAddress subnet(255, 255, 255, 0);

AsyncWebServer server(80);
AsyncWebSocket ws("/ws");

// typedef struct struct_message {
//     int id_alat;
//     int status_proximity;
// } struct_message;

// struct_message dataDiterima;

// ============================================================
// MOTOR DRIVER
// ============================================================
namespace MotorCh {
  constexpr int M1_R = 0, M1_L = 1;
  constexpr int M2_R = 2, M2_L = 3;
  constexpr int M3_R = 4, M3_L = 5;
  constexpr int M4_R = 6, M4_L = 7;
}

// --- Channel PWM (API ledc LAMA / ESP32 core 2.x: ledcSetup + ledcAttachPin + ledcWrite(channel,...)) ---
#define PWM_CH_M1_RPWM 0
#define PWM_CH_M1_LPWM 1
#define PWM_CH_M2_RPWM 2
#define PWM_CH_M2_LPWM 3

class MotorDriver {
public:
  void begin() {
    pinMode(EN_LEFT, OUTPUT);
    pinMode(EN_RIGHT, OUTPUT);
    digitalWrite(EN_LEFT, HIGH);
    digitalWrite(EN_RIGHT, HIGH);

    // API BARU (ESP32 core 3.x): ledcAttach(pin, freq, resolution)
    // Tidak perlu lagi channel manual -- pin langsung dipakai sbg "channel".
    ledcAttach(M1_RPWM, PWM_FREQ, PWM_RESOLUTION);
    ledcAttach(M1_LPWM, PWM_FREQ, PWM_RESOLUTION);
    ledcAttach(M2_RPWM, PWM_FREQ, PWM_RESOLUTION);
    ledcAttach(M2_LPWM, PWM_FREQ, PWM_RESOLUTION);

    stop();
  }

  void setLeft(int speed) {
    speed = constrain(speed, -255, 255);
    if (speed >= 0) {
      ledcWrite(M1_RPWM, 0);
      ledcWrite(M1_LPWM, speed);
    } else {
      ledcWrite(M1_RPWM, -speed);
      ledcWrite(M1_LPWM, 0);
    }
  }

  void setRight(int speed) {
    speed = constrain(speed, -255, 255);
    if (speed >= 0) {
      ledcWrite(M2_RPWM, speed);
      ledcWrite(M2_LPWM, 0);
    } else {
      ledcWrite(M2_RPWM, 0);
      ledcWrite(M2_LPWM, -speed);
    }
  }

  void driveStraight(int baseSpeed, int correction) {
    int left = constrain(baseSpeed + correction, -255, 255);
    int right = constrain(baseSpeed - correction, -255, 255);

    left = applyDeadband(left);
    right = applyDeadband(right);

    setLeft(left);
    setRight(right);
  }

  void pivotTurn(int pwm, int dir) {
    int slowPwm = (int)(pwm * 0.2f);
    if (slowPwm < TURN_PWM_SLOW) slowPwm = TURN_PWM_SLOW;

    if (dir == -1) {
      setLeft(slowPwm);
      setRight(pwm);
    } else {
      setLeft(pwm);
      setRight(slowPwm);
    }
  }

  void stop() {
    setLeft(0);
    setRight(0);
  }

private:
  int applyDeadband(int speed) {
    if (speed == 0) return 0;
    if (speed > 0 && speed < MIN_MOTOR_SPEED) return MIN_MOTOR_SPEED;
    if (speed < 0 && speed > -MIN_MOTOR_SPEED) return -MIN_MOTOR_SPEED;
    return speed;
  }
};

// ============================================================
// IMU SENSOR
// ============================================================
class HeadingSensor {
public:
  HeadingSensor() : bno(55, IMU_ADDR) {}

  bool begin() {
    Wire.begin(IMU_SDA, IMU_SCL);
    ready = bno.begin(OPERATION_MODE_IMUPLUS);
    if (ready) bno.setExtCrystalUse(true);
    return ready;
  }

  void resetHeadingRef() { headingRef = bacaRaw(); }
  bool isReady() const { return ready; }

  float bacaRaw() {
    if (!ready) return 0;
    sensors_event_t event;
    bno.getEvent(&event);
    return normalize(event.orientation.x);
  }

  float getHeading() {
    if (!ready) return 0;
    return normalize(bacaRaw() - headingRef);
  }

  void getCalibration(uint8_t &sys, uint8_t &gyro, uint8_t &accel, uint8_t &mag) {
    if (ready) bno.getCalibration(&sys, &gyro, &accel, &mag);
    else { sys = gyro = accel = mag = 0; }
  }

  static float normalize(float angle) {
    angle = fmod(angle, 360.0f);
    if (angle < 0) angle += 360.0f;
    return angle;
  }

  static float shortestError(float target, float current) {
    float err = target - current;
    while (err > 180.0f) err -= 360.0f;
    while (err < -180.0f) err += 360.0f;
    return err;
  }

private:
  Adafruit_BNO055 bno;
  bool ready = false;
  float headingRef = 0;
};

// ============================================================
// PID CONTROLLER
// ============================================================
class HeadingPID {
public:
  HeadingPID(float kp, float ki, float kd) : kp(kp), ki(ki), kd(kd) {}

  void reset() { integral = 0; lastError = 0; lastTime = millis(); }

  float compute(float error) {
    unsigned long now = millis();
    float dt = (now - lastTime) / 1000.0f;
    if (dt <= 0.001f) dt = 0.001f;
    lastTime = now;
    integral += error * dt;
    integral = constrain(integral, -20.0f, 20.0f);
    float derivative = (error - lastError) / dt;
    lastError = error;
    return (kp * error) + (ki * integral) + (kd * derivative);
  }

private:
  float kp, ki, kd;
  float integral = 0;
  float lastError = 0;
  unsigned long lastTime = 0;
};

// // Fungsi penangkap otomatis saat data ESP-NOW masuk dari Pojok Sawah
// void OnDataRecv(const esp_now_recv_info *recv_info, const uint8_t *incomingData, int len) {
//   // Salin data biner yang masuk ke dalam variabel struct
//   memcpy(&dataDiterima, incomingData, sizeof(dataDiterima));
  
//   // Menampilkan log data di Serial Monitor Rover untuk pemantauan
//   Serial.printf("\n[ESP-NOW MASUK] Dari Alat ID: %d | Status Proximity: %d\n", dataDiterima.id_alat, dataDiterima.status_proximity);

//   // Mengubah data menjadi format CSV ringkas ("ALAT:1,PROX:0\n")
//   String dataKeLora = "ALAT:" + String(dataDiterima.id_alat) + ",PROX:" + String(dataDiterima.status_proximity) + "\n";

//   // Kirim data teks tersebut secara fisik ke modul LoRa Ebyte
//   SerialLoRa.print(dataKeLora);
//   Serial.print("-> Berhasil Diteruskan ke LoRa Ebyte Gateway\n");
// }

// ============================================================
// GPS SENSOR
// ============================================================
class GpsSensor {
public:
  GpsSensor() : gnss(&Wire, GNSS_DEVICE_ADDR) {}

  bool begin() {
    ready = gnss.begin();
    if (ready) {
      gnss.enablePower();
      gnss.setGnss(eGPS_BeiDou_GLONASS);
      gnss.setRgbOn();
    }
    return ready;
  }

  bool isReady() const { return ready; }
  void update() {
    if (!ready) return;

    unsigned long now = millis();
    if (now - lastUpdate < 200) return;
    lastUpdate = now;
    cachedSat = gnss.getNumSatUsed();
    sLonLat_t l = gnss.getLat();
    cachedLat = l.latitudeDegree;
    if ((char)l.latDirection == 'S') cachedLat = -cachedLat;
    
    // [FIX] Paksa nilai latitude menjadi negatif karena lokasi di Imogiri (selatan ekuator)
    if (cachedLat > 0.0) cachedLat = -cachedLat;

    sLonLat_t lo = gnss.getLon();
    cachedLon = lo.lonitudeDegree;
    if ((char)lo.lonDirection == 'W') cachedLon = -cachedLon;

    if (cachedSat < 4 || (cachedLat == 0.0 && cachedLon == 0.0)) {
      hasFix = false;
    } else {
      hasFix = true;
    }
  }
  bool adaFix() { update(); return hasFix; }
  double lat() { update(); return cachedLat; }
  double lon() { update(); return cachedLon; }
  uint8_t jumlahSatelit() { update(); return cachedSat; }

private:
  DFRobot_GNSS_I2C gnss;
  bool ready = false;
  bool hasFix = false;
  double cachedLat = 0.0;
  double cachedLon = 0.0;
  uint8_t cachedSat = 0;
  unsigned long lastUpdate = 0;
};

// ============================================================
// OBJEK GLOBAL
// ============================================================
MotorDriver motor;
HeadingSensor imuSensor;
HeadingPID headingPid(PID_KP, PID_KI, PID_KD);
GpsSensor gps;
bool loraSiap = false;

// --- Status koneksi WiFi/WebSocket (menggantikan koneksiAktif via BLE) ---
bool koneksiAktif = false;

volatile bool mintaJalankanPath = false;
String dataPathPending = "";
volatile bool mintaKalibrasiArah = false;
volatile bool mintaStopAuto = false;

bool estopDitekan() { return digitalRead(PIN_ESTOP) == LOW; }

double jarakMeter(double lat1, double lon1, double lat2, double lon2) {
  const double R = 6371000.0;
  double dLat = radians(lat2 - lat1);
  double dLon = radians(lon2 - lon1);
  double a = sin(dLat / 2) * sin(dLat / 2) +
             cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}
double bearingDerajat(double lat1, double lon1, double lat2, double lon2) {
  double dLon = radians(lon2 - lon1);
  double y = sin(dLon) * cos(radians(lat2));
  double x = cos(radians(lat1)) * sin(radians(lat2)) -
             sin(radians(lat1)) * cos(radians(lat2)) * cos(dLon);
  double brng = degrees(atan2(y, x));
  return fmod(brng + 360.0, 360.0);
}

// ============================================================
// GERAK
// ============================================================
enum GerakAksi { DIAM, MAJU, MUNDUR, BELOK_KIRI, BELOK_KANAN };
GerakAksi aksiSekarang = DIAM;
int kecepatanSekarang = 220;
float targetHeadingLurus = 0;
unsigned long waktuPerintahTerakhir = 0;
bool sedangAutonomous = false;
enum ModeRover { MODE_MANUAL, MODE_AUTO };
ModeRover modeSekarang = MODE_MANUAL;
bool sedangRekam = false;

void kirimStatusBerkala();

void prosesGerakTick() {
  if (sedangAutonomous) return;
  if (aksiSekarang != DIAM && millis() - waktuPerintahTerakhir > FAILSAFE_MS) {
    aksiSekarang = DIAM;
    motor.stop();
    Serial.println("[FAILSAFE] Tidak ada perintah baru, rover dihentikan otomatis.");
    return;
  }
  switch (aksiSekarang) {
    case DIAM:
      motor.stop();
      break;
    case MAJU: {
      float heading = imuSensor.getHeading();
      float error = HeadingSensor::shortestError(targetHeadingLurus, heading);
      float koreksi = headingPid.compute(error);
      motor.driveStraight(kecepatanSekarang, (int)koreksi);
      break;
    }
    case MUNDUR: {
      float heading = imuSensor.getHeading();
      float error = HeadingSensor::shortestError(targetHeadingLurus, heading);
      float koreksi = headingPid.compute(error);
      motor.driveStraight(-kecepatanSekarang, (int)koreksi);
      break;
    }
    case BELOK_KIRI:
      motor.pivotTurn(kecepatanSekarang, -1);
      break;
    case BELOK_KANAN:
      motor.pivotTurn(kecepatanSekarang, 1);
      break;
  }
}

// --- BLOCKING untuk PLAY ---
void belokBlocking(float derajat, int arahPutar, int kecepatanPwm) {
  float headingAwal = imuSensor.getHeading();
  unsigned long mulai = millis();
  int pwmMin = (int)(kecepatanPwm * TURN_MIN_RATIO);
  if (pwmMin < 1) pwmMin = 1;
  while (millis() - mulai < TURN_TIMEOUT_MS) {
    kirimStatusBerkala();
    ws.cleanupClients();
    if (estopDitekan() || !koneksiAktif || mintaStopAuto) {
      if (!koneksiAktif) Serial.println("[PLAY] Koneksi putus di tengah belok, berhenti paksa.");
      else if (mintaStopAuto) Serial.println("[PLAY] Dibatalkan oleh pengguna (STOP_AUTO) saat belok.");
      break;
    }
    float heading = imuSensor.getHeading();
    float sudahBerputar = fabs(HeadingSensor::shortestError(heading, headingAwal));
    float sisa = derajat - sudahBerputar;
    if (sisa <= TURN_TOLERANCE_DEG) break;
    int pwm;
    if (sisa >= TURN_SLOWDOWN_DEG) pwm = kecepatanPwm;
    else { pwm = (int)(kecepatanPwm * (sisa / TURN_SLOWDOWN_DEG)); if (pwm < pwmMin) pwm = pwmMin; }
    pwm = constrain(pwm, 0, 255);
    motor.pivotTurn(pwm, arahPutar);
    delay(20);
  }
  motor.stop();
}
void majuKalibrasiBlocking(int kecepatanPwm, double jarakTargetM, unsigned long timeoutMs) {
  double latAwal = gps.lat(), lonAwal = gps.lon();
  float targetHeading = imuSensor.getHeading();
  headingPid.reset();
  unsigned long mulai = millis();
  while (millis() - mulai < timeoutMs) {
    kirimStatusBerkala();
    ws.cleanupClients();
    if (estopDitekan() || !koneksiAktif || mintaStopAuto) {
      if (!koneksiAktif) Serial.println("[PLAY] Koneksi putus di tengah jalan, berhenti paksa.");
      else if (mintaStopAuto) Serial.println("[PLAY] Dibatalkan oleh pengguna (STOP_AUTO).");
      break;
    }
    double jarak = jarakMeter(latAwal, lonAwal, gps.lat(), gps.lon());
    if (jarak >= jarakTargetM) break;
    double sisaM = jarakTargetM - jarak;
    int pwmDipakai;
    if (sisaM >= GPS_SLOWDOWN_M) pwmDipakai = kecepatanPwm;
    else {
      float rasio = (float)(sisaM / GPS_SLOWDOWN_M);
      pwmDipakai = (int)(kecepatanPwm * rasio);
      int pwmMin = (int)(kecepatanPwm * GPS_MIN_SPEED_RATIO);
      if (pwmDipakai < pwmMin) pwmDipakai = pwmMin;
    }
    float heading = imuSensor.getHeading();
    float error = HeadingSensor::shortestError(targetHeading, heading);
    float koreksi = headingPid.compute(error);
    motor.driveStraight(pwmDipakai, (int)koreksi);
    delay(20);
  }
  motor.stop();
}

float bearingKeHeadingIMU(double bearingGPS); // Forward declaration

void gerakBlockingSampaiKoordinat(int kecepatanPwm, double targetLat, double targetLng, bool maju, float targetHeadingLine, unsigned long timeoutMs) {
  headingPid.reset();
  unsigned long mulai = millis();
  double jarakTerdekat = 999999.0;
  const double TOLERANSI_GPS_M = 2.5; // Toleransi 2.5m khusus modul GNSS DFRobot (mencegah stuck/overshoot)

  while (millis() - mulai < timeoutMs) {
    kirimStatusBerkala();
    ws.cleanupClients();
    if (estopDitekan() || !koneksiAktif || mintaStopAuto) {
      if (!koneksiAktif) Serial.println("[PLAY] Koneksi putus di tengah jalan, berhenti paksa.");
      else if (mintaStopAuto) Serial.println("[PLAY] Dibatalkan oleh pengguna (STOP_AUTO).");
      break;
    }
    
    double jarak = jarakMeter(gps.lat(), gps.lon(), targetLat, targetLng);
    if (jarak <= TOLERANSI_GPS_M) break; // Sudah sampai dalam toleransi 2.5 meter
    
    // Deteksi overshoot
    if (jarak < jarakTerdekat) {
      jarakTerdekat = jarak;
    } else if (jarak > jarakTerdekat + 1.0 && jarakTerdekat < 5.0) {
      Serial.println("[PLAY] Overshoot terdeteksi, anggap sudah sampai.");
      break;
    }

    int pwmDipakai;
    if (jarak >= GPS_SLOWDOWN_M) pwmDipakai = kecepatanPwm;
    else {
      float rasio = (float)(jarak / GPS_SLOWDOWN_M);
      pwmDipakai = (int)(kecepatanPwm * rasio);
      int pwmMin = (int)(kecepatanPwm * GPS_MIN_SPEED_RATIO);
      if (pwmDipakai < pwmMin) pwmDipakai = pwmMin;
    }

    float heading = imuSensor.getHeading();
    float error = HeadingSensor::shortestError(targetHeadingLine, heading);
    float koreksi = headingPid.compute(error);
    
    // Jika maju, arah PWM positif. Jika mundur, arah PWM negatif.
    int dirPwm = maju ? pwmDipakai : -pwmDipakai;
    motor.driveStraight(dirPwm, (int)koreksi);
    delay(20);
  }
  motor.stop();
}

// ============================================================
// AUTONOMOUS PLAY
// ============================================================
double offsetHeadingVsGPS = 0;
bool kalibrasiHeadingViaGPS() {
  if (!gps.adaFix()) return false;
  double lat0 = gps.lat(), lon0 = gps.lon();
  float headingAwal = imuSensor.getHeading();
  Serial.println("[KALIBRASI] Maju sebentar utk selaraskan heading IMU vs GPS...");
  majuKalibrasiBlocking(DRIVE_PWM_SPEED, 2.0, 8000);
  if (!gps.adaFix()) return false;
  double jarak = jarakMeter(lat0, lon0, gps.lat(), gps.lon());
  if (jarak < 1.0) {
    Serial.println("[KALIBRASI] GAGAL - gerak terlalu sedikit (GPS noise dominan).");
    return false;
  }
  double bearingGPS = bearingDerajat(lat0, lon0, gps.lat(), gps.lon());
  offsetHeadingVsGPS = headingAwal - bearingGPS;
  Serial.printf("[KALIBRASI] OK - offset heading vs GPS: %.1f derajat\n", offsetHeadingVsGPS);
  return true;
}
float bearingKeHeadingIMU(double bearingGPS) {
  return HeadingSensor::normalize(bearingGPS + offsetHeadingVsGPS);
}
struct TitikPath { double lat; double lng; };
TitikPath jalurPath[20];
int jumlahTitikPath = 0;
void mulaiJalankanPath(String data) {
  jumlahTitikPath = 0;
  int mulaiIdx = 0;
  while (mulaiIdx < (int)data.length() && jumlahTitikPath < 20) {
    int pemisah = data.indexOf('|', mulaiIdx);
    String bagian = (pemisah == -1) ? data.substring(mulaiIdx) : data.substring(mulaiIdx, pemisah);
    int koma = bagian.indexOf(',');
    if (koma > 0) {
      jalurPath[jumlahTitikPath].lat = bagian.substring(0, koma).toDouble();
      jalurPath[jumlahTitikPath].lng = bagian.substring(koma + 1).toDouble();
      jumlahTitikPath++;
    }
    if (pemisah == -1) break;
    mulaiIdx = pemisah + 1;
  }
  Serial.printf("[PLAY] %d titik diterima.\n", jumlahTitikPath);
  if (jumlahTitikPath == 0) { Serial.println("[PLAY] Kosong, batal."); return; }
  if (!gps.adaFix()) { Serial.println("[PLAY] Belum ada fix GPS, batal."); return; }
  if (!koneksiAktif) { Serial.println("[PLAY] Tidak ada koneksi aktif, batal."); return; }
  sedangAutonomous = true;
  mintaStopAuto = false;
  aksiSekarang = DIAM;
  motor.stop();
  if (!kalibrasiHeadingViaGPS()) {
    Serial.println("[PLAY] Kalibrasi gagal, path dibatalkan.");
    sedangAutonomous = false;
    return;
  }
  if (mintaStopAuto) {
    Serial.println("[PLAY] Dibatalkan oleh pengguna setelah kalibrasi.");
    sedangAutonomous = false;
    return;
  }

  int i = 0;
  int arahPatroli = 1; // 1 untuk MAJU (A->B), -1 untuk MUNDUR (B->A)
  // Langsung gunakan heading bodi saat ini tanpa belok/putar awal
  float lineHeading = imuSensor.getHeading();

  while (!mintaStopAuto) {
    double jarakAwal = jarakMeter(gps.lat(), gps.lon(), jalurPath[i].lat, jalurPath[i].lng);
    if (jarakAwal <= 2.5) {
      Serial.printf("[PLAY] Titik %d dalam toleransi GPS (%.1fm), lanjut ke berikutnya.\n", i + 1, jarakAwal);
    } else {
      bool maju = (arahPatroli == 1);
      Serial.printf("[PLAY] %s %.1f m menuju titik %d (langsung jalan tanpa belok)\n", maju ? "MAJU" : "MUNDUR", jarakAwal, i + 1);
      gerakBlockingSampaiKoordinat(DRIVE_PWM_SPEED, jalurPath[i].lat, jalurPath[i].lng, maju, lineHeading, 60000);

      if (estopDitekan()) { Serial.println("[PLAY] E-STOP, path dihentikan."); break; }
      if (mintaStopAuto) break;
    }

    // Logika patroli maju mundur (looping terus tanpa belok/putar bodi)
    if (jumlahTitikPath <= 1) break;

    i += arahPatroli;
    if (i >= jumlahTitikPath) {
      i = jumlahTitikPath - 2;
      arahPatroli = -1; // Berbalik arah motor: MUNDUR dari B ke A
      if (i < 0) i = 0;
    } else if (i < 0) {
      i = 1;
      arahPatroli = 1;  // Berbalik arah motor: MAJU dari A ke B
      if (i >= jumlahTitikPath) i = 0;
    }
  }
  if (mintaStopAuto) {
    Serial.println("[PLAY] Path dihentikan oleh pengguna (STOP_AUTO).");
  } else {
    Serial.println("[PLAY] Path selesai.");
  }
  sedangAutonomous = false;
}

// ============================================================
// PARSING PERINTAH
// ============================================================
void tanganiPerintah(String cmd) {
  cmd.trim();
  waktuPerintahTerakhir = millis();
  Serial.printf("[WS] Perintah diterima: \"%s\"\n", cmd.c_str());
  if (cmd == "F") {
    if (aksiSekarang != MAJU) { targetHeadingLurus = imuSensor.getHeading(); headingPid.reset(); }
    aksiSekarang = MAJU;
    Serial.println("[CMD] MAJU");
  } else if (cmd == "B") {
    if (aksiSekarang != MUNDUR) { targetHeadingLurus = imuSensor.getHeading(); headingPid.reset(); }
    aksiSekarang = MUNDUR;
    Serial.println("[CMD] MUNDUR");
  } else if (cmd == "L") {
    aksiSekarang = BELOK_KIRI;
    Serial.println("[CMD] BELOK KIRI");
  } else if (cmd == "R") {
    aksiSekarang = BELOK_KANAN;
    Serial.println("[CMD] BELOK KANAN");
  } else if (cmd == "S") {
    aksiSekarang = DIAM;
    Serial.println("[CMD] STOP");
  } else if (cmd == "REC:1") {
    sedangRekam = true;
    Serial.println("[CMD] REKAM ON");
  } else if (cmd == "REC:0") {
    sedangRekam = false;
    Serial.println("[CMD] REKAM OFF");
  } else if (cmd == "MODE:M") {
    modeSekarang = MODE_MANUAL;
    aksiSekarang = DIAM;
    Serial.println("[CMD] MODE MANUAL");
  } else if (cmd == "MODE:A") {
    modeSekarang = MODE_AUTO;
    aksiSekarang = DIAM;
    Serial.println("[CMD] MODE AUTO");
  } else {
    Serial.printf("[WS] Perintah tidak dikenal: %s\n", cmd.c_str());
  }
}

// Rute perintah dari WS/LoRa: menangani prefix khusus (PLAY:, KALIBRASI_ARAH)
// sebelum diteruskan ke tanganiPerintah().
void rutePerintahMasuk(String cmd) {
  cmd.trim();
  if (cmd.length() == 0) return;
  if (cmd.startsWith("PLAY:")) {
    dataPathPending = cmd.substring(5);
    mintaJalankanPath = true;
  } else if (cmd == "STOP_AUTO") {
    mintaStopAuto = true;
    Serial.println("[WS] Menerima perintah STOP_AUTO, menghentikan misi!");
  } else if (cmd == "KALIBRASI_ARAH") {
    mintaKalibrasiArah = true;
  } else {
    tanganiPerintah(cmd);
  }
}

// ============================================================
// CALLBACK WEBSOCKET (menggantikan callback BLE)
// ============================================================
void onWsEvent(AsyncWebSocket *server, AsyncWebSocketClient *client, AwsEventType type, void *arg, uint8_t *data, size_t len) {
  if (type == WS_EVT_CONNECT) {
    koneksiAktif = true;
    Serial.printf("[WS] Client konek. ID: %u, IP: %s\n", client->id(), client->remoteIP().toString().c_str());
  } else if (type == WS_EVT_DISCONNECT) {
    // Kalau tidak ada client lagi yang terhubung, aktifkan failsafe
    if (server->count() == 0) {
      koneksiAktif = false;
      aksiSekarang = DIAM;
      motor.stop();
      Serial.println("[WS] Semua client putus -- rover dihentikan (failsafe).");
    } else {
      Serial.printf("[WS] Client %u putus, masih ada client lain.\n", client->id());
    }
  } else if (type == WS_EVT_DATA) {
    AwsFrameInfo *info = (AwsFrameInfo *)arg;
    if (info->final && info->index == 0 && info->len == len && info->opcode == WS_TEXT) {
      data[len] = 0;
      String cmd = String((char *)data);
      // Print mentah supaya kelihatan di Serial Monitor kalau data dari app benar2 masuk
      Serial.print("[App -> ESP32] ");
      Serial.println(cmd);
      rutePerintahMasuk(cmd);
    }
  }
}

void kirimStatusBerkala() {
  static unsigned long terakhir = 0;
  if (millis() - terakhir < 400) return;
  terakhir = millis();
  if (!koneksiAktif) return;
  const char *modeStr = (modeSekarang == MODE_AUTO) ? "A" : "M";
  double latKirim = gps.lat();
  double lonKirim = gps.lon();
  float headingKirim = HeadingSensor::normalize(
    imuSensor.getHeading() + offsetHeadingVsGPS
  );
  int battPercent = map(analogRead(VOLTAGE_PIN), 0, 4095, 0, 100);
  battPercent = constrain(battPercent, 0, 100);
  char buf[140];
  snprintf(buf, sizeof(buf), "ST:%s,%.1f,%.6f,%.6f,%d,%d,%d",
    modeStr, headingKirim, latKirim, lonKirim,
    gps.jumlahSatelit(), sedangRekam ? 1 : 0, battPercent);
  ws.textAll(buf);
}

void relayBegin() {
  pinMode(RELAY_IN1, OUTPUT);
  pinMode(RELAY_IN2, OUTPUT);
  digitalWrite(RELAY_IN1, RELAY_ON);
  digitalWrite(RELAY_IN2, RELAY_ON);
  Serial.println("[RELAY] Kedua channel relay ON.");
}

// ============================================================
// SETUP & LOOP
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("=== SENAGARDA ROVER - MODE REMOTE WIFI (WEBSOCKET) ===");
  Serial.println("=== KONFIGURASI MOTOR PARALEL ===");
  relayBegin();  
  pinMode(PIN_ESTOP, INPUT_PULLUP);
  motor.begin();
  if (!imuSensor.begin()) {
    Serial.println("ERROR: BNO055 tidak terdeteksi.");
    while (true) { motor.stop(); delay(10); }
  }
  Serial.println("BNO055 siap.");
  Serial.println("Diamkan rover sebentar utk kalibrasi gyro...");
  uint8_t sys, gyro, accel, mag;
  unsigned long t0 = millis();
  while (millis() - t0 < 15000UL) {
    imuSensor.getCalibration(sys, gyro, accel, mag);
    if (gyro >= 3) break;
    delay(500);
  }
  imuSensor.resetHeadingRef();
  Serial.println("Heading siap.");
  if (gps.begin()) Serial.println("GPS TEL0157 siap (I2C).");
  else Serial.println("GPS TIDAK terdeteksi (cek wiring/switch I2C).");

  // --- Setup WiFi (Station + IP Statis) ---
  if (!WiFi.config(local_IP, gateway, subnet)) {
    Serial.println("Gagal mengatur IP Statis! Melanjutkan dengan IP Acak...");
  }
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Menyambungkan ke WiFi ");
  Serial.print(ssid);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nBerhasil terhubung ke WiFi!");
  Serial.print("Alamat IP ESP32 (Permanen): ");
  Serial.println(WiFi.localIP());

    // Menampilkan info penting untuk sinkronisasi di Serial Monitor
  Serial.printf("Router Anda Berjalan di Channel Wi-Fi: %d\n", WiFi.channel());
  Serial.print("SALIN MAC ADDRESS INI KE KODE PENGIRIM: ");
  Serial.println(WiFi.macAddress());

  // // Mengaktifkan mode Wi-Fi Long Range (LR) internal pada ESP32-S3
  // esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_LR);

  // // Inisialisasi ESP-NOW
  // if (esp_now_init() != ESP_OK) {
  //   Serial.println("Gagal Inisialisasi ESP-NOW di Rover");
  //   return;
  // }
  
  // // Daftarkan fungsi penangkap data (Callback)
  // esp_now_register_recv_cb(OnDataRecv);

  // --- Setup WebSocket ---
  ws.onEvent(onWsEvent);
  server.addHandler(&ws);
  server.begin();
  Serial.println("[WS] WebSocket Server berjalan di port 80 pada path /ws");

  // --- Setup LoRa E22 ---
  SerialLoRa.begin(9600, SERIAL_8N1, LORA_RX_PIN, LORA_TX_PIN);
  loraSiap = lora.begin();
  if (loraSiap) {
    ResponseStructContainer c = lora.getConfiguration();
    Configuration cfgLora = *(Configuration *)c.data;
    cfgLora.ADDH = LORA_ADDH;
    cfgLora.ADDL = LORA_ADDL;
    cfgLora.CHAN = LORA_CHAN;
    lora.setConfiguration(cfgLora, WRITE_CFG_PWR_DWN_SAVE);
    c.close();
    Serial.println("[LoRa] E22 siap (alamat & kanal diatur).");
  } else {
    Serial.println("[LoRa] E22 GAGAL diinisialisasi -- cek wiring M0/M1/AUX/RX/TX.");
  }
  
  // Inisialisasi pin tegangan
  pinMode(VOLTAGE_PIN, INPUT);
  
  Serial.println("=== SIAP MENERIMA KONEKSI DARI APP (WIFI) ===");
}
void debugGPSBerkala() {
  static unsigned long terakhir = 0;
  if (millis() - terakhir < 2000) return;
  terakhir = millis();
  Serial.printf(
    "[GPS-DEBUG] lat=%.6f lon=%.6f sat=%d adaFix()=%s\n",
    gps.lat(), gps.lon(), gps.jumlahSatelit(),
    gps.adaFix() ? "YA" : "TIDAK"
  );
}
void cekLoRaMasuk() {
  if (!loraSiap) return;
  if (!lora.available()) return;
  ResponseContainer rc = lora.receiveMessage();
  if (rc.status.code != 1) return;
  String pesan = rc.data;
  pesan.trim();
  if (!pesan.startsWith("C:")) return;
  String cmd = pesan.substring(2);
  cmd.trim();
  Serial.printf("[LoRa] Perintah dari Control: \"%s\"\n", cmd.c_str());
  rutePerintahMasuk(cmd);
}
void kirimStatusLoRaBerkala() {
  static unsigned long terakhir = 0;
  if (millis() - terakhir < 1500) return;
  terakhir = millis();
  if (!loraSiap) return;
  const char *modeStr = (modeSekarang == MODE_AUTO) ? "A" : "M";
  double latKirim = gps.lat();
  double lonKirim = gps.lon();
  float headingKirim = HeadingSensor::normalize(
    imuSensor.getHeading() + offsetHeadingVsGPS
  );
  int battPercent = map(analogRead(VOLTAGE_PIN), 0, 4095, 0, 100);
  battPercent = constrain(battPercent, 0, 100);
  char buf[100];
  snprintf(buf, sizeof(buf), "ST:%s,%.1f,%.6f,%.6f,%d,%d,%d",
    modeStr, headingKirim, latKirim, lonKirim,
    gps.jumlahSatelit(), sedangRekam ? 1 : 0, battPercent);
  lora.sendMessage(String(buf));
}
void loop() {
  ws.cleanupClients();
  if (mintaJalankanPath) {
    mintaJalankanPath = false;
    mulaiJalankanPath(dataPathPending);
  }
  if (mintaKalibrasiArah) {
    mintaKalibrasiArah = false;
    Serial.println("[KALIBRASI ARAH] Diminta operator -- rover maju ~2m...");
    kalibrasiHeadingViaGPS();
  }
  cekLoRaMasuk();
  prosesGerakTick();
  kirimStatusBerkala();
  kirimStatusLoRaBerkala();
  debugGPSBerkala();

}
