<!-- header:begin (generated from project metadata) -->
<h1 align="center">Gitea Mirror</h1>

<p align="center">
  <img src="https://raw.githubusercontent.com/seb5594/Home-Assistant-Gitea-Mirror-App/dev/gitea_mirror/logo.png" alt="Gitea Mirror" width="201" height="160">
</p>

---

<p align="center">
  <a href="https://paypal.me/seb5594"><img src="https://img.shields.io/static/v1?label=Support&amp;message=PayPal&amp;color=0070BA&amp;logo=paypal&amp;logoColor=white&amp;style=for-the-badge" alt="PayPal" height="40"></a>
  <a href="https://buymeacoffee.com/seb5594"><img src="https://img.shields.io/static/v1?label=Support&amp;message=Buy%20Me%20a%20Coffee&amp;color=FFDD00&amp;logo=buy-me-a-coffee&amp;logoColor=black&amp;style=for-the-badge" alt="Buy Me a Coffee" height="40"></a><br>
  <a href="https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fseb5594%2FHome-Assistant-Apps"><img src="https://img.shields.io/static/v1?label=Home%20Assistant&amp;message=Add%20app%20repository&amp;color=18BCF2&amp;logo=homeassistant&amp;logoColor=white&amp;style=for-the-badge" alt="Home Assistant" height="28"></a>
  <a href="https://github.com/seb5594/Home-Assistant-Gitea-Mirror-App/releases/tag/v1.0.0-alpha.1"><img src="https://img.shields.io/static/v1?label=version&amp;message=Alpha%201&amp;color=1877A5&amp;style=for-the-badge" alt="version" height="28"></a>
  <img src="https://img.shields.io/static/v1?label=image%20pulls&amp;message=4&amp;color=1877A5&amp;style=for-the-badge" alt="image pulls" height="28"><br>
  <img src="https://img.shields.io/static/v1?label=arch%20%26%20size&amp;message=amd64%20536.1%20%C2%B7%20aarch64%20534.9%20MiB&amp;color=157F71&amp;style=flat" alt="arch &amp; size" height="20">
  <img src="https://img.shields.io/static/v1?label=stage&amp;message=experimental&amp;color=2F855A&amp;style=flat" alt="stage" height="20">
  <img src="https://img.shields.io/static/v1?label=ingress&amp;message=enabled&amp;color=7C3AED&amp;style=flat" alt="ingress" height="20"><br>
  <a href="https://github.com/seb5594/Home-Assistant-Apps/issues"><img src="https://img.shields.io/github/issues/seb5594/Home-Assistant-Gitea-Mirror-App?label=issues&amp;style=flat" alt="issues" height="20"></a>
  <img src="https://img.shields.io/static/v1?label=runtime%20tests&amp;message=24%20passed&amp;color=2F855A&amp;style=flat" alt="runtime tests" height="20">
  <a href="https://github.com/seb5594/Home-Assistant-Gitea-Mirror-App/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/seb5594/Home-Assistant-Gitea-Mirror-App/ci.yml?branch=dev&amp;label=checks&amp;style=flat" alt="checks" height="20"></a>
  <a href="https://github.com/seb5594/Home-Assistant-Apps#license"><img src="https://img.shields.io/github/license/seb5594/Home-Assistant-Gitea-Mirror-App?label=license&amp;style=flat" alt="license" height="20"></a>
</p>
<!-- header:end -->

Brings [Gitea Mirror](https://github.com/RayLabsHQ/gitea-mirror) to Home Assistant. It mirrors
repositories from GitHub, GitLab or another Gitea to your own Gitea and keeps them up to date. The
original web interface is the page of the app, so there is nothing to open on your network.

> **Pre-release.** The versions are Alpha pre-releases: tested against a real Gitea, not yet on many
> installations. Please report what you see.

* **Inside Home Assistant.** The web interface opens through ingress and signs you in with your
  Home Assistant account.
* **Made for the Gitea app.** The address of the [Gitea app by alexbelgium](https://github.com/alexbelgium/hassio-addons/tree/master/gitea)
  is already filled in. At every start the log checks Gitea and your token, and takes the Gitea user
  name and the address of your browser from it.
* **Every variable is an option.** All environment variables of Gitea Mirror can be set on the
  configuration page, in English and German. What you leave empty stays in the hands of the web
  interface.
* **Pinned and followed.** The release of Gitea Mirror is pinned, never `latest`. A scheduled
  workflow follows the releases of the original project and turns each into a new version of this app.

## Install

In Home Assistant open **Settings → Apps → App store → ⋮ → Repositories**, add
`https://github.com/seb5594/Home-Assistant-Gitea-Mirror-App` and install **Gitea Mirror**.
Older versions call these *Add-ons* and *Add-on store*. Setup, options and troubleshooting are in the
[documentation](gitea_mirror/DOCS.md).

## How it fits together

```text
Home Assistant ──ingress──► ingress-server ──► Gitea Mirror (Bun, SQLite in /data)
 (your account)                 │                  │
                                │                  ├──► source: GitHub, GitLab, Gitea
                                └ user headers     └──► destination: your Gitea
```

The app takes the official release unchanged. The start script turns the options into the
environment of Gitea Mirror, checks Gitea, creates the secrets and starts it; a small server in
front removes the ingress path and lets only Home Assistant through.

## Development

```text
gitea_mirror/
  config.yaml, translations/    options and their labels
  rootfs/usr/lib/gitea-mirror/  shell libraries: options to environment, Gitea check
  rootfs/usr/share/gitea-mirror/
    env-map.json                which option sets which variable
    ingress-server.ts           the server in front of the application
  rootfs/etc/s6-overlay/        the service
.github/tests/runtime.sh        runs inside the built image
.github/workflows/upstream.yml  follows the releases of Gitea Mirror
```

The runtime test starts the real application behind a fake ingress path, signs in with the headers
Home Assistant adds and gives it its configuration. It also checks that every variable in
`env-map.json` is still read by the release in the image, so an upstream rename fails the build and
not an installation. A new release of Gitea Mirror is picked up by `.github/scripts/upstream.py`:
it changes the pin in the `Dockerfile`, raises the app version and adds a changelog entry. Renovate
pull requests for the base image and the Alpine packages get their version bump the same way.

<!-- support:begin (generated, shared text) -->
## Say thanks

All my projects are built in my spare time, just for the fun of it. Still, they take a lot of time and care, and many of the smart home gadgets I buy end up here because I want to make them cloud-free and smart-home ready. Every bit of support means a lot to me.

If my work helped you or turned out to be useful, show your appreciation with a hot drink for my next sleepless night.

[![PayPal](https://img.shields.io/static/v1?label=Support&message=PayPal&color=0070BA&logo=paypal&logoColor=white&style=for-the-badge)](https://paypal.me/seb5594) [![Buy Me a Coffee](https://img.shields.io/static/v1?label=Support&message=Buy%20Me%20a%20Coffee&color=FFDD00&logo=buy-me-a-coffee&logoColor=black&style=for-the-badge)](https://buymeacoffee.com/seb5594)
<!-- support:end -->

<!-- license:begin (generated from the license file) -->
## License

[![license](https://img.shields.io/static/v1?label=license&message=MIT&color=5B6770&style=flat)](LICENSE)

Published under the [MIT License](LICENSE).
<!-- license:end -->
