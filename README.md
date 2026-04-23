# Allocare

Allocare is a data-driven resource allocation system designed to help NGOs convert fragmented, unstructured data into actionable decisions and real-world impact.

---

## 🚀 Problem

NGOs and social organizations collect valuable data through:
- paper surveys  
- field reports  
- spreadsheets  
- on-ground observations  

However, this data is **scattered, inconsistent, and unstructured**, leading to:

- poor visibility of real needs  
- inefficient resource allocation  
- delayed response to critical situations  
- over-served and under-served regions  

The core issue is **not lack of resources**, but **misallocation due to fragmented data**.

---

## 💡 Solution

Allocare transforms fragmented NGO data into a structured, intelligent system that enables:

- unified visibility of needs  
- priority-based resource allocation  
- smart volunteer coordination  
- insight-driven decision making  

Instead of a simple listing platform, Allocare acts as a **decision and action system**.

---

## 🧠 Core System Layers

### 1. Data & Visibility Layer
- Collects data from multiple sources (manual input, uploads)
- Converts unstructured data into structured format
- Displays needs on a unified map

---

### 2. Priority & Allocation Layer
- Classifies needs based on urgency and impact
- Enables intelligent assignment of volunteers
- Tracks status: pending → assigned → completed

---

### 3. Insight Layer (Key Differentiator)
- Identifies recurring patterns from historical data
- Highlights critical trends (e.g., malnutrition zones)
- Recommends targeted NGO interventions

---

## 🔑 Core Features (Current Progress)

### ✅ Authentication
- Email/password login & signup (Firebase Auth)
- Role-based access:
  - NGO
  - Volunteer
  - Admin (approval layer)

---

### 🧱 Application Shell
- Bottom navigation structure:
  - Home
  - Needs
  - Map (placeholder)
  - Insights
  - Profile
- Feature-based scalable architecture

---

### 🧾 Needs Management (Planned UI Ready)
- Add and manage needs
- Categories:
  - Medical
  - Food & Nutrition
  - Shelter
  - Disaster
  - Mental Health
  - Education
  - Elderly Care
  - Livelihood
  - Women Safety
  - Others

---

### 📊 Insights System (Planned)
- Area-based and city-level insights
- Pattern detection from data
- Actionable recommendations

---

### 🗺️ Map (In Progress)
- Placeholder implemented
- Planned:
  - medical pins
  - food heatmaps
  - urgency visualization

---

## 🛠️ Tech Stack

- **Flutter** – Cross-platform frontend (Android, iOS, Web)
- **Firebase Authentication** – User authentication
- **Cloud Firestore (Standard, Regional - asia-south1)** – Database
- **Google Maps (planned)** – Visualization
- **Gemini (planned)** – NLP-based classification

---

## 🧩 Architecture

- Feature-based modular structure
- Clean separation of UI, models, and logic
- Scalable and maintainable codebase

---

## 👥 User Roles

### NGO
- submit and manage needs  
- view insights and trends  
- coordinate resources  

### Volunteer
- view assigned tasks  
- execute on-ground actions  

### Admin (system-level)
- verify NGOs (no UI, controlled via backend)

---

## 🎯 Vision

Allocare is designed to move beyond static dashboards and become a **real-time decision engine for social impact**, ensuring that:

> The right help reaches the right place at the right time.

---

## 📌 Status

🚧 Active Development  
- Auth completed  
- App structure completed  
- Core features under development  

---

## 🤝 Team

Built as part of the Google Solution Challenge.
