#!/usr/bin/env bash
# add-governance-chapter.sh
#
# Adds a new "Organization Governance" chapter to your existing
# ajeetraina/labspace-sbx-blastradius repo. The chapter follows the same
# surface-label convention (🖥 Host / 🌐 Admin Console / 📦 Sandbox shell)
# and code-fence directives (bash no-run-button, plaintext no-copy-button)
# as 01-blast-radius-test.md.
#
# Extras for this chapter:
#   - A "Set Docker Hub Org" form at the top of the page that persists the
#     org slug in localStorage (so re-runs of the labspace remember it).
#   - A top tab/link bar with three deep-links into the Admin Console:
#     Manage AI governance, Network access, Filesystem access. Links stay
#     disabled until the org slug is set.
#
# What the script does:
#   1. Clones labspace-sbx-blastradius (or uses --dir if already cloned)
#   2. Creates branch: feat/governance-chapter
#   3. Writes labspace/02-governance.md
#   4. Patches labspace/labspace.yaml to register the new section
#   5. Commits, and optionally pushes + opens a PR via gh CLI
#
# Re-runnable: if 02-governance.md already exists it's overwritten.
# labspace.yaml is only patched when the section isn't already registered.
#
# Usage:
#   ./add-governance-chapter.sh                              # full flow with push + PR
#   ./add-governance-chapter.sh --no-push                    # local commit only
#   ./add-governance-chapter.sh --no-pr                      # push but skip PR
#   ./add-governance-chapter.sh --dir ./blastradius          # use an existing local clone
#   ./add-governance-chapter.sh --branch feat/gov-v2         # custom branch name

set -euo pipefail

# ---- Defaults ----------------------------------------------------------------
OWNER="ajeetraina"
REPO="labspace-sbx-blastradius"
DIR=""
BRANCH="feat/governance-chapter"
DO_PUSH=1
DO_PR=1

# ---- Arg parsing -------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)    OWNER="$2"; shift 2 ;;
    --repo)     REPO="$2"; shift 2 ;;
    --dir)      DIR="$2"; shift 2 ;;
    --branch)   BRANCH="$2"; shift 2 ;;
    --no-push)  DO_PUSH=0; DO_PR=0; shift ;;
    --no-pr)    DO_PR=0; shift ;;
    -h|--help)  sed -n '2,36p' "$0"; exit 0 ;;
    *)          echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

DIR="${DIR:-$REPO}"
CHAPTER_FILE="labspace/02-governance.md"
YAML_FILE="labspace/labspace.yaml"
SECTION_TITLE="Organization Governance"

# ---- Output helpers ----------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { printf "${GREEN}==>${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}!! ${NC} %s\n" "$*"; }
fatal() { printf "${RED}xx ${NC} %s\n" "$*" >&2; exit 1; }

# ---- Preflight ---------------------------------------------------------------
command -v git >/dev/null 2>&1 || fatal "git is required."

# ---- Clone or reuse ----------------------------------------------------------
if [[ -d "$DIR/.git" ]]; then
  info "Using existing clone at $DIR"
  cd "$DIR"
elif [[ -e "$DIR" ]]; then
  fatal "Directory '$DIR' exists but isn't a git repo. Remove it or pass --dir."
else
  info "Cloning ${OWNER}/${REPO} into $DIR/"
  git clone "https://github.com/${OWNER}/${REPO}.git" "$DIR"
  cd "$DIR"
fi

# ---- Sanity-check the repo structure -----------------------------------------
[[ -f "labspace/01-blast-radius-test.md" ]] || fatal "labspace/01-blast-radius-test.md not found — is this the right repo?"
[[ -f "$YAML_FILE" ]] || fatal "$YAML_FILE not found — is this the right repo?"

# Refuse to clobber uncommitted work
if ! git diff --quiet || ! git diff --cached --quiet; then
  fatal "Working tree has uncommitted changes. Stash or commit them first."
fi

info "Fetching latest"
git fetch origin --quiet

DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -1)
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
git checkout -q "$DEFAULT_BRANCH"
git pull -q --ff-only origin "$DEFAULT_BRANCH" 2>/dev/null || warn "Could not fast-forward $DEFAULT_BRANCH (continuing)"

# Create or switch to the feature branch
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  info "Branch $BRANCH already exists — switching to it"
  git checkout -q "$BRANCH"
else
  info "Creating branch $BRANCH"
  git checkout -q -b "$BRANCH"
fi

# ---- Write the chapter file --------------------------------------------------
info "Writing $CHAPTER_FILE"
cat > "$CHAPTER_FILE" <<'CHAPTER_EOF'
<!--
  AI Governance Setup Bar
  =======================
  A small HTML widget at the top of the chapter that does two things:
  1. Asks the reader to set their Docker Hub Org slug (persisted to localStorage).
  2. Provides quick-jump links into the Admin Console's AI governance subpages
     for that org. Links stay disabled until the org slug is set.
  All vanilla HTML / CSS / JS, no frameworks.
-->
<style>
  .gov-bar {
    border: 1px solid #d0d7de;
    border-radius: 8px;
    padding: 14px 18px;
    margin: 0 0 24px 0;
    background: #f6f8fa;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    font-size: 14px;
  }
  .gov-bar__row {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px;
  }
  .gov-bar__row + .gov-bar__row { margin-top: 10px; }
  .gov-bar__label {
    font-weight: 600;
    color: #1f2328;
    margin-right: 4px;
  }
  .gov-bar input[type="text"] {
    padding: 5px 10px;
    border: 1px solid #d0d7de;
    border-radius: 6px;
    font-size: 14px;
    min-width: 220px;
    font-family: inherit;
  }
  .gov-bar button {
    padding: 5px 14px;
    border: 1px solid #1f6feb;
    background: #1f6feb;
    color: #fff;
    border-radius: 6px;
    font-size: 14px;
    cursor: pointer;
    font-family: inherit;
  }
  .gov-bar button:hover { background: #1a5fd1; }
  .gov-bar button.gov-bar__change {
    background: transparent;
    color: #1f6feb;
    border-color: transparent;
    padding: 0 4px;
    text-decoration: underline;
    font-size: 13px;
  }
  .gov-bar__links {
    display: flex;
    flex-wrap: wrap;
    gap: 14px;
  }
  .gov-bar__links a {
    text-decoration: none;
    padding: 4px 10px;
    border-radius: 6px;
    background: #ffffff;
    border: 1px solid #d0d7de;
    color: #1f6feb;
    font-weight: 500;
  }
  .gov-bar__links a:hover { background: #eaf2ff; }
  .gov-bar__links a.disabled {
    color: #8c959f;
    background: #f0f1f2;
    border-color: #e6e8eb;
    pointer-events: none;
    cursor: not-allowed;
  }
  .gov-bar__status {
    color: #57606a;
    font-size: 13px;
  }
  .gov-bar__status.error { color: #cf222e; }
  .gov-bar__status.ok    { color: #1a7f37; }
</style>

<div class="gov-bar" id="gov-bar">
  <div class="gov-bar__row" id="gov-bar-input-row">
    <span class="gov-bar__label">🏢 Docker Hub Org:</span>
    <input type="text" id="gov-bar-input" placeholder="e.g. dockerdevrel" autocomplete="off" spellcheck="false" />
    <button id="gov-bar-set">Set org</button>
    <span class="gov-bar__status" id="gov-bar-status">Set your org before enabling AI governance.</span>
  </div>
  <div class="gov-bar__row" id="gov-bar-summary-row" style="display:none;">
    <span class="gov-bar__label">🏢 Org:</span>
    <strong id="gov-bar-current"></strong>
    <button class="gov-bar__change" id="gov-bar-change">change</button>
  </div>
  <div class="gov-bar__row gov-bar__links">
    <a id="gov-link-manage"     href="#" class="disabled" target="_blank" rel="noopener">⚙️  Manage AI governance</a>
    <a id="gov-link-network"    href="#" class="disabled" target="_blank" rel="noopener">🛜 Network access</a>
    <a id="gov-link-filesystem" href="#" class="disabled" target="_blank" rel="noopener">📂 Filesystem access</a>
  </div>
</div>

<script>
(function () {
  var STORAGE_KEY = 'labspace.sbx.governance.org';
  var SLUG_RE = /^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/;  // Docker Hub org rules

  var input       = document.getElementById('gov-bar-input');
  var setBtn      = document.getElementById('gov-bar-set');
  var changeBtn   = document.getElementById('gov-bar-change');
  var status      = document.getElementById('gov-bar-status');
  var inputRow    = document.getElementById('gov-bar-input-row');
  var summaryRow  = document.getElementById('gov-bar-summary-row');
  var current     = document.getElementById('gov-bar-current');
  var linkManage  = document.getElementById('gov-link-manage');
  var linkNet     = document.getElementById('gov-link-network');
  var linkFs      = document.getElementById('gov-link-filesystem');

  function urlFor(org, sub) {
    return 'https://app.docker.com/admin/' + encodeURIComponent(org) + '/ai-governance/' + sub;
  }

  function activate(org) {
    inputRow.style.display = 'none';
    summaryRow.style.display = 'flex';
    current.textContent = org;
    linkManage.href = urlFor(org, 'manage');
    linkNet.href    = urlFor(org, 'network-access');
    linkFs.href     = urlFor(org, 'filesystem-access');
    [linkManage, linkNet, linkFs].forEach(function (a) { a.classList.remove('disabled'); });
  }

  function deactivate() {
    inputRow.style.display = 'flex';
    summaryRow.style.display = 'none';
    status.className = 'gov-bar__status';
    status.textContent = 'Set your org before enabling AI governance.';
    [linkManage, linkNet, linkFs].forEach(function (a) {
      a.classList.add('disabled');
      a.href = '#';
    });
  }

  function commit() {
    var org = (input.value || '').trim().toLowerCase();
    if (!org) {
      status.className = 'gov-bar__status error';
      status.textContent = 'Please type your Docker Hub org slug.';
      return;
    }
    if (!SLUG_RE.test(org)) {
      status.className = 'gov-bar__status error';
      status.textContent = 'That doesn\u2019t look like a valid Docker Hub org slug (3\u201340 chars, lowercase letters, digits, hyphens; can\u2019t start or end with hyphen).';
      return;
    }
    try { localStorage.setItem(STORAGE_KEY, org); } catch (e) { /* private mode */ }
    activate(org);
  }

  setBtn.addEventListener('click', commit);
  input.addEventListener('keydown', function (e) { if (e.key === 'Enter') commit(); });
  changeBtn.addEventListener('click', function () {
    try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
    input.value = '';
    deactivate();
    input.focus();
  });

  // Restore on load if previously set
  var saved = null;
  try { saved = localStorage.getItem(STORAGE_KEY); } catch (e) {}
  if (saved && SLUG_RE.test(saved)) {
    input.value = saved;
    activate(saved);
  }
})();
</script>

# Organization Governance

In Chapter 1 you shrank the blast radius for *one* developer's laptop.
Local `sbx policy` rules said what your sandbox could touch, and that
worked because you were the one writing them.

Now scale that up. Imagine 200 developers, all running agents, all on
slightly different policies. Some allowed an extra domain "just for
this sprint." Some never restricted filesystem mounts. One of them
gets prompt-injected on a Tuesday afternoon.

That's the governance problem. It's not solved by better local
policies — it's solved by *uniform* policies, set centrally, that
individual developers can extend but can't weaken.

This chapter shows how Docker's **AI governance** controls in the
Admin Console do that. You'll enable org-level policy, watch a local
rule go **inactive** because corporate policy doesn't delegate it,
then turn on delegation and watch the same rule come back **active** —
while the org-level deny still blocks the things it's meant to block.

> **Set your Docker Hub Org first**
>
> Use the input at the top of this chapter to enter your Docker Hub
> org slug (e.g. `dockerdevrel`). The three quick-jump links above
> will deep-link straight into your org's Admin Console pages for
> Manage, Network access, and Filesystem access. The slug is saved
> in your browser so you only set it once.

> **Note**
>
> Sandbox organization governance is on a separate paid subscription.
> If your org doesn't have it enabled, [contact Docker
> Sales](https://www.docker.com/products/ai-governance/#contact-sales).
> The CLI portions of this chapter still run without it; you just
> won't see `remote` rules in `sbx policy ls`.

---

## Three surfaces — same labels as Chapter 1, plus one new one

| Label | Surface | Looks like |
|---|---|---|
| **🖥 Host** | Your Mac terminal (the right pane) | `you@your-mac %` |
| **🌐 Admin Console** | Browser, opened via the links at the top | A web UI, not a terminal |
| **📦 Sandbox shell** | A raw bash shell inside the sandbox | `agent@sbxlab:~/workspace$` |

One new surface this chapter: the **Admin Console**. Most of the
configuration happens there. The terminal still matters — that's
where you verify each policy change actually landed on the
developer's machine.

---

## Why org-level policy is different from local policy

Local `sbx policy` rules sit on a single developer's machine. They're
fast to change, they're owned by the person typing the command, and
they only protect that one workstation. Great for getting unblocked.
Terrible as a security control.

Three things flip when you move policy to the org level:

1. **Same rules, every developer.** Whatever the security team writes
   in the Admin Console applies to every sandbox launched by every
   member of the org, the same way.
2. **Local rules become advisory.** When org policy is active, a
   developer's local `sbx policy` rules show up in `sbx policy ls` —
   but with status `inactive`. They exist, they're just not being
   evaluated.
3. **Deny rules become unbreakable.** An org-level deny can't be
   undone by a local allow. Even with delegation turned on (we'll
   get there), a developer can *extend* the allowlist but can't
   override a deny.

That last property is the whole point. It's the security control
that makes the first two trustworthy.

---

## Setup

🖥 **Host** — verify `sbx` is happy and you're signed into an org
that has AI governance available:

```bash
sbx version
```

```bash
sbx login
```

Clear any leftover local policy from Chapter 1 so we start clean:

```bash no-run-button
sbx policy rm network -g --resource example.com
sbx policy rm network -g --resource api.example.com
```

Either may return `rule not found` — that's fine.

🌐 **Admin Console** — click **⚙️ Manage AI governance** in the bar
at the top of this page. (If the link is disabled, set your org
slug first.) Keep the Admin Console tab open; you'll bounce between
it and the terminal throughout the chapter.

---

## Step 1 — Enable AI governance

The master switch lives at **AI governance → Manage**. Before it's
flipped, the **Network access** and **Filesystem access** pages
render with a banner reading *"Turn on AI governance to control
network access"* and the **Add rule** button is disabled.

🌐 **Admin Console** → **⚙️ Manage AI governance** (top bar):

1. Toggle **AI governance** on.
2. Three sub-pages become functional:

| Page | What it controls |
|---|---|
| **Manage** | The master switch you just flipped |
| **Network access** | Allow / deny rules for outbound traffic from sandboxes |
| **Filesystem access** | Allow / deny rules for host paths sandboxes can mount |

> **Note**
>
> Policy changes take up to 5 minutes to reach developer machines.
> You can force an immediate refresh with `sbx policy reset` on the
> host — but that command also deletes all locally configured
> rules, so it prompts for confirmation.

---

## Step 2 — Add an org-level network rule

The headline behavior to demonstrate: **a local allow rule is
inactive when org policy is on and the rule type isn't delegated.**

🌐 **Admin Console** → click **🛜 Network access** in the top bar
→ **Add rule**:

| Field | Value |
|---|---|
| Name | `Allow Anthropic APIs` |
| Path / target | `api.anthropic.com` |
| Action | Allow |

Add a second rule that we'll come back to when we test delegation:

| Field | Value |
|---|---|
| Name | `Deny internal corp domains` |
| Path / target | `*.corp.internal` |
| Action | Deny |

Save.

> **Tip**
>
> Targets support exact domains (`example.com`), wildcard subdomains
> (`*.example.com`), CIDR ranges, and optional port suffixes
> (`example.com:443`). You can paste multiple entries at once, one
> per line.
>
> Watch out: `example.com` does **not** match subdomains, and
> `*.example.com` does **not** match the root domain. Specify both
> lines if you want to cover both.

🖥 **Host** — pull the new policy down immediately:

```bash no-run-button
sbx policy reset
```

Confirm the prompt. Then:

```bash no-run-button
sbx policy ls
```

You'll see the org rules show up with `remote` in the **ORIGIN**
column — that's the marker for org-pushed rules:

```plaintext no-copy-button
NAME                       TYPE      ORIGIN   DECISION   STATUS    RESOURCES
Allow Anthropic APIs       network   remote   allow      active    api.anthropic.com
Deny internal corp domains network   remote   deny       active    *.corp.internal
```

---

## Step 3 — Watch a local rule go inactive

Restart the sandbox so it picks up the fresh policy:

🖥 **Host**:

```bash no-run-button
sbx rm sbxlab
sbx run sbxlab
```

Inside the sandbox, the agent can still reach `api.anthropic.com`
(it always could — that's how it's been talking the whole time —
but now the path is explicitly allowed and auditable). What it
can't reach is `example.com`, because nothing in the org policy
allows it.

So far, nothing surprising. The interesting part is what happens
when the developer tries to fix it themselves.

🖥 **Host** — back on the Mac, *not* in the sandbox:

```bash no-run-button
sbx policy allow network -g example.com
sbx policy ls
```

The new rule appears in the list — but look at the **STATUS** column:

```plaintext no-copy-button
NAME                       TYPE      ORIGIN   DECISION   STATUS                                                  RESOURCES
allow example              network   local    allow      inactive — corporate policy takes precedence and does   example.com
                                                                   not delegate this rule type to local policy.
Allow Anthropic APIs       network   remote   allow      active                                                  api.anthropic.com
Deny internal corp domains network   remote   deny       active                                                  *.corp.internal
```

`inactive` plus the message *"corporate policy takes precedence and
does not delegate this rule type to local policy."*

📦 **Sandbox shell** — prove it:

```bash no-run-button
sbx exec -it sbxlab bash
```

```bash no-run-button
curl example.com -v
```

You'll see:

```plaintext no-copy-button
Blocked by network policy: domain example.com:80
  detail: no matching allow rule - blocked by default deny policy
```

The local rule is configured. It just isn't being evaluated. **Org
policy decides; local policy waits.**

`exit` out of the sandbox shell before moving on.

---

## Step 4 — Delegate the rule type so developers can extend

Strict org control is great for security teams and unworkable in
practice. Every new dependency would mean filing a ticket.
Delegation is the escape valve: the admin can hand a rule type back
to local control, with two guardrails — **local rules can only
*expand* access, and overly-broad patterns are rejected.**

🌐 **Admin Console** → **🛜 Network access** (top bar) → toggle
**User defined** on. (The hint copy reads *"Let users extend the
policy within set limits."*)

🖥 **Host**:

```bash no-run-button
sbx policy reset
sbx policy ls
```

The local `example.com` rule that was previously `inactive` now
reads `active`:

```plaintext no-copy-button
NAME                       TYPE      ORIGIN   DECISION   STATUS   RESOURCES
allow example              network   local    allow      active   example.com
Allow Anthropic APIs       network   remote   allow      active   api.anthropic.com
Deny internal corp domains network   remote   deny       active   *.corp.internal
```

📦 **Sandbox shell** — same `curl`, different outcome this time:

```bash no-run-button
sbx rm sbxlab
sbx run sbxlab
```

```bash no-run-button
sbx exec -it sbxlab bash
```

```bash no-run-button
curl example.com -v
```

200 OK. The local allow works because the org delegated network
rules back to local control.

---

## Step 5 — Confirm org-level denies still win

This is the property that makes delegation safe to turn on. Even
with **User defined** on, an org-level *deny* can't be undone by a
local *allow*.

🖥 **Host** — try to allow a subdomain of the `*.corp.internal`
deny rule the org set:

```bash no-run-button
sbx policy allow network -g build.corp.internal
```

The CLI accepts it. The rule shows up `local`, `active`, `allow`.
Looks like it should work. But:

📦 **Sandbox shell**:

```bash no-run-button
curl build.corp.internal -v
```

Blocked. Org-level deny wins over local allow, even when the local
rule is more specific. Same logic applies to wildcards: if the org
denies `*.example.com`, a local allow for `api.example.com` has no
effect.

And to keep developers from circumventing the whole policy with one
catch-all rule, the CLI blocks catch-all patterns in delegated
local rules. 🖥 **Host**:

```bash no-run-button
sbx policy allow network -g "*.com"
```

You'll get an error immediately. The blocklist covers `*`, `**`,
`*.com`, `**.com`, `*.*`, `**.**`, and CIDR ranges `0.0.0.0/0` and
`::/0`. Scoped wildcards like `*.example.com` are still fine.

---

## Step 6 — Filesystem rules

Network rules govern what the sandbox can *reach*. Filesystem rules
govern what it can *mount*. By default, sandboxes can mount any
directory the user has access to — fine for an individual, a problem
when sensitive directories like `~/.ssh` and `~/.aws` exist on every
developer's laptop.

🌐 **Admin Console** → click **📂 Filesystem access** in the top bar
→ add these rules:

| Name | Path | Action |
|---|---|---|
| `Allow user workspaces` | `/Users/**/workspace/**` | Allow |
| `Allow project directory` | `~/.docker/labspace/**` | Allow |
| `Deny SSH directory` | `~/.ssh/**` | Deny |
| `Deny AWS credentials` | `~/.aws/**` | Deny |

> **Caution: `**` vs `*` is the single most common mistake**
>
> Use `**` (double wildcard) for recursive matching. `~/**` matches
> all paths under home; `~/*` matches only files directly under `~`,
> with no subdirectories. If a path is denied that you expected to
> allow (or vice-versa), check the wildcard first.

🖥 **Host** — propagate and test the allowed path:

```bash no-run-button
sbx policy reset
```

```bash no-run-button
sbx run sbxlab
```

📦 **Sandbox shell**:

```bash no-run-button
sbx exec -it sbxlab bash
```

```bash no-run-button
mount
```

You'll see the project directory mounted as `virtiofs`, just like
before.

🖥 **Host** — now try a denied path:

```bash no-run-button
sbx rm sbxlab
sbx run --mount ~/.ssh sbxlab
```

You'll see a `mount policy denied` error. The deny rule blocks the
mount before the sandbox even starts — same precedence model as
network rules.

---

## Step 7 — Precedence at a glance

A mental model that covers every situation you'll hit:

1. **Deny beats allow within any layer.** If a target matches both
   an allow and a deny at the same level, it's blocked.
2. **Org rules beat local rules.** When governance is on, local
   rules are inactive unless the org delegates that rule type.
3. **Delegated local rules can expand access, but can't override
   org denies.** Including wildcard denies — local
   `api.example.com` allow has no effect if the org denies
   `*.example.com`.
4. **Default is deny for network, allow for filesystem.** Outbound
   network traffic is blocked unless allowed; filesystem paths
   are mountable unless denied (until you write any rules; once
   rules exist, the standard allow/deny precedence applies).

### Reading `sbx policy ls`

| Column | What to look for |
|---|---|
| **ORIGIN** | `local` (set by the developer) vs `remote` (pushed from the Admin Console) |
| **STATUS** | `active` (being enforced) vs `inactive` (not evaluated — usually means the org didn't delegate this rule type) |
| **DECISION** | `allow` or `deny` |

### Forcing policy propagation

Org changes take up to 5 minutes to reach developer machines. To
force an immediate pull:

```bash no-run-button
sbx policy reset
```

This stops the daemon and re-pulls org policy on the next `sbx`
command. It also deletes all locally configured rules, so warn
developers before they run it.

---

## What you just demonstrated

| Thing | Why it matters |
|---|---|
| ⚙️ Enabling AI governance | One toggle moves your whole org from per-machine policy to centrally-managed policy |
| 🛜 Org-level network rules | Allow / deny entries that propagate to every developer's `sbx policy ls` as `remote` |
| 🔓 Delegation via **User defined** | Lets developers self-serve the long tail of allowlists without filing tickets, without weakening org denies |
| 📂 Org-level filesystem rules | Restricts which host paths sandboxes can mount — the protection against `~/.ssh`, `~/.aws`, and `/etc` accidents |
| ⚖️ Precedence | Deny beats allow, org beats local, delegated local can extend but never override |

This is the difference between an isolation primitive that protects
one developer and a control plane that protects an organization. The
sandbox does the same thing it always did. The Admin Console is what
makes "the same thing, applied uniformly" possible.

## Try this next

- Hand a teammate the Admin Console URL for **Network access** and
  watch what they propose first. The conversation that follows
  ("why are we allowing `*.googleapis.com` again?") is usually more
  valuable than the policy itself.
- Add a deny rule for a domain the agent quietly relies on (try
  `*.github.com`) and watch the exact failure mode the next time you
  run a sandbox. Then remove it. That five-minute exercise teaches
  more about what agents touch than any docs page.
- Turn on **User defined** for filesystem but leave network strict.
  Most orgs settle here: network is denylist-by-default with admin
  approval, filesystem can be extended by developers as long as
  `~/.ssh` and `~/.aws` are explicitly denied.

## Reference

- Organization governance docs: <https://docs.docker.com/ai/sandboxes/security/governance/>
- Local sandbox policies: <https://docs.docker.com/ai/sandboxes/security/policy/>
- Isolation layers: <https://docs.docker.com/ai/sandboxes/security/isolation/>
- Credentials & the credential proxy: <https://docs.docker.com/ai/sandboxes/security/credentials/>

---

*Chapter authored as a follow-on to the Blast Radius Test.*
CHAPTER_EOF

# ---- Patch labspace.yaml -----------------------------------------------------
# Only append the section if it isn't already registered.
if grep -q "contentPath: 02-governance.md" "$YAML_FILE"; then
  info "labspace.yaml already has the governance section — leaving as-is"
else
  info "Patching $YAML_FILE to register the new section"
  # Append matching the existing two-space indent convention
  cat >> "$YAML_FILE" <<'YAML_EOF'
  - title: "Organization Governance"
    contentPath: 02-governance.md
    duration: 20
YAML_EOF
fi

# ---- Commit ------------------------------------------------------------------
git add "$CHAPTER_FILE" "$YAML_FILE"
if git diff --cached --quiet; then
  warn "No changes to commit (files already match)."
else
  info "Committing"
  git commit -q -m "Add Organization Governance chapter

New chapter labspace/02-governance.md walks through Docker's AI governance
controls in the Admin Console:

- Set Docker Hub Org form at the top of the page (persists to localStorage)
- Top tab/link bar deep-linking into Manage / Network access /
  Filesystem access for the configured org
- Enable AI governance + add org-level network rules
- Demonstrate inactive local rules under corporate policy
- Toggle User defined to delegate rule types back to local control
- Confirm org-level denies still beat delegated local allows
- Filesystem rules with the ** vs * wildcard gotcha
- Precedence cheat sheet and sbx policy reset for forced propagation

Follows the same surface-label convention and code-fence directives
(bash no-run-button, plaintext no-copy-button) as 01-blast-radius-test.md."
fi

# ---- Push / PR ---------------------------------------------------------------
if [[ $DO_PUSH -eq 1 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    warn "gh CLI not found — skipping push."
    warn "To push manually:"
    warn "  cd $(pwd)"
    warn "  git push -u origin $BRANCH"
  elif ! gh auth status >/dev/null 2>&1; then
    warn "gh CLI is not authenticated. Run 'gh auth login' and then:"
    warn "  cd $(pwd)"
    warn "  git push -u origin $BRANCH"
  else
    info "Pushing $BRANCH"
    git push -u origin "$BRANCH"
    if [[ $DO_PR -eq 1 ]]; then
      info "Opening pull request"
      gh pr create \
        --base "$DEFAULT_BRANCH" \
        --head "$BRANCH" \
        --title "Add Organization Governance chapter" \
        --body "Adds a second chapter to the labspace covering Docker's AI governance controls (Admin Console → AI governance → Network / Filesystem access).

**What's new**
- \`labspace/02-governance.md\` with the full walkthrough
- A \"Set Docker Hub Org\" form at the top of the page (persists to localStorage)
- A top tab/link bar deep-linking into Manage / Network access / Filesystem access for the configured org
- New section registered in \`labspace/labspace.yaml\`

**Conventions**
Follows the same surface labels (🖥 Host / 🌐 Admin Console / 📦 Sandbox shell) and code-fence directives (\`bash no-run-button\`, \`plaintext no-copy-button\`) as \`01-blast-radius-test.md\`.

**Test**
Run \`bash start-labspace.sh\` and open http://localhost:3030 — the new chapter appears under the Blast Radius Test." \
        || warn "gh pr create failed (PR may already exist for this branch)"
    fi
  fi
else
  info "Skipping push (--no-push)."
  info "To push later:"
  info "  cd $(pwd)"
  info "  git push -u origin $BRANCH"
fi

echo
info "Done."
echo "  Branch:       $BRANCH"
echo "  Chapter file: $(pwd)/$CHAPTER_FILE"
echo "  Test locally: cd $(pwd) && bash start-labspace.sh   # then http://localhost:3030
