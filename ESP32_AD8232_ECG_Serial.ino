// ========================================================================
// ESP32 + AD8232 ECG acquisition for MATLAB dashboard
// Sends one ADC value per line at 250 samples/second over Serial.
// ========================================================================

const int ECG_PIN = 4;                 // AD8232 OUTPUT -> ESP32 ADC pin
const int FS = 250;                    // samples per second
const uint32_t TS_US = 1000000UL / FS; // 4000 microseconds

// Optional lead-off pins. Set USE_LEADS_OFF true only if LO+ and LO- are wired.
const bool USE_LEADS_OFF = false;
const int LO_PLUS_PIN  = 25;
const int LO_MINUS_PIN = 26;

uint32_t nextSampleTime;

void setup() {
  Serial.begin(115200);
  delay(1000);

  analogReadResolution(12);                    // 0 to 4095
  analogSetPinAttenuation(ECG_PIN, ADC_11db);  // wider input range

  if (USE_LEADS_OFF) {
    pinMode(LO_PLUS_PIN, INPUT);
    pinMode(LO_MINUS_PIN, INPUT);
  }

  nextSampleTime = micros();
}

void loop() {
  if ((int32_t)(micros() - nextSampleTime) >= 0) {
    nextSampleTime += TS_US;

    if (USE_LEADS_OFF && (digitalRead(LO_PLUS_PIN) == HIGH || digitalRead(LO_MINUS_PIN) == HIGH)) {
      Serial.println("LEADS_OFF");
    } else {
      int adc = analogRead(ECG_PIN);
      Serial.println(adc);
    }
  }
}
