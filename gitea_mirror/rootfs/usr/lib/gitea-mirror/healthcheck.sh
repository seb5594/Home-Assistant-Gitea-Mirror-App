#!/usr/bin/env bash
# shellcheck shell=bash
# Docker health check: the application answers on its health endpoint.

curl -fsS --max-time 5 -o /dev/null "http://127.0.0.1:${PORT:-8099}/api/health"
