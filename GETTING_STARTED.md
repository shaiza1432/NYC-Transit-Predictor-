# Getting Started

A short guide for anyone receiving this project as a zip. Follow these
steps and you will have the dashboard running locally in about 10 minutes.

---

## 1. Prerequisites

You only need **one** thing installed on your machine:

**[Docker Desktop](https://www.docker.com/products/docker-desktop/)** — free,
available for Windows, macOS, and Linux.

Nothing else. Python, Java, Spark, and every other dependency are baked
into the Docker image — you do not need to install them on your host.

After installing Docker Desktop, start it. On Windows you will see a
small whale icon in the system tray; wait until it says "Docker is
running" before continuing.

---

## 2. Setup

### Step 1 — Extract the zip

Unzip the archive to a location of your choice. Suggested paths:

| OS | Suggested path |
|---|---|
| Windows | `C:\projects\nyc-transit-predictor\` |
| macOS / Linux | `~/Projects/nyc-transit-predictor/` |

### Step 2 — Open a terminal in that folder

| OS | Command |
|---|---|
| Windows | Open PowerShell, then `cd C:\projects\nyc-transit-predictor` |
| macOS / Linux | Open Terminal, then `cd ~/Projects/nyc-transit-predictor` |

### Step 3 — Build the Docker image (first time only)

```bash
docker compose build
```

This downloads Python 3.11, Java 17, and roughly 30 pip packages
(PySpark, Streamlit, Plotly, etc.). Expect **5 to 10 minutes** the
first time. Subsequent builds reuse cached layers and are nearly
instant.

### Step 4 — Train the model (optional)

A **pre-trained model is already included** in `models/rf_pipeline/`.
You can skip this step and go straight to step 5.

If you want to retrain from scratch (for example, after editing
hyper-parameters in `.env`), run:

```bash
docker compose run --rm pipeline
```

Takes about 4 to 5 minutes on a modern laptop. Exits with code 0 on
success. Produces `models/rf_pipeline/`, `models/metrics.json`, and
five diagnostic plots in `dashboard/static/plots/`.

### Step 5 — Start the dashboard

```bash
docker compose up -d dashboard
```

The `-d` flag runs the service in the background. The container takes
a few seconds to become healthy.

### Step 6 — Open the dashboard

Go to <http://localhost:8501> in your browser.

You should land on the Overview page with live KPIs from the trained
model.

---

## 3. Using the dashboard

The dashboard has eight pages, grouped into four sections in the
sidebar:

| Section | Page | What it does |
|---|---|---|
| Operate | Overview | Workspace landing, live model status, recent events |
| Operate | Predict | Enter a stop and time, get an instant travel-time prediction; save and compare scenarios |
| Operate | Map | Pan and zoom every MTA subway stop, Pydeck WebGL |
| Analyze | Performance | Train/test metrics, baseline comparison, five diagnostic plots |
| Maintain | System health | Environment + data + model status check |
| Maintain | Pipeline runs | History of training runs with metrics |
| Maintain | Settings | Theme picker, runtime defaults, project paths |
| Docs | Methodology | Model card describing what the model does and its limitations |

The sidebar also has a Dark / Light theme toggle at the bottom.

---

## 4. Common commands

```bash
# Stop everything
docker compose down

# Start the dashboard
docker compose up -d dashboard

# Tail dashboard logs in real time
docker compose logs -f dashboard

# Re-run the training pipeline
docker compose run --rm pipeline

# Open an interactive shell inside the container
docker compose run --rm --entrypoint bash dashboard

# Run the test suite (38 tests, takes about 30 seconds)
docker compose run --rm --entrypoint sh pipeline -c \
  "pip install -q -r requirements-dev.txt && pytest -m 'not slow'"

# Force a full rebuild after code changes
docker compose up -d --build dashboard

# Nuclear reset: remove image and any volumes
docker compose down -v --rmi local
```

---

## 5. Troubleshooting

### `Cannot connect to the Docker daemon`

Docker Desktop is not running. Start it from the Start menu (Windows),
Applications folder (macOS), or `systemctl start docker` (Linux).

### `port is already allocated` / `address already in use`

Something else is using port 8501. Either stop that process or change
the port in `.env`:

```
STREAMLIT_PORT=8502
```

Then restart with `docker compose up -d dashboard`.

### Pipeline runs out of memory (exit code 137)

Increase Docker's memory allocation:

| OS | How |
|---|---|
| Windows / macOS | Docker Desktop → Settings → Resources → Memory ≥ 6 GB → Apply & Restart |
| Linux | Docker honors host RAM directly. Free up RAM or close other apps. |

### Dashboard says "Model not yet trained"

The `models/rf_pipeline/` folder is empty or missing. Run:

```bash
docker compose run --rm pipeline
```

### First Predict page load is slow

The first prediction takes 5 to 15 seconds because the Spark session
and the trained model both have to be loaded into the container's
memory. Subsequent predictions return in under a second thanks to
Streamlit's resource caching.

### "Image build is taking forever"

The first build downloads about 500 MB of dependencies. Subsequent
builds reuse cached layers. If the build feels stuck for more than
20 minutes, check your internet connection and Docker Desktop's
status.

---

## 6. Project layout

```
nyc-transit-predictor/
|
+-- dashboard/             Streamlit app + ML pipeline source
|   +-- app.py              Streamlit entrypoint (theme + navigation)
|   +-- pipeline.py         CLI training pipeline
|   +-- views/              Eight dashboard pages
|   +-- src/                Core library (config, model, predict, styling, ...)
|   +-- static/plots/       Diagnostic PNGs written by the pipeline
|   +-- static/nyc-logo.png Brand logo shown in the sidebar
|
+-- data/raw/              GTFS feed from MTA NYC Transit (~45 MB)
+-- models/                Trained Random Forest + metrics.json
+-- notebooks/             EDA notebook (01_eda.ipynb)
+-- tests/                 pytest suite (38 tests)
+-- docs/                  Architecture doc
|
+-- Dockerfile             Python 3.11 + Java 17 + Spark base image
+-- docker-compose.yml     Three services (pipeline, dashboard, notebook)
+-- requirements.txt       Pinned Python dependencies
+-- requirements-dev.txt   Test / lint / type-check tools
+-- .env.example           Copy to .env to override defaults
+-- README.md              Full reference (architecture, methodology, etc.)
+-- GETTING_STARTED.md     This file
+-- CONTRIBUTING.md        Branching, code conventions, PR checklist
+-- CHANGELOG.md           Release notes
+-- LICENSE                MIT (code) + MTA terms (data)
```

---

## 7. Going further

- **Edit code with hot reload.** Streamlit watches the filesystem and
  re-runs on every save. Any change under `dashboard/` is picked up
  immediately by the running container, no rebuild needed.

- **Tune the model.** Edit `.env` (copy from `.env.example`) and adjust
  `RF_NUM_TREES`, `RF_MAX_DEPTH`, `RF_MAX_BINS`, `TEST_SIZE`. Then
  re-run the pipeline.

- **Run the Jupyter notebook.** Start the dev profile:
  ```bash
  docker compose --profile dev up -d notebook
  ```
  Open <http://localhost:8888>.

- **Read the deeper docs.** `README.md` has the full architecture
  walkthrough; `docs/ARCHITECTURE.md` has the data-flow diagram and
  module dependency graph.

---

## One-line summary

> Install Docker Desktop, extract the zip, run `docker compose up -d dashboard`,
> open <http://localhost:8501>. Done.
