# Directory and File Structure

## Root Level
- `backend/`: Contains the FastAPI application and related Python scripts.
- `frontend/`: Contains the Next.js frontend application.
- `.planning/`: Project management and architectural documentation.
- **Utility Scripts:** A large collection of Python scripts in the root (e.g., `check_leaderboard.py`, `diagnose_user.py`, `simulate_reg.py`, `verify_hash.py`). These scripts are used for data auditing, user diagnostics, migrations, and direct interactions with the data layer (Google Sheets).

## Backend (`backend/`)
- `app/`: The core FastAPI application.
  - `main.py`: The entry point of the FastAPI application. Sets up CORS, initializes auth, and includes routers.
  - `auth.py`: Authentication configuration using `fastapi-users`.
  - `models.py`: Pydantic/Database models representing data structures.
  - `sheets.py`: Google Sheets integration logic.
  - `routers/`: Modular API endpoints (e.g., `referral.py`, `reviews.py`).
- `scripts/`: Operational scripts like `monthly_report.gs` and `check_reviews_data.py`.
- `tests/`: Automated tests for the API.
- **Diagnostic Scripts:** Various Python scripts (e.g., `clean_headers.py`, `diag_robust.py`, `test_paystack_webhook.py`) used for maintenance and testing.

## Frontend (`frontend/`)
- `src/app/`: Next.js App Router directories defining the application pages.
  - Core pages: `/about`, `/admin`, `/books`, `/dashboard`, `/refer`, `/reset-password`, `/reviews`, `/rewards`.
  - `layout.tsx`, `page.tsx`: Root layout and home page.
  - `globals.css`, `variables.css`: Global styles.
- `src/components/`: Reusable React components (e.g., `Header.tsx`, `Footer.tsx`, `BookCarousel.tsx`, `AdminTestConsole.tsx`).
- `public/`: Static assets including images, covers, SVGs, and backgrounds.
- `GoogleSheetsBackend.gs`: Google Apps Script likely used for triggering frontend/backend data sync.
- Configuration Files: `package.json`, `next.config.ts`, `tsconfig.json`, `eslint.config.mjs` managing build settings, dependencies, and linting.