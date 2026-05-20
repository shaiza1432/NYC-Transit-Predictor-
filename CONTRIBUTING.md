# Contributing

Thanks for your interest in improving NYC Transit Predictor! This guide
covers the practical workflow — environment, conventions, and the
pre-merge checklist.

## Development setup

Two options. **Option A** is fully containerised and matches CI:

```bash
docker compose build
docker compose --profile dev up -d notebook   # http://localhost:8888
docker compose run --rm dashboard bash        # interactive shell
```

**Option B** uses a host virtual env (Java 17 + Python 3.11 must be on PATH):

```bash
python -m venv .venv
source .venv/bin/activate                     # PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt -r requirements-dev.txt
```

## Branching and commits

* Branch off `main` with a descriptive name: `fix/streamlit-cache-typing`,
  `feat/weather-enrichment`, `docs/spark-tuning-guide`.
* Keep commits small and topical. Squash WIP commits before opening a PR.
* Use the imperative mood in commit subject lines:
  `add hourly-average chart caching`, not `added` or `adds`.

## Code conventions

* **Formatting and linting:** `ruff format .` then `ruff check .`.
  CI enforces both — your PR will be blocked on style drift.
* **Type hints:** every public function must be typed. Run `mypy dashboard`
  before pushing.
* **Imports:** organised by ruff's isort rules. Don't import inside
  functions unless you're breaking a real circular dependency.
* **Logging:** use `from dashboard.src.logger import log`. Never `print`.
* **Comments:** explain *why*, not *what*. The code should be self-evident
  about the *what*.

## Tests

Add tests in `tests/`. Naming: `test_<module>.py`. Markers:

* `@pytest.mark.spark` — needs an active SparkSession (covered by the
  session-scoped fixture in `conftest.py`).
* `@pytest.mark.slow` — runtime > 5 s. Deselect with `pytest -m "not slow"`.
* `@pytest.mark.integration` — end-to-end pipeline tests.

Aim for 80%+ coverage on changed modules. Don't test third-party code.

## Pull-request checklist

Before opening a PR:

- [ ] `ruff format --check .`
- [ ] `ruff check .`
- [ ] `mypy dashboard`
- [ ] `pytest -m "not slow"`
- [ ] Updated docs (README / ARCHITECTURE) if behaviour changed
- [ ] Added entry in `CHANGELOG.md` under `## Unreleased`
- [ ] No secrets / credentials in the diff

## Reporting issues

Open a GitHub issue with:

* What you tried (commands + relevant config).
* What you expected to happen.
* What actually happened (full traceback, please).
* Your environment: OS, Docker version, host Python version (if natively).

## License

By contributing you agree your changes are released under the project's
MIT license.
