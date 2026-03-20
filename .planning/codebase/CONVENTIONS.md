# Codebase Conventions

This document outlines the coding conventions, style guidelines, naming conventions, and best practices observed in the Enchiridion codebase.

## 1. Frontend (Next.js / React)

### Framework & Architecture
- **Framework:** Next.js (Version 16+) with the App Router architecture (`src/app`).
- **Language:** TypeScript (`.ts`, `.tsx`). Strict typing is encouraged.
- **Components:** React functional components. UI components are located in the `src/components/` directory.
- **Routing:** Handled via Next.js App Router conventions (e.g., `page.tsx`, `layout.tsx`).

### Styling
- **CSS Modules:** Styling is heavily scoped using CSS Modules (`*.module.css`), ensuring styles are encapsulated at the component or page level.
- **Global Styles:** General variables and reset styles are managed in `src/app/globals.css` and `src/app/variables.css`.
- **Vanilla CSS:** The project prefers Vanilla CSS over utility-first frameworks like TailwindCSS.

### Naming Conventions
- **Files & Components:** PascalCase for React component files (e.g., `BookCarousel.tsx`, `AppSection.tsx`).
- **CSS Modules:** PascalCase matching the component name (e.g., `BookCarousel.module.css`).
- **Variables & Functions:** camelCase for standard variables, hooks, and functions.

### Tooling & Best Practices
- **Linting:** ESLint is configured with `eslint-config-next` and TypeScript rules. Run linting checks using `npm run lint`.
- **Imports:** Absolute imports (using `@/`) are preferred for internal modules (e.g., `@/components/BookCarousel`).
- **Aesthetics & UI:** The UI uses specialized visual effects (ambient glows, smoke ribbons, floating particles), which are styled through advanced CSS animations and layout properties.

## 2. Backend (Python / FastAPI)

### Framework & Architecture
- **Framework:** FastAPI.
- **Language:** Python 3.x.
- **Project Structure:** Code is modularized inside the `backend/app/` directory with clear separation of concerns:
  - `main.py`: Entry point and global middleware/app configuration.
  - `auth.py`: Authentication logic (`fastapi-users`).
  - `models.py`: Data models and schemas.
  - `routers/`: Endpoint definitions split by domain (e.g., `referral.py`, `reviews.py`).
  - `scripts/`: Standalone scripts for maintenance or reports.

### Naming Conventions
- **Files & Modules:** snake_case for Python modules and files (e.g., `test_api.py`, `main.py`).
- **Classes/Models:** PascalCase for Pydantic models and classes (e.g., `UserRead`, `UserCreate`).
- **Functions & Variables:** snake_case for standard functions and variables.

### Best Practices
- **Routing:** Endpoints are modularized using `APIRouter` and included in the main app with specific `prefix` and `tags` for Swagger UI organization.
- **Validation:** Pydantic is used for robust request and response data validation.
- **Asynchronous Code:** Heavy use of `async`/`await` for non-blocking I/O operations, particularly around API requests and database interactions.
- **Dependencies:** Integrations (like Google Sheets via `gspread`) use asynchronous patterns or background tasks where applicable.
