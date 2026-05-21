#!/usr/bin/env bash
# add-governance-chapter.sh
#
# Adds an "Organization Governance" chapter to your existing
# ajeetraina/labspace-sbx-blastradius repo.
#
# Fixes in this revision:
#   - Deep-link buttons are now LIVE even before the org is set: they
#     default to https://app.docker.com/admin (which resolves to whatever
#     org the user has chosen in the console). JS upgrades them to
#     org-specific deep-links when an org slug is set. This works even if
#     the labspace renderer doesn't run inline <script> blocks.
#   - Removed the bogus `-g` flag from `sbx policy rm/allow` commands —
#     current `sbx` builds reject `unknown shorthand flag: 'g' in -g`.
#     Correct form is `sbx policy rm network --resource <domain>`.
#   - Optional --no-tmux flag: skips patching start-labspace.sh. By default
#     the script patches it so ttyd launches into a tmux session with two
#     pre-named windows (host + sandbox). The reader sees them as tabs at
#     the bottom of the ttyd pane and switches with Ctrl-b 0 / Ctrl-b 1.
#     Use --no-tmux if you'd rather keep the bare-shell behaviour.
#
# Usage:
#   ./add-governance-chapter.sh                        # full flow with push + PR
#   ./add-governance-chapter.sh --no-push              # local commit only
#   ./add-governance-chapter.sh --no-pr                # push but skip PR
#   ./add-governance-chapter.sh --dir ./blastradius    # use existing clone
#   ./add-governance-chapter.sh --branch feat/gov-v2   # custom branch name
#   ./add-governance-chapter.sh --no-tmux              # skip start-labspace.sh patch
#
# Re-runnable: existing files are overwritten; yaml is only patched if
# the section isn't already registered.

set -euo pipefail

# ---- Defaults ----------------------------------------------------------------
OWNER="ajeetraina"
REPO="labspace-sbx-blastradius"
DIR=""
BRANCH="feat/governance-chapter"
DO_PUSH=1
DO_PR=1
WITH_TMUX=1

# ---- Arg parsing -------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)      OWNER="$2"; shift 2 ;;
    --repo)       REPO="$2"; shift 2 ;;
    --dir)        DIR="$2"; shift 2 ;;
    --branch)     BRANCH="$2"; shift 2 ;;
    --no-push)    DO_PUSH=0; DO_PR=0; shift ;;
    --no-pr)      DO_PR=0; shift ;;
    --no-tmux)    WITH_TMUX=0; shift ;;
    -h|--help)    sed -n '2,32p' "$0"; exit 0 ;;
    *)            echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

DIR="${DIR:-$REPO}"
CHAPTER_FILE="labspace/02-governance.md"
YAML_FILE="labspace/labspace.yaml"
START_SCRIPT="start-labspace.sh"

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

# ---- Sanity-check ------------------------------------------------------------
[[ -f "labspace/01-blast-radius-test.md" ]] || fatal "labspace/01-blast-radius-test.md not found — is this the right repo?"
[[ -f "$YAML_FILE" ]] || fatal "$YAML_FILE not found — is this the right repo?"

if ! git diff --quiet || ! git diff --cached --quiet; then
  fatal "Working tree has uncommitted changes. Stash or commit them first."
fi

info "Fetching latest"
git fetch origin --quiet

DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -1)
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
git checkout -q "$DEFAULT_BRANCH"
git pull -q --ff-only origin "$DEFAULT_BRANCH" 2>/dev/null || warn "Could not fast-forward $DEFAULT_BRANCH (continuing)"

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  info "Branch $BRANCH already exists — switching to it"
  git checkout -q "$BRANCH"
else
  info "Creating branch $BRANCH"
  git checkout -q -b "$BRANCH"
fi

# ---- Write the chapter -------------------------------------------------------
info "Writing $CHAPTER_FILE"
cat > "$CHAPTER_FILE" <<'CHAPTER_EOF'
<!--
  Three-step stepper at the top of the chapter, matching the actual
  Admin Console workflow:

    Step 1 → enable AI governance (the master toggle)
    Step 2 → configure Filesystem access rules
    Step 3 → configure Network access rules

  Each step's button opens the Docker Admin Console in a new tab; the
  attendee's session there determines the org automatically (no need
  to template URLs for each attendee, no JS, no form, no helper page).
  Step prose tells them which sidebar item to click once they land.

  Why this design: the labspace markdown renderer strips inline
  <script> tags as an XSS defense, so anything interactive needs to
  be plain HTML. Plain anchor links + visual stepping == bulletproof.
-->
<style>
  .gov-steps {
    margin: 0 0 24px 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }
  .gov-step {
    display: flex; align-items: flex-start; gap: 14px;
    border: 1px solid #d0d7de; border-radius: 8px;
    padding: 14px 18px; margin: 0 0 10px 0;
    background: #ffffff;
  }
  .gov-step__num {
    flex-shrink: 0;
    width: 32px; height: 32px;
    border-radius: 50%;
    background: #1f6feb; color: #fff;
    display: flex; align-items: center; justify-content: center;
    font-weight: 600; font-size: 14px;
  }
  .gov-step__body { flex: 1; min-width: 0; }
  .gov-step__title { font-weight: 600; color: #1f2328; font-size: 15px; margin: 4px 0 4px 0; }
  .gov-step__desc { color: #57606a; font-size: 13px; line-height: 1.5; margin: 0 0 10px 0; }
  .gov-step__desc strong { color: #1f2328; }
  .gov-step__btn {
    display: inline-block;
    padding: 6px 14px;
    border: 1px solid #1f6feb;
    background: #1f6feb;
    color: #fff;
    border-radius: 6px;
    text-decoration: none;
    font-size: 13px;
    font-weight: 500;
  }
  .gov-step__btn:hover { background: #1a5fd1; }
</style>

<div class="gov-steps">

  <div class="gov-step">
    <div class="gov-step__num">1</div>
    <div class="gov-step__body">
      <div class="gov-step__title">Enable AI Governance</div>
      <div class="gov-step__desc">
        Open the Admin Console, then in the left sidebar go to <strong>AI governance → Manage</strong> and toggle <strong>AI governance</strong> on. This is the master switch — until it's on, the Filesystem and Network pages refuse to accept rules.
      </div>
      <a class="gov-step__btn" href="https://app.docker.com/admin" target="_blank" rel="noopener">⚙️ Open Admin Console</a>
    </div>
  </div>

  <div class="gov-step">
    <div class="gov-step__num">2</div>
    <div class="gov-step__body">
      <div class="gov-step__title">Configure Filesystem access</div>
      <div class="gov-step__desc">
        In the same Admin Console tab, go to <strong>AI governance → Filesystem access</strong>. Add allow / deny rules for which host paths sandboxes can mount. We'll walk through example rules in Step 6 below.
      </div>
      <a class="gov-step__btn" href="https://app.docker.com/admin" target="_blank" rel="noopener">📂 Open Admin Console</a>
    </div>
  </div>

  <div class="gov-step">
    <div class="gov-step__num">3</div>
    <div class="gov-step__body">
      <div class="gov-step__title">Configure Network access</div>
      <div class="gov-step__desc">
        In the same Admin Console tab, go to <strong>AI governance → Network access</strong>. Add allow / deny rules for which domains sandboxes can reach. We'll walk through example rules in Step 2–5 below.
      </div>
      <a class="gov-step__btn" href="https://app.docker.com/admin" target="_blank" rel="noopener">🛜 Open Admin Console</a>
    </div>
  </div>

</div>

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

> **Use the steps above first**
>
> The three numbered steps at the top of this chapter walk you
> through the workflow: enable AI governance, configure filesystem
> access, configure network access. Each step's button opens the
> Admin Console in a new tab — the chapter prose below walks you
> through what to fill in once you're there.

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
| **🌐 Admin Console** | Browser, opened via the buttons at the top | A web UI, not a terminal |
| **📦 Sandbox shell** | A raw bash shell inside the sandbox | `agent@sbxlab:~/workspace$` |

> **Tip — two terminals at once**
>
> This chapter has you bouncing between the host shell and the
> sandbox shell. The labspace ships with two tmux windows by
> default — look for the `host` and `sandbox` tabs at the bottom
> of the terminal pane and switch between them with
> <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>0</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>1</kbd>.
>
> If you don't see the tabs (older `start-labspace.sh`, or `tmux`
> isn't installed locally), you can still split the current pane:
> <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>"</kbd> for a horizontal split,
> or <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>%</kbd> for vertical.

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
sbx policy rm network --resource example.com
sbx policy rm network --resource api.example.com
```

Either may return `rule not found` — that's fine.

🌐 **Admin Console** — click **⚙️ Manage AI governance** at the
top of this page. Keep the Admin Console tab open; you'll bounce
between it and the terminal throughout the chapter.

---

## Step 1 — Enable AI governance

The master switch lives at **AI governance → Manage**. Before it's
flipped, the **Network access** and **Filesystem access** pages
render with a banner reading *"Turn on AI governance to control
network access"* and the **Add rule** button is disabled.

🌐 **Admin Console** → use **Step 1** above, or in the left sidebar
go to **AI governance → Manage**:

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

🌐 **Admin Console** → use **Step 3** above, or in the left sidebar
go to **AI governance → Network access** → **Add rule**:

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
sbx policy allow network --resource example.com
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

🌐 **Admin Console** → **AI governance → Network access** →
toggle **User defined** on. (The hint copy reads *"Let users
extend the policy within set limits."*)

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
sbx policy allow network --resource build.corp.internal
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
sbx policy allow network --resource "*.com"
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

🌐 **Admin Console** → use **Step 2** above, or in the left sidebar
go to **AI governance → Filesystem access** → add these rules:

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
if grep -q "contentPath: 02-governance.md" "$YAML_FILE"; then
  info "labspace.yaml already has the governance section — leaving as-is"
else
  info "Patching $YAML_FILE to register the new section"
  cat >> "$YAML_FILE" <<'YAML_EOF'
  - title: "Organization Governance"
    contentPath: 02-governance.md
    duration: 20
YAML_EOF
fi

# ---- Optionally patch start-labspace.sh for tmux multi-terminal --------------
if [[ $WITH_TMUX -eq 1 ]]; then
  if [[ ! -f "$START_SCRIPT" ]]; then
    warn "$START_SCRIPT not found — skipping tmux patch"
  elif grep -q "labspace-tmux-launcher" "$START_SCRIPT"; then
    info "$START_SCRIPT already patched for tmux — leaving as-is"
  else
    info "Patching $START_SCRIPT for tmux multi-terminal"
    # Insert tmux-launcher writeout right before the ttyd launch line,
    # then swap `zsh` for the launcher.
    python3 - "$START_SCRIPT" <<'PYEOF'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
src = p.read_text()

launcher_block = r"""
# ── Tmux launcher (added for multi-terminal support) ───────────
# Writes a launcher script that ttyd will exec. The launcher attaches
# to (or creates) a tmux session with two pre-named windows so the
# reader sees 'host' and 'sandbox' tabs at the bottom of the ttyd pane.
# tmux is verified above in the preflight check.
LAUNCHER="$(mktemp -t labspace-tmux-launcher.XXXXXX.sh)"
chmod +x "$LAUNCHER"
cat > "$LAUNCHER" <<'LAUNCHER_EOF'
#!/usr/bin/env bash
SESSION="labspace"
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session  -d -s "$SESSION" -n host    "${SHELL:-zsh} -l"
  tmux new-window      -t "$SESSION:" -n sandbox "${SHELL:-zsh} -l"
  tmux select-window   -t "$SESSION:host"
fi
exec tmux attach -t "$SESSION"
LAUNCHER_EOF
trap 'rm -f "$LAUNCHER"' EXIT

"""

# Insert the launcher block right before the "ttyd" launch line.
# Use a callable replacement to sidestep backslash-escaping in re.sub's
# replacement template — passing literal quotes through `\1...\2` ends up
# double-escaped in bash and breaks the launch.
def _replace(m):
    return launcher_block.lstrip() + m.group(1) + '"$LAUNCHER"' + m.group(2)
src = re.sub(
    r"(ttyd -p \$TTYD_PORT --writable --max-clients 4 )zsh( &)",
    _replace,
    src,
    count=1,
)

# Add a tmux preflight check immediately after the ttyd check, matching the
# same format as the existing ttyd and sbx checks.
tmux_check = '''
# ── 1b. Check tmux ─────────────────────────────────────────────
if ! command -v tmux &>/dev/null; then
  echo ""
  echo -e "${RED}ERROR: tmux not found.${NC}"
  echo ""
  echo "  This labspace uses tmux to give you two terminals (host + sandbox)"
  echo "  as tabs at the bottom of the ttyd pane."
  echo ""
  echo "  Install it with:"
  echo "    brew install tmux          # macOS"
  echo "    sudo apt install tmux      # Ubuntu/Debian"
  echo ""
  echo "  Then re-run: bash start-labspace.sh"
  exit 1
fi

'''
# Insert immediately after the closing 'fi' of the ttyd check (the first
# blank line after '# ── 1. Check ttyd ──...').
src = re.sub(
    r"(# ── 1\. Check ttyd ─.*?\nfi\n)\n",
    r"\1" + tmux_check,
    src,
    count=1,
    flags=re.DOTALL,
)
p.write_text(src)
PYEOF
  fi
fi

# ---- Commit ------------------------------------------------------------------
git add "$CHAPTER_FILE" "$YAML_FILE"
[[ $WITH_TMUX -eq 1 && -f "$START_SCRIPT" ]] && git add "$START_SCRIPT"

if git diff --cached --quiet; then
  warn "No changes to commit (files already match)."
else
  info "Committing"
  COMMIT_MSG="Add Organization Governance chapter"
  [[ $WITH_TMUX -eq 1 ]] && COMMIT_MSG="$COMMIT_MSG + host/sandbox tmux tabs"
  git commit -q -m "$COMMIT_MSG

New chapter labspace/02-governance.md walks through Docker's AI governance
controls in the Admin Console:

- Set Docker Hub Org form at the top of the page (persists to localStorage)
- Top tab/link bar deep-linking into Manage / Network access /
  Filesystem access for the configured org; links work even before an
  org is set (default to /admin so the console resolves the org)
- Enable AI governance + add org-level network rules
- Demonstrate inactive local rules under corporate policy
- Toggle User defined to delegate rule types back to local control
- Confirm org-level denies still beat delegated local allows
- Filesystem rules with the ** vs * wildcard gotcha
- Precedence cheat sheet and sbx policy reset for forced propagation

Multi-terminal: start-labspace.sh is patched so ttyd launches into a
tmux session with two pre-named windows (host + sandbox). The reader
sees them as tabs at the bottom of the ttyd pane and switches with
Ctrl-b 0 / Ctrl-b 1. A tmux preflight check is added alongside the
existing ttyd and sbx checks.

CLI commands use the current 'sbx policy ... --resource <domain>' form
(the earlier '-g' shorthand is no longer accepted by sbx).

Follows the same surface labels (🖥 Host / 🌐 Admin Console / 📦 Sandbox
shell) and code-fence directives (bash no-run-button, plaintext
no-copy-button) as 01-blast-radius-test.md."
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
- A top tab/link bar with three deep-link buttons (Manage / Network / Filesystem). Buttons work even before an org is set — they default to \`/admin\` and the console handles org selection. Once a slug is entered, the JS upgrades them to org-specific deep-links.
- New section registered in \`labspace/labspace.yaml\`

**Bug fixes vs the earlier draft**
- \`sbx policy rm/allow\` commands no longer use the \`-g\` shorthand (current sbx builds reject it as \`unknown shorthand flag\`)
- Deep-link buttons no longer rely on JS having run successfully — they're live by default

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
[[ $WITH_TMUX -eq 1 ]] && echo "  Tmux:         $START_SCRIPT patched for host/sandbox tabs (requires tmux on the host)"
echo "  Test locally: cd $(pwd) && bash start-labspace.sh   # then http://localhost:3030"
