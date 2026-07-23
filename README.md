# Safe-Kid: AI-Powered Telemetry & Predictive Safety Tracking System

Safe-Kid is a real-time, hybrid child tracking and safety diagnostics platform consisting of a **Flutter mobile application** (split into Guardian and Child interfaces) and a **React web portal** powered by **Firebase**.

Unlike simple CRUD GPS trackers, Safe-Kid employs local **Sensor Fusion** and **Trajectory Vector Projection** algorithms to detect anomalies and predict hazardous behaviors in real-time.

---

## 🚀 Advanced Engine Highlights

Safe-Kid implements custom algorithms directly on the device client and dashboard layers to ensure fast, battery-efficient response times:

### 1. Sensor Fusion Engine (`sensor_fusion_service.dart`)
* **Core Logic**: Fuses high-frequency accelerometer events with GPS velocity.
* **Algorithm**: Computes a rolling standard deviation variance ($Var > 1.5$ for running, $Var > 0.2$ for walking) and checks it against linear speed thresholds ($Speed \ge 15.0 \text{ km/h}$ flags `in_vehicle` states).
* **Benefit**: Allows the child app to accurately classify activities (`stationary`, `walking`, `running`, `in_vehicle`) offline and with minimal processing footprint.

### 2. AI Predictive Geofencing (`route_anomaly_detector.dart`)
* **Core Logic**: Projects the child's movement vectors forward in time.
* **Algorithm**: Evaluates the heading vector between the last 3 GPS points:
  $$\vec{V}_{avg} = \frac{(P_1 - P_2) + (P_0 - P_1)}{2}$$
  Projects the position 3 steps forward ($P_{pred} = P_0 + 3 \cdot \vec{V}_{avg}$) and evaluates if the projected coordinate crosses the boundary of any active safe zone before the departure actually occurs.
* **Benefit**: Alerts parents preemptively, giving them extra reaction time.

### 3. Spatial Outlier & Route Deviation Detection
* **Core Logic**: Detects when a child wanders off their normal, routine paths.
* **Algorithm**: Compares the active coordinates against a historical coordinate footprint database. If the minimum distance to any baseline historical coordinate exceeds $300\text{m}$, a route deviation alert is fired.

### 4. Live Device Battery & Connectivity Diagnostics
* **Core Logic**: Continuous monitoring of telemetry quality.
* **Features**: Live battery percentages, charging indicators, and specific network medium tracking (WiFi vs. Cellular vs. Offline).
* **Benefit**: Tells the parent whether the child's device is active, charging, or disconnected, allowing them to debug connectivity gaps.

---

## 📱 Tech Stack & Components

* **Mobile App (Flutter)**: Single codebase rendering parent and child interfaces based on role.
* **Web Portal (React + Vite)**: A responsive web-based command center for parents.
* **Database & Auth (Firebase)**: Firebase Auth (Anonymous & Email), Firestore streams, and Firebase Cloud Messaging (FCM) for push alerts.

---

## 🧪 Testing & Validation Methodology

### 1. Simulated Test Harness
* To safely verify extreme conditions (such as high-speed vehicular anomalies, predictive geofence exits, and offline dropouts), we implemented a simulated override mode inside the child client. This allowed developer-driven injection of arbitrary velocities and trajectory patterns.

### 2. Real-World Field Testing
To ensure the system works reliably outside of developmental environments, a real-world pilot test was performed:
* **Devices**: Tested with physical devices (Android and iOS) running the Child app telemetry loops, and another device running the Guardian app.
* **Methodology**: Carried the test device on predefined pedestrian routes (walking) and transit routes (driving) within a neighborhood.
* **Observed Metrics**:
  * **Database Sync Latency**: Average write-to-sync time on Firestore was $<500\text{ms}$ on 4G cellular networks.
  * **Transition Resiliency**: Verified seamless handoff when switching from home WiFi to mobile cellular data without losing connection states.
  * **Sensor Classification**: Accurate detection of vehicle transitions within 30 seconds of accelerating past $15\text{ km/h}$.
  * **Power Consumption**: Baseline battery level tracking verified that localized sensor calculations do not cause abnormal thermal throttling or battery drain.

---

## 🛠️ Getting Started

### Mobile App Setup (Flutter)
1. Install Flutter SDK.
2. Run `flutter pub get` to install dependencies.
3. Configure your Firebase project and add `google-services.json` (Android) or `GoogleService-Info.plist` (iOS).
4. Run the app:
   ```bash
   flutter run
   ```

### Web Dashboard Setup (React)
1. Navigate to `/safekid_web`:
   ```bash
   cd safekid_web
   npm install
   npm run dev
   ```
