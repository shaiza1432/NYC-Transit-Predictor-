# Changelog

All notable changes are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-05-19

Initial production-ready release.

### Added
- End-to-end Spark pipeline: load → preprocess → train → evaluate → persist.
- Random Forest regressor on five engineered features (`hour_of_day`,
  `is_peak`, `stop_sequence`, `stop_lat`, `stop_lon`).
- Single-pass metric aggregation (RMSE, MAE, R²) replacing three separate
  Spark jobs.
- Broadcast joins on small tables (stops, routes, trips) for ~30% speedup.
- Multi-page Streamlit dashboard: Home, Metrics, Predict, Map, About.
- Pydeck WebGL map for stops visualisation.
- Twelve-factor config via env vars and `python-dotenv`.
- Loguru logging with rotation (10 MB) and 14-day retention.
- Production exit codes (`0/1/2/3`) from the CLI pipeline.
- Input validation in `predict.py` with informative ranges.
- Docker / Docker-Compose setup (Python 3.11 + OpenJDK 17 + tini).
- Three compose services: `pipeline`, `dashboard`, optional dev `notebook`.
- pytest test suite: unit + integration + Spark fixture.
- Ruff lint + format, mypy type checking, `pip-audit` security scan.
- GitHub Actions CI with four parallel jobs (quality, integration, docker, audit).
- Make + PowerShell task runners for cross-platform DX.
- ARCHITECTURE.md, CONTRIBUTING.md, README, LICENSE.

### Notes
- Dataset is the MTA New York City Transit GTFS feed (~45 MB on disk).
- The historical "Dublin Bus" naming has been removed from all source.
