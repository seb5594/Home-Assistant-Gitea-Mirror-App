# Changelog

## 3.51.6

* Match the app version to the pinned upstream image version (3.51.6); the packaged upstream software is unchanged.
* Refresh the Git package pin to 2.54.1-r0 because Alpine no longer provides the previously pinned build.
* Keep daily automatic updates within the current upstream major version.
* Require Renovate Dependency Dashboard approval and manual PR merge for major Docker image updates.
* Keep historical Alpha release notes below; the Home Assistant wrapper remains experimental.

## 1.0.0-alpha.6

* 📦 Update raylabshq/gitea-mirror to 3.51.6 (was 3.51.5).

## 1.0.0-alpha.5

* 📦 Update raylabshq/gitea-mirror to 3.51.5 (was 3.51.3).

## 1.0.0-alpha.4

* 📦 Update raylabshq/gitea-mirror to 3.51.3 (was 3.51.2).

## 1.0.0-alpha.3

* 📦 Update raylabshq/gitea-mirror to 3.51.2 (was 3.51.0).

## 1.0.0-alpha.2

* Update the base image and packaged dependencies to available release versions; restore reproducible CI builds.

## 1.0.0-alpha.1

* First version: Gitea Mirror 3.46.0 in Home Assistant, with the web interface behind ingress.
* Every environment variable of Gitea Mirror is an option, in English and German.
* The Gitea app by alexbelgium is preset; the log checks Gitea and the token and fills in the Gitea
  user name and the browser address from them.
* Sign-in with the Home Assistant account.
