# Enchiridion System Architecture

## Overview
Enchiridion is a full-stack application composed of a Next.js frontend and a FastAPI (Python) backend. The system leverages Google Sheets for data storage and management, acting as a lightweight database or CRM.

## High-Level Components

### 1. Frontend Client
- **Framework:** Next.js (React) with TypeScript.
- **Routing:** Uses Next.js App Router (`src/app`), containing routes such as `/dashboard`, `/admin`, `/books`, `/refer`, and `/rewards`.
- **UI Components:** Modular React components stored in `src/components`, styled with CSS Modules (`.module.css`).
- **Functionality:** Provides user interfaces for dashboards, referrals, reviews, and administration consoles.

### 2. Backend API
- **Framework:** FastAPI (Python).
- **Authentication:** `fastapi-users` library using JWT-based authentication.
- **Routers:** Modularized business logic:
  - `/auth`, `/users`: User registration, login, and management.
  - `/referral`: Handling referral programs, rewards, and leaderboards.
  - `/reviews`: Managing user reviews.
- **Integrations:**
  - **Google Sheets:** Integrated heavily (`app/sheets.py`, Apps Script `.gs` files) to store, sync, and process data (referrals, reviews, partnerships).
  - **Payment Gateway:** Integration with Paystack (indicated by webhook tests).

### 3. Data Layer
- Primarily relies on Google Sheets for structured data storage, avoiding traditional SQL/NoSQL databases in the current setup.
- Accompanied by various Google Apps Scripts (`GoogleSheetsBackend.gs`, `monthly_report.gs`) and Python utility scripts (`check_leaderboard.py`, `simulate_reg.py`) to manage data integrity, auditing, and reporting.

## Design Patterns
- **Client-Server Architecture:** Clear separation between the Next.js presentation layer and the FastAPI business logic API.
- **RESTful API:** The backend exposes stateless REST endpoints for the frontend to consume.
- **Modular Routing:** Both frontend and backend use modular routing to separate concerns (e.g., `referral.py` vs `reviews.py`).
- **Data-Driven Workflows:** Heavy reliance on external scripts for data manipulation, cleaning, and diagnostics outside of the main API server process.