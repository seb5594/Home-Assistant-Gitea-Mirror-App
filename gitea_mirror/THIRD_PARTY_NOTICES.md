# Third-party notices

This app contains software of the following projects, used unmodified.

| Component | License | Source |
| --- | --- | --- |
| Gitea Mirror, the application with its web interface and dependencies, copied from the official `ghcr.io/raylabshq/gitea-mirror` image | AGPL-3.0, see `licenses/gitea-mirror-AGPL-3.0.txt` | <https://github.com/RayLabsHQ/gitea-mirror> |
| Bun runtime, copied from the official `oven/bun` image | MIT | <https://github.com/oven-sh/bun> |
| Home Assistant base image with bashio and s6-overlay | Apache-2.0, MIT | <https://github.com/home-assistant/docker-base> |
| Git, Git LFS, SQLite, curl, jq (installed through Alpine packages) | GPL-2.0, MIT, public domain, curl, MIT | <https://pkgs.alpinelinux.org> |

The notices of the Alpine packages are in the image under `/usr/share/licenses`.

Gitea Mirror is licensed under the GNU Affero General Public License. The version in this app is
the release named in the `Dockerfile` (`GITEA_MIRROR_VERSION`); its source code is available at the
address above under the tag of that release. This app only adds the start scripts in
`rootfs/`, the options and the Home Assistant integration around it.

The icon and logo are the Gitea Mirror logo from the repository above (`public/logo.png`). This app
is not an official product of the Gitea Mirror project.
