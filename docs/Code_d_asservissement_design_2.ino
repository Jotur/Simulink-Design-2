#include <Arduino.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

/*
  Arduino Mega
  PWM 10 bits sur pin 11 (OC1A, Timer1)
  Frequence PWM = 15.625 kHz

  Fonctions :
    - Stabilite du courant plus robuste en regime permanent
    - Tarage
    - Calibration masse lineaire/quadratique automatique
    - Memorisation poids d'un objet
    - Comptage d'objets
    - Telemetrie serie
    - Reglage serie de pos_ref_V et des regulateurs
    - Arret / reprise de l'asservissement

  Commandes serie :
    C                     -> calibration masse
    T                     -> tare
    P                     -> memoriser objet
    R                     -> effacer objet
    STOP                  -> arret asservissement
    START                 -> reprise asservissement
    <nombre>              -> change pos_ref_V si entre 0 et 5
    POSREF=<v>            -> change pos_ref_V
    KC_POS=<v>
    TI_POS=<v>
    TD_POS=<v>
    KC_I=<v>
    TI_I=<v>
*/

const uint8_t PIN_CUR_SENSE = A15;
const uint8_t PIN_POS_SENSE = A8;
const uint8_t PIN_PWM_OUT   = 11;

// ------------------------- ADC / conversion -------------------------
const float VREF    = 5.0f;
const float ADC_MAX = 1023.0f;

const float VCUR_ZERO = 2.5f;
const float K_SENSE_I = 1.10f;
const float K_AMP_I   = 0.95f;

// ------------------------- Echantillonnage -------------------------
const uint32_t TS_INNER_US = 2000;
const float TS_INNER = 0.002f;

const uint8_t OUTER_DIV = 1;
const float TS_OUTER = TS_INNER * OUTER_DIV;

// ------------------------- Consigne -------------------------
volatile float pos_ref_V = 1.8f;

// ------------------------- Saturations -------------------------
const float IREF_MAX = 2.35f;
const float IREF_MIN = -2.35f;

const float U_MAX_V = 5.0f;
const float U_MIN_V = 0.0f;

// ------------------------- Regulateur position : PID -------------------------
float KC_POS = 0.85f;
float TI_POS = 0.30f;
float TD_POS = 0.020f;

float k1_pos = 0.0f;
float k2_pos = 0.0f;
float k3_pos = 0.0f;

float e_pos_0 = 0.0f;
float e_pos_1 = 0.0f;
float e_pos_2 = 0.0f;
float u_pos_1 = 0.0f;
float posIntegral_A = 0.0f;

const float POS_DEADBAND = 0.010f;
const float POS_NEAR_P_SCALE = 0.15f;  // P reduit pres de la consigne
const float POS_D_NEAR_BAND = 0.01f;    // zone ou D est attenue pres de la consigne
const float POS_D_NEAR_SCALE = 0.01f;   // D minimal pres de la consigne
const uint32_t POS_SETTLE_HOLD_MS = 250; // temps stable avant gel de Iref
const float POS_HOLD_RELEASE_BAND = 0.06f; // on sort du mode hold si l'erreur redevient trop grande
const float POS_HOLD_TRACK_ERR_BAND_A = 0.015f;
const float IREF_STEP_MAX = 1.8f;

// ------------------------- Regulateur courant : PI -------------------------
float KC_I  = 0.18f;
float TI_I  = 0.001f;

float k1_i = 0.0f;
float k2_i = 0.0f;

float e_i_0 = 0.0f;
float e_i_1 = 0.0f;
float u_i_1 = 0.0f;

// ------------------------- Moyenne ADC -------------------------
const uint8_t ADC_AVG_SAMPLES = 16;

// ------------------------- Filtre position -------------------------
const float ALPHA_POS = 0.5f;
float pos_filt_V = 2.5f;

// ------------------------- Mesure courant robuste -------------------------
const uint8_t CURR_AVG_N = 80;
float currBufA[CURR_AVG_N];
uint8_t currBufIndex = 0;
uint8_t currBufCount = 0;
float currBufSumA = 0.0f;
float currentAvgFast_A = 0.0f;

float currentAvgSlow_A = 0.0f;
const float ALPHA_CURR_SLOW = 0.04f;

const uint8_t STAB_BUF_N = 40;
float stabBufA[STAB_BUF_N];
uint8_t stabIndex = 0;
uint8_t stabCount = 0;
bool currentStable = false;

const float STABILITY_BAND_A = 0.002f;
const float TRACKING_ERR_BAND_A = 0.035f;
float currentBand_A = 0.0f;
float currentTrackingErr_A = 0.0f;

// ------------------------- Calibration masse -------------------------
bool calibrationMode = false;
bool massCalibrated = false;

enum MassModelType {
  MASS_MODEL_LINEAR = 1,
  MASS_MODEL_QUADRATIC = 2
};

MassModelType massModelType = MASS_MODEL_LINEAR;
float massCoeff1 = 0.0f;
float massCoeff2 = 0.0f;
float massIntercept_g = 0.0f;
float massFitRmse_g = 0.0f;

const uint8_t CALIB_N = 7;
float calibCurrentA[CALIB_N];
float calibCurrentAbsA[CALIB_N];
float calibStableFlag[CALIB_N];
float calibMassG[CALIB_N] = {0.0f, 1.0f, 5.0f, 10.0f, 20.0f, 50.0f, 70.0f};

float massEst_g = 0.0f;
float massNet_g = 0.0f;
const float MASS_MAX_G = 200.0f;

// ------------------------- Tarage / comptage -------------------------
float tareOffset_g = 0.0f;
bool tareActive = false;

float pieceWeight_g = 0.0f;
bool pieceWeightValid = false;

int identicalObjectCount = 0;
bool countIsIntegerValid = false;
const float COUNT_TOL = 0.12f;
const float MIN_PIECE_G = 0.5f;

// ------------------------- Etats debug -------------------------
float g_pos_meas_V_raw = 2.5f;
float g_pos_meas_V = 2.5f;
float g_cur_meas_V = 2.5f;
float g_i_meas_A = 0.0f;
float g_i_ref_A = 0.0f;
float g_u_cmd_sat_V = 2.5f;
bool controlEnabled = true;
bool posHoldActive = false;
uint32_t posNearTargetSinceMs = 0;
float posHoldIref_A = 0.0f;

// ------------------------- Outils -------------------------
static inline float clampf(float x, float lo, float hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}

static inline float adcToVolts(int adc) {
  return (adc * VREF) / ADC_MAX;
}

static inline uint16_t voltsToPwm10bits(float v) {
  v = clampf(v, 0.0f, VREF);
  int pwm = (int)lroundf((v / VREF) * 1023.0f);
  if (pwm < 0) pwm = 0;
  if (pwm > 1023) pwm = 1023;
  return (uint16_t)pwm;
}

int analogReadAverage(uint8_t pin, uint8_t nSamples) {
  uint32_t sum = 0;
  for (uint8_t i = 0; i < nSamples; i++) {
    sum += analogRead(pin);
  }
  return (int)(sum / nSamples);
}

void msg(const char* s) {
  Serial.print("MSG,");
  Serial.println(s);
}

void msgFloat(const char* label, float v, int digits = 3) {
  Serial.print("MSG,");
  Serial.print(label);
  Serial.print("=");
  Serial.println(v, digits);
}

void recomputeControllers() {
  if (TI_POS <= 0.0f) TI_POS = 1e-6f;
  if (TI_I <= 0.0f) TI_I = 1e-6f;
  if (TD_POS < 0.0f) TD_POS = 0.0f;

  k1_pos = KC_POS * (1.0f + TS_OUTER / TI_POS + TD_POS / TS_OUTER);
  k2_pos = KC_POS * (-1.0f - 2.0f * TD_POS / TS_OUTER);
  k3_pos = KC_POS * (TD_POS / TS_OUTER);

  k1_i = KC_I * (1.0f + TS_INNER / TI_I);
  k2_i = -KC_I;
}

void resetControllerStates() {
  e_pos_0 = e_pos_1 = e_pos_2 = 0.0f;
  e_i_0 = e_i_1 = 0.0f;
  u_pos_1 = 0.0f;
  posIntegral_A = 0.0f;
  u_i_1 = 0.0f;
  g_i_ref_A = 0.0f;
}

void setActuatorNeutral() {
  g_u_cmd_sat_V = VCUR_ZERO;
  OCR1A = voltsToPwm10bits(VCUR_ZERO);
}

// ------------------------- PWM Timer1 pin 11 -------------------------
void setupPwm15625Hz_Timer1_OC1A() {
  pinMode(PIN_PWM_OUT, OUTPUT);

  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1  = 0;

  TCCR1A |= (1 << WGM10) | (1 << WGM11);
  TCCR1B |= (1 << WGM12);

  TCCR1A |= (1 << COM1A1);
  TCCR1B |= (1 << CS10);

  OCR1A = voltsToPwm10bits(VCUR_ZERO);
}

void setupFastADC() {
  ADCSRA = (ADCSRA & 0b11111000) | 0b100;
}

void updateCurrentFilters(float i_meas_A) {
  if (currBufCount < CURR_AVG_N) {
    currBufA[currBufIndex] = i_meas_A;
    currBufSumA += i_meas_A;
    currBufCount++;
  } else {
    currBufSumA -= currBufA[currBufIndex];
    currBufA[currBufIndex] = i_meas_A;
    currBufSumA += i_meas_A;
  }

  currBufIndex++;
  if (currBufIndex >= CURR_AVG_N) currBufIndex = 0;

  currentAvgFast_A = (currBufCount > 0) ? (currBufSumA / (float)currBufCount) : 0.0f;
  currentAvgSlow_A += ALPHA_CURR_SLOW * (currentAvgFast_A - currentAvgSlow_A);
}

void updateStability(float iAvgA) {
  stabBufA[stabIndex] = iAvgA;
  stabIndex++;
  if (stabIndex >= STAB_BUF_N) stabIndex = 0;

  if (stabCount < STAB_BUF_N) stabCount++;

  currentTrackingErr_A = fabs(currentAvgFast_A - g_i_ref_A);

  if (stabCount < STAB_BUF_N) {
    currentStable = false;
    currentBand_A = 999.0f;
    return;
  }

  float minV = stabBufA[0];
  float maxV = stabBufA[0];

  for (uint8_t i = 1; i < STAB_BUF_N; i++) {
    if (stabBufA[i] < minV) minV = stabBufA[i];
    if (stabBufA[i] > maxV) maxV = stabBufA[i];
  }

  currentBand_A = maxV - minV;
  bool noiseOk = (currentBand_A <= STABILITY_BAND_A);
  bool trackingOk = (currentTrackingErr_A <= TRACKING_ERR_BAND_A);
  currentStable = noiseOk && trackingOk;
}

float evalMassModel(float currentAbsA) {
  if (!massCalibrated) return 0.0f;

  float x = fabs(currentAbsA);
  float m = massIntercept_g;

  if (massModelType == MASS_MODEL_LINEAR) {
    m += massCoeff1 * x;
  } else {
    m += massCoeff1 * x + massCoeff2 * x * x;
  }

  return clampf(m, 0.0f, MASS_MAX_G);
}

bool fitLinearModel(const float *x, const float *y, uint8_t n, float &a1, float &b, float &rmse) {
  if (n < 2) return false;

  float sumX = 0.0f, sumY = 0.0f, sumXY = 0.0f, sumX2 = 0.0f;
  for (uint8_t i = 0; i < n; i++) {
    sumX += x[i];
    sumY += y[i];
    sumXY += x[i] * y[i];
    sumX2 += x[i] * x[i];
  }

  float den = n * sumX2 - sumX * sumX;
  if (fabs(den) < 1e-9f) return false;

  a1 = (n * sumXY - sumX * sumY) / den;
  b = (sumY - a1 * sumX) / n;

  float mse = 0.0f;
  for (uint8_t i = 0; i < n; i++) {
    float err = (a1 * x[i] + b) - y[i];
    mse += err * err;
  }
  rmse = sqrtf(mse / n);
  return true;
}

bool fitQuadraticModel(const float *x, const float *y, uint8_t n, float &a2, float &a1, float &b, float &rmse) {
  if (n < 3) return false;

  float Sx = 0.0f, Sx2 = 0.0f, Sx3 = 0.0f, Sx4 = 0.0f;
  float Sy = 0.0f, Sxy = 0.0f, Sx2y = 0.0f;

  for (uint8_t i = 0; i < n; i++) {
    float xi = x[i];
    float xi2 = xi * xi;
    Sx += xi;
    Sx2 += xi2;
    Sx3 += xi2 * xi;
    Sx4 += xi2 * xi2;
    Sy += y[i];
    Sxy += xi * y[i];
    Sx2y += xi2 * y[i];
  }

  float A[3][4] = {
    {(float)n, Sx,  Sx2, Sy},
    {Sx,  Sx2, Sx3, Sxy},
    {Sx2, Sx3, Sx4, Sx2y}
  };

  for (uint8_t i = 0; i < 3; i++) {
    float pivot = A[i][i];
    if (fabs(pivot) < 1e-9f) return false;

    for (uint8_t j = i; j < 4; j++) A[i][j] /= pivot;

    for (uint8_t k = 0; k < 3; k++) {
      if (k == i) continue;
      float factor = A[k][i];
      for (uint8_t j = i; j < 4; j++) {
        A[k][j] -= factor * A[i][j];
      }
    }
  }

  b  = A[0][3];
  a1 = A[1][3];
  a2 = A[2][3];

  float mse = 0.0f;
  for (uint8_t i = 0; i < n; i++) {
    float yi = b + a1 * x[i] + a2 * x[i] * x[i];
    float err = yi - y[i];
    mse += err * err;
  }
  rmse = sqrtf(mse / n);
  return true;
}

bool fitMassCurve(const float *currAbsA, const float *massG, uint8_t n) {
  float linA1 = 0.0f, linB = 0.0f, linRmse = 0.0f;
  float quadA2 = 0.0f, quadA1 = 0.0f, quadB = 0.0f, quadRmse = 0.0f;

  bool okLin = fitLinearModel(currAbsA, massG, n, linA1, linB, linRmse);
  bool okQuad = fitQuadraticModel(currAbsA, massG, n, quadA2, quadA1, quadB, quadRmse);

  if (!okLin && !okQuad) return false;

  if (okQuad && (!okLin || quadRmse < linRmse * 0.98f)) {
    massModelType = MASS_MODEL_QUADRATIC;
    massCoeff1 = quadA1;
    massCoeff2 = quadA2;
    massIntercept_g = quadB;
    massFitRmse_g = quadRmse;
  } else {
    massModelType = MASS_MODEL_LINEAR;
    massCoeff1 = linA1;
    massCoeff2 = 0.0f;
    massIntercept_g = linB;
    massFitRmse_g = linRmse;
  }

  return true;
}

void updateMassEstimate() {
  if (massCalibrated) {
    massEst_g = evalMassModel(currentAvgSlow_A);
  } else {
    massEst_g = 0.0f;
  }

  massNet_g = massEst_g - tareOffset_g;
  if (massNet_g < 0.0f) massNet_g = 0.0f;
}

void updateObjectCount() {
  countIsIntegerValid = false;
  identicalObjectCount = 0;

  if (!pieceWeightValid) return;
  if (!currentStable) return;
  if (pieceWeight_g < MIN_PIECE_G) return;

  float ratio = massNet_g / pieceWeight_g;

  if (ratio < 0.25f) {
    identicalObjectCount = 0;
    countIsIntegerValid = true;
    return;
  }

  int nearestInt = (int)lroundf(ratio);
  float err = fabs(ratio - (float)nearestInt);

  if (err <= COUNT_TOL) {
    identicalObjectCount = nearestInt;
    if (identicalObjectCount < 0) identicalObjectCount = 0;
    countIsIntegerValid = true;
  }
}

bool readLineNonBlocking(char *buf, uint8_t bufSize, bool &lineReady) {
  static uint8_t idx = 0;
  lineReady = false;

  while (Serial.available()) {
    char c = (char)Serial.read();

    if (c == '\n' || c == '\r') {
      buf[idx] = '\0';
      idx = 0;
      lineReady = true;
      return true;
    }

    if (idx < bufSize - 1) {
      buf[idx++] = c;
    }
  }

  return false;
}

void waitForEnterKeepingControl(const char *message);
float captureStableCurrentAverageA(uint32_t duration_ms, bool &wasStable);
void runMassCalibration();
void handleNormalSerial();
void runControlStep();
void sendTelemetry();

void runControlStep() {
  static uint32_t last_us = micros();
  uint32_t now = micros();

  if ((uint32_t)(now - last_us) < TS_INNER_US) return;
  last_us += TS_INNER_US;

  int pos_adc_avg = analogReadAverage(PIN_POS_SENSE, ADC_AVG_SAMPLES);
  int cur_adc_avg = analogReadAverage(PIN_CUR_SENSE, ADC_AVG_SAMPLES);

  float pos_meas_V_raw = adcToVolts(pos_adc_avg);
  float cur_meas_V = adcToVolts(cur_adc_avg);

  pos_filt_V = pos_filt_V + ALPHA_POS * (pos_meas_V_raw - pos_filt_V);
  float pos_meas_V = pos_filt_V;

  float i_meas_A = (cur_meas_V - VCUR_ZERO) / K_SENSE_I;

  updateCurrentFilters(i_meas_A);
  updateStability(currentAvgSlow_A);

  g_pos_meas_V_raw = pos_meas_V_raw;
  g_pos_meas_V = pos_meas_V;
  g_cur_meas_V = cur_meas_V;
  g_i_meas_A = i_meas_A;

  if (!controlEnabled) {
    resetControllerStates();
    setActuatorNeutral();
    updateMassEstimate();
    updateObjectCount();
    return;
  }

  e_pos_0 = pos_meas_V - pos_ref_V;
  bool nearTarget = (fabs(e_pos_0) < POS_DEADBAND);
  bool trackingHoldOk = (fabs(currentAvgFast_A - g_i_ref_A) < POS_HOLD_TRACK_ERR_BAND_A);
  uint32_t nowMs = millis();

  if (posHoldActive) {
    if (fabs(e_pos_0) > POS_HOLD_RELEASE_BAND) {
      posHoldActive = false;
      posNearTargetSinceMs = 0;
    }
  } else {
    if (nearTarget && currentStable && trackingHoldOk) {
      if (posNearTargetSinceMs == 0) {
        posNearTargetSinceMs = nowMs;
      } else if ((uint32_t)(nowMs - posNearTargetSinceMs) >= POS_SETTLE_HOLD_MS) {
        posHoldActive = true;
        posHoldIref_A = g_i_ref_A;
      }
    } else {
      posNearTargetSinceMs = 0;
    }
  }

  float u_pos_0 = u_pos_1;

  if (posHoldActive) {
    g_i_ref_A = posHoldIref_A;
  } else {
    float p_pos = KC_POS * e_pos_0;

    float d_raw = KC_POS * TD_POS * ((e_pos_0 - e_pos_1) / TS_OUTER);
    float absErr = fabs(e_pos_0);
    float d_scale = 1.0f;
    if (absErr < POS_D_NEAR_BAND) {
      float x = absErr / POS_D_NEAR_BAND;  // 0 au centre, 1 au bord de la zone
      d_scale = POS_D_NEAR_SCALE + (1.0f - POS_D_NEAR_SCALE) * x;
    }
    float d_pos = d_raw * d_scale;

    if (nearTarget) {
      p_pos *= POS_NEAR_P_SCALE;
    } else {
      posIntegral_A += KC_POS * (TS_OUTER / TI_POS) * e_pos_0;
      posIntegral_A = clampf(posIntegral_A, IREF_MIN, IREF_MAX);
    }

    u_pos_0 = p_pos + posIntegral_A + d_pos;
    float i_ref_target = clampf(u_pos_0, IREF_MIN, IREF_MAX);

    float delta = i_ref_target - g_i_ref_A;
    delta = clampf(delta, -IREF_STEP_MAX, IREF_STEP_MAX);
    g_i_ref_A += delta;
  }

  u_pos_1 = u_pos_0;

  e_pos_2 = e_pos_1;
  e_pos_1 = e_pos_0;

  e_i_0 = g_i_ref_A - i_meas_A;

  float u_i_0 =
      u_i_1
    + k1_i * e_i_0
    + k2_i * e_i_1;

  float u_cmd_V = VCUR_ZERO + (u_i_0 / K_AMP_I);
  float u_cmd_sat_V = clampf(u_cmd_V, U_MIN_V, U_MAX_V);

  float u_i_sat = (u_cmd_sat_V - VCUR_ZERO) * K_AMP_I;
  u_i_1 = u_i_sat;
  e_i_1 = e_i_0;

  OCR1A = voltsToPwm10bits(u_cmd_sat_V);
  g_u_cmd_sat_V = u_cmd_sat_V;

  updateMassEstimate();
  updateObjectCount();
}

void waitForEnterKeepingControl(const char *message) {
  msg("");
  msg(message);
  msg("Appuie sur Entree quand la balance est stable.");

  while (true) {
    runControlStep();
    sendTelemetry();

    while (Serial.available()) {
      char c = (char)Serial.read();
      if (c == '\n' || c == '\r') return;
    }
  }
}

float captureStableCurrentAverageA(uint32_t duration_ms, bool &wasStable) {
  uint32_t t0 = millis();
  uint32_t lastSampleMs = millis();
  float sum = 0.0f;
  uint16_t n = 0;
  bool allStable = true;

  while ((uint32_t)(millis() - t0) < duration_ms) {
    runControlStep();
    sendTelemetry();

    uint32_t nowMs = millis();
    if ((uint32_t)(nowMs - lastSampleMs) >= 20) {
      lastSampleMs += 20;
      sum += fabs(currentAvgSlow_A);
      n++;
      if (!currentStable) allStable = false;
    }
  }

  wasStable = allStable && (n > 0);
  if (n == 0) return fabs(currentAvgSlow_A);
  return sum / (float)n;
}

void runMassCalibration() {
  calibrationMode = true;

  const char* steps[CALIB_N] = {
    "Retire tout objet de la balance (0 g).",
    "Place un poids de 1 g.",
    "Place un poids de 5 g.",
    "Place un poids de 10 g.",
    "Place un poids de 20 g.",
    "Place un poids de 50 g.",
    "Place un poids de 70 g."
  };

  msg("====================================");
  msg("MODE CALIBRAGE MASSE");
  msg("Mesure utilisee : abs(iavg_slow) avec critere de stabilite durci.");
  msg("Le meilleur modele lineaire ou quadratique est choisi automatiquement.");
  msg("Important : garder la meme consigne de position.");
  msg("====================================");

  for (uint8_t i = 0; i < CALIB_N; i++) {
    waitForEnterKeepingControl(steps[i]);

    bool stepStable = false;
    float currentAbsA = captureStableCurrentAverageA(1800, stepStable);

    calibCurrentA[i] = currentAvgSlow_A;
    calibCurrentAbsA[i] = currentAbsA;
    calibStableFlag[i] = stepStable ? 1.0f : 0.0f;

    Serial.print("CALDATA,");
    Serial.print("step="); Serial.print(i + 1);
    Serial.print(",mass_g="); Serial.print(calibMassG[i], 3);
    Serial.print(",current_A="); Serial.print(calibCurrentA[i], 6);
    Serial.print(",current_abs_A="); Serial.print(calibCurrentAbsA[i], 6);
    Serial.print(",stable="); Serial.println(stepStable ? 1 : 0);
  }

  bool ok = fitMassCurve(calibCurrentAbsA, calibMassG, CALIB_N);

  if (ok) {
    massCalibrated = true;
    tareOffset_g = 0.0f;
    tareActive = false;
    msg("Calibration terminee.");
    msgFloat("massCoeff1", massCoeff1, 6);
    msgFloat("massCoeff2", massCoeff2, 6);
    msgFloat("massIntercept_g", massIntercept_g, 6);
    msgFloat("massFitRmse_g", massFitRmse_g, 6);

    Serial.print("CALRESULT,");
    Serial.print("model="); Serial.print((massModelType == MASS_MODEL_LINEAR) ? "linear" : "quadratic");
    Serial.print(",coeff1="); Serial.print(massCoeff1, 6);
    Serial.print(",coeff2="); Serial.print(massCoeff2, 6);
    Serial.print(",intercept="); Serial.print(massIntercept_g, 6);
    Serial.print(",rmse="); Serial.println(massFitRmse_g, 6);
  } else {
    massCalibrated = false;
    msg("Erreur : impossible de calculer la courbe de calibration.");
  }

  msg("Fin du mode calibrage.");
  msg("====================================");

  calibrationMode = false;
}

void sendTelemetry() {
  static uint32_t lastMs = 0;
  uint32_t nowMs = millis();
  if ((uint32_t)(nowMs - lastMs) < 100) return;
  lastMs = nowMs;

  Serial.print("DATA,");
  Serial.print("control="); Serial.print(controlEnabled ? 1 : 0);
  Serial.print(",pos_ref="); Serial.print(pos_ref_V, 3);
  Serial.print(",pos="); Serial.print(g_pos_meas_V, 3);
  Serial.print(",pos_raw="); Serial.print(g_pos_meas_V_raw, 3);
  Serial.print(",iref="); Serial.print(g_i_ref_A, 4);
  Serial.print(",imeas="); Serial.print(g_i_meas_A, 4);
  Serial.print(",curV="); Serial.print(g_cur_meas_V, 3);
  Serial.print(",iavg_fast="); Serial.print(currentAvgFast_A, 4);
  Serial.print(",iavg="); Serial.print(currentAvgSlow_A, 4);
  Serial.print(",band="); Serial.print(currentBand_A, 4);
  Serial.print(",tracking_err="); Serial.print(currentTrackingErr_A, 4);
  Serial.print(",stable="); Serial.print(currentStable ? 1 : 0);
  Serial.print(",pos_hold="); Serial.print(posHoldActive ? 1 : 0);
  Serial.print(",mass="); Serial.print(massEst_g, 2);
  Serial.print(",net="); Serial.print(massNet_g, 2);
  Serial.print(",tare="); Serial.print(tareOffset_g, 2);
  Serial.print(",piece="); Serial.print(pieceWeight_g, 2);
  Serial.print(",piece_valid="); Serial.print(pieceWeightValid ? 1 : 0);
  Serial.print(",count="); Serial.print(identicalObjectCount);
  Serial.print(",count_valid="); Serial.print(countIsIntegerValid ? 1 : 0);
  Serial.print(",u="); Serial.print(g_u_cmd_sat_V, 3);
  Serial.print(",kc_pos="); Serial.print(KC_POS, 4);
  Serial.print(",ti_pos="); Serial.print(TI_POS, 4);
  Serial.print(",td_pos="); Serial.print(TD_POS, 4);
  Serial.print(",kc_i="); Serial.print(KC_I, 4);
  Serial.print(",ti_i="); Serial.println(TI_I, 5);
}

bool startsWithKeyValue(const char *line, const char *key, float &outVal) {
  size_t n = strlen(key);
  if (strncmp(line, key, n) == 0) {
    outVal = atof(line + n);
    return true;
  }
  return false;
}

void handleNormalSerial() {
  char line[64];
  bool lineReady = false;
  readLineNonBlocking(line, sizeof(line), lineReady);

  if (!lineReady) return;
  if (strlen(line) == 0) return;

  if (strcmp(line, "C") == 0 || strcmp(line, "c") == 0) {
    runMassCalibration();
    return;
  }

  if (strcmp(line, "STOP") == 0 || strcmp(line, "stop") == 0) {
    controlEnabled = false;
    resetControllerStates();
    setActuatorNeutral();
    msg("Asservissement arrete.");
    return;
  }

  if (strcmp(line, "START") == 0 || strcmp(line, "start") == 0) {
    controlEnabled = true;
    resetControllerStates();
    msg("Asservissement relance.");
    return;
  }

  if (strcmp(line, "T") == 0 || strcmp(line, "t") == 0) {
    if (!massCalibrated) {
      msg("Tarage impossible : calibration masse non faite.");
      return;
    }
    if (!currentStable) {
      msg("Tarage refuse : courant non stable.");
      return;
    }

    tareOffset_g = massEst_g;
    tareActive = true;
    msgFloat("Tare_g", tareOffset_g, 2);
    msg("Tarage effectue.");
    return;
  }

  if (strcmp(line, "P") == 0 || strcmp(line, "p") == 0) {
    if (!massCalibrated) {
      msg("Memorisation objet impossible : calibration masse non faite.");
      return;
    }
    if (!currentStable) {
      msg("Memorisation objet refusee : courant non stable.");
      return;
    }
    if (massNet_g < MIN_PIECE_G) {
      msg("Memorisation objet refusee : masse trop petite.");
      return;
    }

    pieceWeight_g = massNet_g;
    pieceWeightValid = true;
    msgFloat("Poids_objet_g", pieceWeight_g, 2);
    msg("Reference objet memorisee.");
    return;
  }

  if (strcmp(line, "R") == 0 || strcmp(line, "r") == 0) {
    pieceWeight_g = 0.0f;
    pieceWeightValid = false;
    identicalObjectCount = 0;
    countIsIntegerValid = false;
    msg("Reference objet effacee.");
    return;
  }

  float v = 0.0f;
  if (startsWithKeyValue(line, "POSREF=", v)) {
    if (v >= 0.0f && v <= 5.0f) {
      pos_ref_V = v;
      msgFloat("Nouvelle_consigne_V", pos_ref_V, 3);
    } else {
      msg("POSREF hors plage 0..5 V");
    }
    return;
  }

  if (startsWithKeyValue(line, "KC_POS=", v)) {
    if (v > 0.0f) {
      KC_POS = v;
      recomputeControllers();
      resetControllerStates();
      msgFloat("KC_POS", KC_POS, 4);
    }
    return;
  }

  if (startsWithKeyValue(line, "TI_POS=", v)) {
    if (v > 0.0f) {
      TI_POS = v;
      recomputeControllers();
      resetControllerStates();
      msgFloat("TI_POS", TI_POS, 4);
    }
    return;
  }

  if (startsWithKeyValue(line, "TD_POS=", v)) {
    if (v >= 0.0f) {
      TD_POS = v;
      recomputeControllers();
      resetControllerStates();
      msgFloat("TD_POS", TD_POS, 4);
    }
    return;
  }

  if (startsWithKeyValue(line, "KC_I=", v)) {
    if (v > 0.0f) {
      KC_I = v;
      recomputeControllers();
      resetControllerStates();
      msgFloat("KC_I", KC_I, 4);
    }
    return;
  }

  if (startsWithKeyValue(line, "TI_I=", v)) {
    if (v > 0.0f) {
      TI_I = v;
      recomputeControllers();
      resetControllerStates();
      msgFloat("TI_I", TI_I, 5);
    }
    return;
  }

  float newRef = atof(line);
  if (newRef >= 0.0f && newRef <= 5.0f) {
    pos_ref_V = newRef;
    msgFloat("Nouvelle_consigne_V", pos_ref_V, 3);
  } else {
    msg("Commande inconnue. C/T/P/R/STOP/START/POSREF=.../KC_POS=/TI_POS=/TD_POS=/KC_I=/TI_I=");
  }
}

void setup() {
  Serial.begin(115200);

  setupPwm15625Hz_Timer1_OC1A();
  setupFastADC();
  recomputeControllers();

  for (uint8_t i = 0; i < CURR_AVG_N; i++) currBufA[i] = 0.0f;
  for (uint8_t i = 0; i < STAB_BUF_N; i++) stabBufA[i] = 0.0f;

  currentAvgFast_A = 0.0f;
  currentAvgSlow_A = 0.0f;
  setActuatorNeutral();

  msg("Systeme pret.");
  msg("Commandes : C / T / P / R / STOP / START / POSREF=... / KC_POS= / TI_POS= / TD_POS= / KC_I= / TI_I=");
}

void loop() {
  handleNormalSerial();
  runControlStep();
  sendTelemetry();
}
