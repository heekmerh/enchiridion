# Enchiridion - Refactor & Vercel Deployment

## Overview
The goal of this phase is to clean up the existing Enchiridion codebase and prepare it for a production-ready, full-stack deployment on Vercel. This involves removing dead code, resolving linting and typing issues, refactoring both frontend and backend components for better maintainability and performance, and configuring the build for Vercel's serverless environment.

## Core Value
A stable, optimized, and unified full-stack application (Next.js + FastAPI) hosted reliably on Vercel, with a clean and maintainable codebase.

## Constraints
- Must maintain existing Google Sheets integration for data storage.
- Must result in a successful Vercel deployment of both Next.js and FastAPI without breaking existing features.

## Requirements

### Validated

- ✓ Frontend UI for dashboard, books, referrals, reviews, and admin consoles — existing
- ✓ Backend REST API (FastAPI) handling auth, referrals, and reviews — existing
- ✓ Data integration with Google Sheets for storing/processing data — existing
- ✓ JWT-based authentication using fastapi-users — existing

### Active

- [ ] Remove unused/temporary Python scripts, test scripts, and leftover data CSVs/images from the project root and directories.
- [ ] Fix all ESLint warnings and TypeScript type errors in the Next.js frontend.
- [ ] Refactor and optimize frontend state management, component structure, and API integrations.
- [ ] Refactor FastAPI endpoints and Google Sheets data access logic in the backend for better performance and maintainability.
- [ ] Configure the project for Fullstack Vercel Deployment (e.g., configuring `vercel.json` and API rewrites to support Next.js and FastAPI serverless functions in one deployment).

### Out of Scope

- Migrating away from Google Sheets to a traditional SQL database — Not planned for this cleanup phase.
- Adding entirely new major features — Focus is on refactoring and deployment readiness.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fullstack Vercel Deployment | User selected a unified deployment on Vercel for both Next.js and Python. | — Pending |
| Comprehensive Refactoring | Code needs structure improvements (both frontend and backend) alongside fixing build errors. | — Pending |
| Removal of Clutter | Many unused root scripts and test files exist which complicate the build and deployment process. | — Pending |

---
*Last updated: 2026-03-16 after initialization*
