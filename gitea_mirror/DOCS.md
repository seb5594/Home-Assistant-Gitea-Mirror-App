# Gitea Mirror

Mirrors repositories from GitHub, GitLab or another Gitea to your own Gitea and keeps them up to date.
The app runs [Gitea Mirror](https://github.com/RayLabsHQ/gitea-mirror) and shows its web interface
inside Home Assistant (**Open Web UI**, or the *Gitea Mirror* entry in the sidebar).

**This is a pre-release (Alpha).** It is tested against a real Gitea, but not yet on many
installations. Expect rough edges and please report what you see.

## Contents

* [How it works](#how-it-works)
* [Quick start](#quick-start)
* [Options and the app's own settings](#options-and-the-apps-own-settings)
* [Connecting to Gitea](#connecting-to-gitea)
* [Signing in](#signing-in)
* [Data and backups](#data-and-backups)
* [Resources](#resources)
* [Security](#security)
* [Updates](#updates)
* [Options in detail](#options-in-detail)
* [Variables that are not offered](#variables-that-are-not-offered)
* [Troubleshooting](#troubleshooting)

## How it works

The web interface of Gitea Mirror is the page of this app. Home Assistant forwards it through
*ingress*, so no port has to be opened and the page is protected by your Home Assistant login. By
default the app is visible to administrators only.

The app takes the official release of Gitea Mirror unchanged and adds what Home Assistant needs:
the options of this page (every environment variable of Gitea Mirror has one), the connection to the
Gitea app, the sign-in with your Home Assistant account and the paths for ingress.

## Quick start

With the Gitea app from [alexbelgium/hassio-addons](https://github.com/alexbelgium/hassio-addons/tree/master/gitea):

1. Install and start the Gitea app and sign in once.
2. In Gitea open **Settings → Applications** and generate a token with read and write access to
   **repository** and **organization** and read access to **user**.
3. At the source (for GitHub: **Settings → Developer settings → Personal access tokens**) create a
   token with the scopes `repo` and `admin:org`.
4. Install this app. Under **Configuration** fill in **Source → Username**, **Source → Access token**
   and **Destination → Access token**, then start it.
5. Open **Open Web UI**. You are signed in with your Home Assistant account. Open **Repositories**,
   import and mirror.

The address of the Gitea app, `http://db21ed7f-gitea:3000`, is already filled in. The log tells
whether Gitea answers and whether the token is accepted, and fills in the Gitea user name and the
address your browser uses for links when you leave those empty. For another Gitea change
**Destination → Destination address**.

## Options and the app's own settings

Gitea Mirror keeps its configuration in its database and lets you change everything in the web
interface. The options of this page do the same from outside, which suits a setup that is described
in one place:

* An option that is **filled in** is applied at every start of the app. A change made in the web
  interface for the same setting is overwritten the next time the app starts.
* An option that is **left empty** sets nothing. The web interface is then the place for that setting.
  Switches that were never touched count as empty.

The options reach the configuration of the first account. The account is created when you open the
page for the first time, so the app applies the options then and restarts once to read them.
Settings about hosts are protected: once repositories were imported or mirrored, a different source
or destination address from the options is ignored with a warning in the log (change it in the web
interface, which asks for confirmation).

## Connecting to Gitea

The destination is a Gitea (or Forgejo) that pulls the mirrors itself. Gitea needs to reach the
source on the internet, and this app needs to reach Gitea. Other destinations (GitHub, GitLab) are
supported by Gitea Mirror as a beta; choose them under **Destination → Destination host**.

At every start the app asks Gitea for its version and, with an access token, who the token belongs
to. Problems are written to the log in plain words: unknown host name, connection refused,
certificate not trusted, token rejected.

## Signing in

With **Authentication → Sign in with Home Assistant** (on by default), Home Assistant tells the app
who opens the page, and that person is signed in and gets an account of their own. Every account
has its own configuration, so a second administrator starts with an empty one. Switch the option off
to use e-mail and password instead; the first account created becomes the administrator, as in the
original.

Single sign-on with an external provider (OIDC) is set up in the web interface under *Settings*.
Enter the address people use to reach Home Assistant in **Authentication → Public address**
so that the provider can send them back.

## Data and backups

Everything lives in the `/data` folder of the app: the database, the secrets and the working copies.
Home Assistant backups contain it, except for the working copies of push targets (`mirrors`), which
can be recreated.

Two secrets are created at the first start and kept in `/data` (`.better_auth_secret` and
`.encryption_secret`). The encryption secret protects the tokens stored in the database. A backup
restored onto a new installation brings them along; if you restore only the database, set the same
secret in **Authentication → Encryption secret**.

The repositories themselves are mirrored into your Gitea, so Gitea (and its own backup) holds them,
not this app.

## Resources

The app is one process of the Bun runtime. At rest it uses about as much memory as a small web
service; it grows while a batch of repositories is processed. On a small device lower
**Automation → Batch size** and **Content → Issues in parallel**. The app is built for `amd64` and
`aarch64`.

## Security

* Only Home Assistant's ingress proxy and the app itself can talk to the application; the
  application trusts the user headers that ingress adds.
* The application runs as an unprivileged user.
* Tokens are stored encrypted in the database. The options page keeps what you type there in the
  Home Assistant configuration, like every app.

## Updates

The release of Gitea Mirror is pinned in the `Dockerfile`. A scheduled workflow follows the releases
of the original project: a new release becomes a new version of this app by itself, after the
tests ran against it. The tests fail when a release renames or drops a variable the options use.

## Options in detail

The table lists every option with the environment variable of Gitea Mirror it sets.

### Source

| Option | Environment variable | What it does |
| --- | --- | --- |
| `source.provider` | `SOURCE_PROVIDER` | The service the repositories come from. GitHub is the supported path; GitLab and Gitea/Forgejo (including Codeberg) are beta. It cannot be changed once repositories were imported. |
| `source.url` | `SOURCE_URL` | Address of the GitLab or Gitea/Forgejo instance, for example https://gitlab.example.com. Ignored for GitHub. Defaults to https://gitlab.com or https://codeberg.org. |
| `source.username` | `GITHUB_USERNAME` | Your account name at the source host. |
| `source.token` | `GITHUB_TOKEN` | Personal access token of the source account. GitHub needs the scopes repo and admin:org, GitLab read_api and read_repository, Gitea/Forgejo read:repository, read:user and read:organization. |
| `source.account_type` | `GITHUB_TYPE` | Whether the source account is a personal account or an organization. |
| `source.github_api_url` | `GH_API_URL` | Only for GitHub Enterprise: https://ghe.example.com/api/v3 (Server) or https://api.TENANT.ghe.com (Cloud with data residency). Leave empty for github.com. |
| `source.include_private` | `PRIVATE_REPOSITORIES` | Include private repositories. |
| `source.include_public` | `PUBLIC_REPOSITORIES` | Include public repositories. |
| `source.include_archived` | `INCLUDE_ARCHIVED` | Include archived repositories. |
| `source.include_collaborator_repos` | `INCLUDE_COLLABORATOR_REPOS` | Include repositories that belong to others and where you are a collaborator. Switch off to import only your own. |
| `source.skip_forks` | `SKIP_FORKS` | Leave forked repositories out. |
| `source.mirror_starred` | `MIRROR_STARRED` | Also import the repositories you starred. |
| `source.starred_lists` | `MIRROR_STARRED_LISTS` | Only with starred repositories: names of GitHub star lists to mirror, separated by commas. Empty means every starred repository. |
| `source.starred_org` | `STARRED_REPOS_ORG` | Gitea organization that receives the starred repositories. The app default is starred. |
| `source.starred_mode` | `STARRED_REPOS_MODE` | dedicated-org puts them all into one organization, preserve-owner keeps the original owner as organization. |
| `source.starred_duplicate_strategy` | `STARRED_DUPLICATE_STRATEGY` | What happens when two starred repositories share a name: suffix gives repo-owner, prefix gives owner-repo, owner-org uses the owner as organization. |
| `source.skip_starred_issues` | `SKIP_STARRED_ISSUES` | Skip issues of starred repositories to save time and requests. |
| `source.auto_mirror_starred` | `AUTO_MIRROR_STARRED` | Mirror starred repositories during scheduled runs and Mirror All. Off means they are imported for browsing and mirrored one by one. |
| `source.mirror_organizations` | `MIRROR_ORGANIZATIONS` | Also mirror the repositories of your organizations. |
| `source.only_mirror_orgs` | `ONLY_MIRROR_ORGS` | Skip your personal repositories and mirror organization repositories only. |
| `source.include_organizations` | `INCLUDE_ORGANIZATIONS` | Only mirror these organizations, separated by commas. Empty means all organizations you belong to. |
| `source.excluded_organizations` | `GITHUB_EXCLUDED_ORGS` | Organizations to leave out, separated by commas. |
| `source.preserve_org_structure` | `PRESERVE_ORG_STRUCTURE` | Create the same organizations in Gitea. Superseded by the layout below when that is set. |
| `source.mirror_strategy` | `MIRROR_STRATEGY` | preserve keeps the source organizations, single-org puts everything into one organization, flat-user puts everything under the Gitea user, mixed keeps personal repositories in one organization and organization repositories in theirs. |

### Destination

| Option | Environment variable | What it does |
| --- | --- | --- |
| `destination.provider` | `DESTINATION_PROVIDER` | Where mirrors are created. Gitea and Forgejo pull the code themselves; GitHub and GitLab receive pushes from this app and are beta. |
| `destination.url` | `GITEA_URL` | Address of your Gitea. The default is the Gitea app by alexbelgium. For another app use http://<host name>:3000, for a Gitea elsewhere for example https://git.example.com. An address set here is applied at every start; clear it to manage the address in the app. |
| `destination.external_url` | `GITEA_EXTERNAL_URL` | Address your browser uses to reach Gitea, for dashboard links. Empty takes the address Gitea itself announces (its ROOT_URL). |
| `destination.username` | `GITEA_USERNAME` | Gitea account that owns the mirrors. Empty looks it up from the access token. |
| `destination.token` | `GITEA_TOKEN` | Access token of that account (Gitea > Settings > Applications). It needs write access to repositories and organizations. |
| `destination.organization` | `GITEA_ORGANIZATION` | Organization that receives the mirrors with the single-org layout. The app default is github-mirrors. |
| `destination.org_visibility` | `GITEA_ORG_VISIBILITY` | Visibility of organizations the app creates in Gitea. |
| `destination.mirror_interval` | `GITEA_MIRROR_INTERVAL` | How often Gitea pulls the mirrors, for example 30m, 8h or 1d. Setting it also switches scheduled mirroring on. |
| `destination.lfs` | `GITEA_LFS` | Mirror Git LFS files. Gitea needs LFS enabled. |
| `destination.create_org` | `GITEA_CREATE_ORG` | Create missing organizations in Gitea automatically. |
| `destination.preserve_visibility` | `GITEA_PRESERVE_VISIBILITY` | Private source repositories become private mirrors, public ones stay public. |
| `destination.template_owner` | `GITEA_TEMPLATE_OWNER` | Owner of a Gitea template repository used for new mirrors. |
| `destination.template_repo` | `GITEA_TEMPLATE_REPO` | Name of the Gitea template repository. |
| `destination.add_topics` | `GITEA_ADD_TOPICS` | Copy the topics of the source repository. |
| `destination.topic_prefix` | `GITEA_TOPIC_PREFIX` | Text put in front of every copied topic, for example gh-. |
| `destination.fork_strategy` | `GITEA_FORK_STRATEGY` | skip leaves forks out, reference mirrors them without their parent's history, full-copy mirrors everything. |
| `destination.ignore_certificate_errors` | `GITEA_SKIP_TLS_VERIFY` | Accepts any certificate of the destination. Only for a Gitea in your own network that cannot get a trusted certificate. |
| `destination.push_concurrency` | `PUSH_CONCURRENCY` | Only for GitHub and GitLab destinations: how many git fetch or push operations run at once. The app default is 2. |

### What to mirror

| Option | Environment variable | What it does |
| --- | --- | --- |
| `content.releases` | `MIRROR_RELEASES` | Mirror releases together with their assets. |
| `content.release_limit` | `RELEASE_LIMIT` | Newest releases to mirror per repository. The app default is 10. |
| `content.release_type` | `RELEASE_TYPE` | all mirrors everything, stable skips what the source marks as a pre-release. |
| `content.release_include_tags` | `RELEASE_INCLUDE_TAGS` | Only releases whose tag matches are mirrored. Comma separated globs such as v1.* or regular expressions in slashes such as /^v\d+\.\d+$/. |
| `content.release_exclude_tags` | `RELEASE_EXCLUDE_TAGS` | Releases whose tag matches are skipped; same notation as above. Excluding wins over including. |
| `content.release_asset_limit` | `RELEASE_ASSET_LIMIT` | Upload assets only for the newest N mirrored releases. 0 means release notes only. Empty means assets for every mirrored release. |
| `content.wiki` | `MIRROR_WIKI` | Mirror the wiki of each repository. |
| `content.metadata` | `MIRROR_METADATA` | Main switch for issues, pull requests, labels and milestones. |
| `content.issues` | `MIRROR_ISSUES` | Mirror issues with their comments. Needs metadata. |
| `content.pull_requests` | `MIRROR_PULL_REQUESTS` | Mirror pull requests as issues, Gitea cannot create them. Needs metadata. |
| `content.labels` | `MIRROR_LABELS` | Mirror labels. Needs metadata. |
| `content.milestones` | `MIRROR_MILESTONES` | Mirror milestones. Needs metadata. |
| `content.issue_concurrency` | `MIRROR_ISSUE_CONCURRENCY` | Issues processed at once. Above 1 is faster, but they may be created out of order. The app default is 3. |
| `content.pull_request_concurrency` | `MIRROR_PULL_REQUEST_CONCURRENCY` | Pull requests processed at once. Above 1 may change their order. The app default is 5. |

### Automation

| Option | Environment variable | What it does |
| --- | --- | --- |
| `schedule.enabled` | `SCHEDULE_ENABLED` | Import and mirror all repositories at start and keep syncing on the interval below. |
| `schedule.interval` | `SCHEDULE_INTERVAL` | Seconds (3600) or a cron expression such as 0 2 * * * for every day at 2 o'clock. The app default is 3600. |
| `schedule.concurrent` | `SCHEDULE_CONCURRENT` | Allow mirror operations to overlap. |
| `schedule.batch_size` | `SCHEDULE_BATCH_SIZE` | Repositories processed in parallel. The app default is 10. A smaller number is gentler on a small device. |
| `schedule.pause_between_batches` | `SCHEDULE_PAUSE_BETWEEN_BATCHES` | Milliseconds. The app default is 5000. |
| `schedule.retry_attempts` | `SCHEDULE_RETRY_ATTEMPTS` | How often a failed operation is tried again. The app default is 3. |
| `schedule.retry_delay` | `SCHEDULE_RETRY_DELAY` | Milliseconds between attempts. The app default is 60000. |
| `schedule.timeout` | `SCHEDULE_TIMEOUT` | Longest time for one mirror operation in milliseconds. The app default is 3600000. |
| `schedule.auto_retry` | `SCHEDULE_AUTO_RETRY` | Try failed operations again by themselves. |
| `schedule.auto_import` | `AUTO_IMPORT_REPOS` | Discover and import new repositories during scheduled runs. |
| `schedule.auto_mirror` | `AUTO_MIRROR_REPOS` | Mirror newly imported repositories during scheduled runs without pressing Mirror All. |
| `schedule.only_mirror_updated` | `SCHEDULE_ONLY_MIRROR_UPDATED` | Mirror only repositories that have updates. |
| `schedule.update_interval` | `SCHEDULE_UPDATE_INTERVAL` | How often to look for updates, in milliseconds. The app default is 86400000. |
| `schedule.skip_recently_mirrored` | `SCHEDULE_SKIP_RECENTLY_MIRRORED` | Skip repositories that were mirrored a short time ago. |
| `schedule.recent_threshold` | `SCHEDULE_RECENT_THRESHOLD` | Milliseconds a mirror counts as recent. The app default is 3600000. |
| `schedule.cleanup_before_mirror` | `SCHEDULE_CLEANUP_BEFORE_MIRROR` | Run the cleanup before each scheduled mirror run. |
| `schedule.notify_on_failure` | `SCHEDULE_NOTIFY_ON_FAILURE` | Send a notification when a run fails (set up the channels in the app). |
| `schedule.notify_on_success` | `SCHEDULE_NOTIFY_ON_SUCCESS` | Send a notification when a run succeeds. |
| `schedule.log_level` | `SCHEDULE_LOG_LEVEL` | How much the scheduler writes to the log. |
| `schedule.timezone` | `SCHEDULE_TIMEZONE` | Time zone for cron schedules, for example Europe/Berlin. The app default is UTC. |

### Cleanup

| Option | Environment variable | What it does |
| --- | --- | --- |
| `cleanup.enabled` | `CLEANUP_ENABLED` | Remove old events from the app's database. |
| `cleanup.retention_days` | `CLEANUP_RETENTION_DAYS` | Days to keep events. The app default is 7. |
| `cleanup.delete_from_destination` | `CLEANUP_DELETE_FROM_GITEA` | Apply the action for orphaned repositories in Gitea too. Off leaves the copies in Gitea untouched and only changes the app's own list. |
| `cleanup.delete_if_missing_at_source` | `CLEANUP_DELETE_IF_NOT_IN_GITHUB` | Treat repositories that no longer exist at the source as orphaned. This switches the cleanup on. |
| `cleanup.orphaned_repo_action` | `CLEANUP_ORPHANED_REPO_ACTION` | skip does nothing, archive keeps the data read-only (recommended for backups), delete removes it. |
| `cleanup.dry_run` | `CLEANUP_DRY_RUN` | Only log what the cleanup would do. The app default is on. |
| `cleanup.protected_repos` | `CLEANUP_PROTECTED_REPOS` | Repository names the cleanup never touches, separated by commas. |
| `cleanup.batch_size` | `CLEANUP_BATCH_SIZE` | Items handled per batch. The app default is 10. |
| `cleanup.pause_between_deletes` | `CLEANUP_PAUSE_BETWEEN_DELETES` | Milliseconds. The app default is 2000. |

### Backup before sync

| Option | Environment variable | What it does |
| --- | --- | --- |
| `backup.strategy` | `PRE_SYNC_BACKUP_STRATEGY` | disabled keeps no copies, always saves before every sync, on-force-push saves only when history was rewritten, block-on-force-push saves and then waits for your approval. The app default is on-force-push. Applies until the app has stored a setting of its own; after that the Backup settings page in the app wins. |
| `backup.keep_count` | `PRE_SYNC_BACKUP_KEEP_COUNT` | Newest copies kept per repository. The app default is 5. Applies until the app has stored a setting of its own. |
| `backup.retention_days` | `PRE_SYNC_BACKUP_RETENTION_DAYS` | Copies older than this are removed, the newest one always stays. 0 keeps them for ever. The app default is 30. Applies until the app has stored a setting of its own. |
| `backup.git_username` | `PRE_SYNC_BACKUP_GIT_USERNAME` | User name sent with the access token when a copy is fetched from Gitea. The app default is oauth2. |

### Sign-in

| Option | Environment variable | What it does |
| --- | --- | --- |
| `authentication.sign_in_with_home_assistant` | - | Home Assistant administrators are signed in automatically and get an account in the app. Switch it off to sign in with e-mail and password instead. On by default. |
| `authentication.default_method` | `AUTH_DEFAULT_METHOD` | Tab the login page opens on when both e-mail and single sign-on are available. |
| `authentication.allow_signup` | `AUTH_ALLOW_SIGNUP` | Keep e-mail sign-up open after the first account exists. The first account can always be created. |
| `authentication.public_url` | `BETTER_AUTH_URL` | Only for single sign-on with an external provider: the address people use to reach Home Assistant, for example https://ha.example.com. Scheme and host only. |
| `authentication.trusted_origins` | `BETTER_AUTH_TRUSTED_ORIGINS` | More addresses allowed to send sign-in requests, separated by commas, for example single sign-on providers. Scheme and host only. |
| `authentication.log_level` | `BETTER_AUTH_LOG_LEVEL` | Set debug to see the full sign-in and single sign-on trace when troubleshooting. The app default is warn. |
| `authentication.session_secret` | `BETTER_AUTH_SECRET` | Signs the sessions. Empty creates a random one at the first start and keeps it in the app's data. |
| `authentication.encryption_secret` | `ENCRYPTION_SECRET` | Encrypts the tokens stored in the database. Empty creates a random one at the first start. Keep it when you restore a backup elsewhere, without it the stored tokens cannot be read. |

### Advanced

| Option | Environment variable | What it does |
| --- | --- | --- |
| `advanced.repair_progress_interval` | `GITEA_REPAIR_PROGRESS_INTERVAL` | The repair at every start logs a line after this many repositories. The app default is 100. |
| `advanced.repair_request_timeout_ms` | `GITEA_REPAIR_REQUEST_TIMEOUT_MS` | Milliseconds the repair waits for one Gitea answer. Raise it when Gitea is slow. The app default is 15000. |
| `advanced.mcp_internal_url` | `MCP_INTERNAL_URL` | Address the app's MCP tools use to call the app itself. The default works inside this app. |

## Variables that are not offered

These variables of Gitea Mirror are not options, for the reason given:

| Variable | Reason |
| --- | --- |
| `NODE_ENV`, `HOST`, `PORT`, `BASE_URL`, `DATABASE_URL`, `DATABASE_PATH`, `MIRROR_CLONE_DIR`, `PRE_SYNC_BACKUP_DIR` | Fixed by the app: ingress, the data folder and the paths inside it |
| `SERVER_CERT_PATH`, `SERVER_KEY_PATH` | The page is served through Home Assistant, which takes care of HTTPS |
| `HEADER_AUTH_ENABLED` and the other `HEADER_AUTH_*` variables | Set by **Authentication → Sign in with Home Assistant** |
| `PUBLIC_BETTER_AUTH_URL` | Taken from **Authentication → Public address** |
| `DELAY` | Older name of `SCHEDULE_INTERVAL` |
| `GITHUB_API_URL` | Older name of `GH_API_URL` |
| `JWT_SECRET` | Older name of the session secret; a file from it is migrated by the original image only |
| `PRE_SYNC_BACKUP_ENABLED` | Replaced by the backup strategy |
| `NON_MIRROR_STRATEGY`, `ORG_CREATION_RETRIES`, `ORG_CREATION_RETRY_DELAY`, `SEQUENTIAL_ORG_CREATION`, `REPO_BATCH_SIZE`, `SYNC_TIMEOUT` | Documented in the source, but not read by release 3.46 |
| `DEPLOYMENT_MODE`, `DOCKER_REGISTRY`, `DOCKER_IMAGE`, `DOCKER_TAG` | Hosted service and compose files only |

## Troubleshooting

**The app does not show Gitea as configured.** Open the log. The first lines say whether Gitea
answers, whether the token is accepted and which values were filled in from it.

**"Gitea does not answer: the host name is unknown".** The Gitea app is not installed or not started,
or it has another host name. In Home Assistant the host name of an app is shown in its *Info* tab;
enter `http://<host name>:3000` in **Destination → Destination address**.

**"The certificate is not trusted".** Gitea uses a certificate Home Assistant does not know. Use
its plain address in your network, or switch on **Destination → Ignore certificate errors**.

**The page is blank or sign-in fails.** Open the page again from Home Assistant (not through a saved
link to another address) and look at the log. With a reverse proxy in front of Home Assistant, the
proxy has to pass the `Host` header and websockets, as Home Assistant needs anyway.

**My option has no effect.** Options reach the configuration of the first account, once it
exists. Check the log for *Applying the options to the configuration*, and see
[Options and the app's own settings](#options-and-the-apps-own-settings).

**The source cannot be changed.** Once repositories were imported the source is locked. Change it
in the web interface, which asks for confirmation.

## Questions

Open an issue in the [catalog repository](https://github.com/seb5594/Home-Assistant-Apps/issues).
Problems of Gitea Mirror itself belong to the
[original project](https://github.com/RayLabsHQ/gitea-mirror/issues).
