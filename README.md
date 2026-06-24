# Rental Manager

A rental house management web app. Manage properties, rooms, customers, leases, and payments.

## Tech stack
- **Frontend**: React 18 + Vite + TypeScript, react-i18next (EN/VI)
- **Backend**: FastAPI (Python 3.11), SQLAlchemy 2.0, Alembic, SQLite
- **Auth**: JWT (python-jose)
- **Deploy**: Docker Compose

## Local development

**Backend**
```bash
cd src/backend
cp .env.example .env   # edit SECRET_KEY
pip install -r requirements-dev.txt
alembic upgrade head
uvicorn app.main:app --reload
```

**Frontend**
```bash
cd src/frontend
npm install
npm run dev
```

Visit http://localhost:5173

## Production (Docker Compose)

```bash
cp .env.example .env   # set SECRET_KEY and DATABASE_URL
mkdir -p data
docker compose up --build -d
```

Visit http://localhost

## Tests

```bash
# Python unit + integration
pytest -c tests/_runner/pytest.ini

# React unit
npx vitest run --config tests/_runner/vitest.config.ts

# E2E (requires running app)
npx playwright test --config tests/_runner/playwright.config.ts
```

## Development workflow

Work moves idea → spec → build → review → test → ship, driven by slash commands. Full reference: [docs/guides/development-workflow.md](docs/guides/development-workflow.md).

| Phase | Command | What it does |
|---|---|---|
| Capture | `/capture-idea <slug>` | Frame a raw idea into a backlog item — or split a big one into an epic + per-wave slices |
| Spec | `/new-feature <slug>` | Scaffold spec, acceptance criteria, test plan, and test cases |
| Build | `/implement <slug>` | Generate code, unit tests, and e2e/integration automation |
| Review | `/review-code <slug>` | Read-only audit against spec, ACs, and test cases |
| Test | `/execute-tests <slug>` | Run the configured runner and write a verdict report |
| Ship | `/ship <slug>` | Mark shipped and archive the initiative (green report required) |
