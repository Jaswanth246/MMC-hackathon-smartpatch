# VIGILIS
### Smart Diabetic Complication Monitoring System

VIGILIS is a proof-of-concept healthcare monitoring system designed to support the early detection of diabetic complications by combining simulated biochemical data with plantar pressure monitoring. The project demonstrates how multiple health parameters can be integrated into a single platform for continuous patient monitoring.

> **Note:** This prototype does **not** include a functional microneedle patch. The biochemical sensor values (glucose, urea, and creatinine) are simulated using potentiometers to demonstrate the complete hardware, software, and communication workflow.

---

## Overview

Diabetes can lead to serious complications such as diabetic foot ulcers and kidney disease if changes in physiological parameters are not detected early.

VIGILIS demonstrates a wearable monitoring ecosystem consisting of:

- Simulated biochemical parameter monitoring
- Smart insole pressure sensing
- Bluetooth Low Energy (BLE) communication
- Mobile application for real-time visualization
- Cloud-based data storage
- Doctor dashboard for remote monitoring

---

## Features

- Real-time monitoring of simulated glucose, urea, and creatinine values
- Foot pressure monitoring using Force Sensitive Resistors (FSRs)
- BLE communication between hardware and mobile application
- Firebase Realtime Database integration
- Patient mobile application
- Doctor dashboard for remote access
- Continuous data visualization

---

## System Architecture

```
Potentiometers (Simulated Biochemical Values)
                    │
                    ▼
               ESP32 Module
                    │
          Bluetooth Low Energy
                    │
                    ▼
           Flutter Mobile App
                    │
             Firebase Database
                    │
                    ▼
          Doctor Monitoring Dashboard

Smart Insole (FSR Sensors)
            │
            ▼
        ESP32 Module
```

---

## Hardware Used

### Biochemical Module

- ESP32
- Potentiometers (used to simulate glucose, urea, and creatinine readings)

### Smart Insole

- ESP32
- 8 Force Sensitive Resistors (FSRs) per foot

### Communication

- Bluetooth Low Energy (BLE)

---

## Software Stack

- Flutter
- Firebase Realtime Database
- Arduino IDE
- ESP32 BLE Library

---

## Working Principle

1. Potentiometers generate variable analog values that simulate biochemical sensor readings.
2. FSR sensors measure pressure distribution across the foot.
3. ESP32 transmits both datasets using BLE.
4. The Flutter application receives and displays the data in real time.
5. Data is uploaded to Firebase.
6. Doctors can monitor patient information through the dashboard.

---

## Prototype Demonstration

The implemented prototype successfully demonstrates:

- Simulated biochemical monitoring
- Plantar pressure monitoring
- BLE communication
- Mobile application interface
- Cloud connectivity
- Remote monitoring workflow

The project validates the overall architecture while using simulated biochemical inputs instead of an actual microneedle sensing patch.

---

## Future Scope

- Integration of a real microneedle biosensing patch
- Continuous non-invasive biochemical monitoring
- AI-based diabetic complication prediction
- Alert system for abnormal readings
- Long-term patient analytics
- Clinical validation and testing

---

## Applications

- Remote diabetic patient monitoring
- Early diabetic foot ulcer detection
- Continuous health tracking
- Telemedicine
- Smart healthcare systems

---

## Project Status

✅ Hardware Prototype Completed

✅ Mobile Application Developed

✅ BLE Communication Implemented

✅ Firebase Integration Completed

✅ Pressure Monitoring Implemented

✅ Biochemical Data Simulation Completed

⬜ Real Microneedle Patch Integration (Future Work)

---

## Team

Developed as part of an academic healthcare innovation project demonstrating an integrated wearable monitoring system for diabetic complication detection.

---

## Disclaimer

This project is a proof-of-concept prototype intended for educational and research purposes. The biochemical measurements demonstrated in this prototype are simulated using potentiometers and are **not** obtained from actual biosensors or a functional microneedle patch. The proposed microneedle sensing system remains part of the future implementation.
