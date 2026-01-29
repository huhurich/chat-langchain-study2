#!/bin/bash
poetry run uvicorn --app-dir=backend main:app --host 0.0.0.0 --port ${PORT:-8080}
