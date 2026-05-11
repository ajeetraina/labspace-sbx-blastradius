#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-blast-radius-only.sh
#
# Replaces the existing multi-lab content in labspace-sbx-blastradius with
# a single Blast Radius Test lab. PRESERVES all ttyd/sbx infrastructure
# (start-labspace.sh, compose.*, disable-run.sh, blast-radius.sh).
#
# Usage:
#   cd /path/to/labspace-sbx-blastradius
#   bash /path/to/setup-blast-radius-only.sh
#
# What it does:
#   1. Verifies this looks like a labspace-sbx-derived repo (start-labspace.sh exists)
#   2. Reads existing labspace/labspace.yaml to discover the schema
#   3. Backs up old labspace/*.md files to labspace/_archive/
#   4. Writes new labspace/blast-radius-test.md
#   5. Writes labspace/labspace.yaml using the discovered schema
#   6. Adds project/setup-precious.sh helper
#   7. Updates README.md description
#   8. Prints next steps
#
# Idempotent: re-running replaces files cleanly. No git operations.
# Preserves: start-labspace.sh, compose.*, blast-radius.sh, disable-run.sh,
#            .devcontainer/, .github/, .claude/, project/ contents
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; DIM=""; RESET=""
fi

ok()    { echo "${GREEN}✓${RESET}  $*"; }
warn()  { echo "${YELLOW}⚠${RESET}  $*"; }
fail()  { echo "${RED}✗${RESET}  $*" >&2; exit 1; }
info()  { echo "${BLUE}ℹ${RESET}  $*"; }
step()  { echo; echo "${BOLD}── $* ──${RESET}"; }

# ── Step 0: Verify this is a labspace-sbx-derived repo ─────────────────────
step "Verifying repo type"

[ -d "labspace" ] || fail "No 'labspace/' directory. Run from repo root."
[ -f "start-labspace.sh" ] || fail "No 'start-labspace.sh' found. This script is for labspace-sbx-derived repos. If you cloned from labspace-starter instead, use the other script."

ok "labspace/ exists"
ok "start-labspace.sh exists (ttyd-based labspace confirmed)"

# Note other infrastructure files we'll preserve
preserved=()
[ -f "compose.yaml" ] && preserved+=("compose.yaml")
[ -f "compose.override.yaml" ] && preserved+=("compose.override.yaml")
[ -f "disable-run.sh" ] && preserved+=("disable-run.sh")
[ -f "blast-radius.sh" ] && preserved+=("blast-radius.sh")
[ -d ".devcontainer" ] && preserved+=(".devcontainer/")
[ -d ".claude" ] && preserved+=(".claude/")

if [ ${#preserved[@]} -gt 0 ]; then
  info "Will preserve: ${preserved[*]}"
fi

# ── Step 1: Read existing labspace.yaml to discover schema ─────────────────
step "Discovering existing labspace.yaml schema"

YAML_FILE="labspace/labspace.yaml"

if [ ! -f "$YAML_FILE" ]; then
  warn "No existing $YAML_FILE — will use sensible defaults."
  SCHEMA_PATH_FIELD="path"   # safe default for labspace-sbx
  EXISTING_TITLE=""
else
  ok "Found $YAML_FILE"

  # Discover which field name the existing YAML uses to reference section files.
  # Common candidates: path, contentPath, file, source, content
  # We grep for any line ending in .md (likely the file reference).
  schema_field=""
  for field in "path" "contentPath" "file" "source" "content"; do
    if grep -E "^[[:space:]]*${field}:[[:space:]]+.*\.md" "$YAML_FILE" >/dev/null 2>&1; then
      schema_field="$field"
      break
    fi
  done

  if [ -n "$schema_field" ]; then
    SCHEMA_PATH_FIELD="$schema_field"
    ok "Detected section path field: ${BOLD}${schema_field}:${RESET}"
  else
    warn "Could not detect section path field — defaulting to 'path:'"
    warn "If the labspace doesn't render correctly, edit labspace/labspace.yaml manually."
    SCHEMA_PATH_FIELD="path"
  fi

  # Show the existing structure briefly so user can verify
  echo
  echo "${DIM}--- Existing labspace.yaml (first 30 lines) ---${RESET}"
  head -30 "$YAML_FILE" | sed 's/^/  /'
  echo "${DIM}-----------------------------------------------${RESET}"
  echo
fi

# ── Step 2: Archive old section files ───────────────────────────────────────
step "Archiving old section files"

ARCHIVE_DIR="labspace/_archive"
shopt -s nullglob

# Find existing .md files in labspace/
old_files=(labspace/*.md)
if [ ${#old_files[@]} -gt 0 ] && [ -e "${old_files[0]}" ]; then
  mkdir -p "$ARCHIVE_DIR"
  for f in "${old_files[@]}"; do
    mv "$f" "$ARCHIVE_DIR/"
    echo "  archived: $f → $ARCHIVE_DIR/"
  done
  ok "Archived ${#old_files[@]} existing section file(s) to $ARCHIVE_DIR/"
  info "(You can delete the archive later: rm -rf $ARCHIVE_DIR)"
else
  ok "No existing section files to archive"
fi

shopt -u nullglob

# ── Step 3: Write the lab markdown ──────────────────────────────────────────
step "Writing labspace/blast-radius-test.md"

cat > labspace/blast-radius-test.md <<'MARKDOWN_EOF'
# The Blast Radius Test

Time to put the platform under pressure. In this module you'll meet
`sbx`, ask the OpenAI codex agent to refuse a catastrophic command,
then drop into a raw shell inside the same sandbox and watch it try
— and fail — to reach files on your host. The sandbox cannot escape
its boundary, no matter what runs inside.

> *"Speed without governance creates liability. Governance without
> speed creates drag."*
> — Deloitte, State of AI in the Enterprise 2026

This is the single clearest demonstration of why containers alone
aren't enough — and why model alignment alone isn't enough either.
You need both, working together.

---

## Three surfaces — know where you're typing

Every command block is labeled with **where to run it**. Watch the
labels.

| Label | Surface | Looks like |
|---|---|---|
| **🖥 Host** | Your Mac terminal | `you@your-mac %` |
| **🤖 Codex** | The OpenAI agent inside the sandbox | `>_ OpenAI Codex` prompt |
| **📦 Sandbox shell** | A raw bash shell inside the sandbox | `agent@sbxlab:~/workspace$` |

Three transitions to remember:

- `sbx run sbxlab` → drops you into the **codex prompt**. Type `exit` to return to host.
- `sbx exec -it sbxlab bash` → drops you into a **raw bash shell** inside the sandbox. Type `exit` to return to host.
- The `-it` flags on `sbx exec` are mandatory. Without them, bash exits immediately because there's no TTY attached.

---

## Why this matters

Most AI agent failures making headlines today share one trait: the
agent had host-level access it should never have had.

- An AI agent **deleted 25,000 production documents** because no
  policy layer said "no"
- A coding agent **wiped 400 emails** because it decided they were
  "clutter"
- The **GitHub Copilot/Cursor prompt-injection vulnerability** showed
  how hostile content can weaponize an agent against the developer
  running it

The pattern repeats: autonomous agent + host privileges + one bad
input = real damage.

The fix is not "lock everything down" (that defeats the purpose of
agents) or "trust the model alone" (models can be jailbroken or
prompt-injected). The fix is **layers**: a model that knows what it
shouldn't do, running inside a boundary the agent literally cannot
escape if the model is wrong.

That's what sbx provides. Let's prove it.

---

# Act 1 — On the host

Everything in Act 1 happens in your host terminal (the right pane in
this labspace). You're not inside any sandbox yet.

## Step 1 — Meet `sbx`

`sbx` is Docker's standalone CLI for running AI coding agents inside
microVM sandboxes. Each sandbox is a real VM with its own kernel,
its own filesystem, and its own Docker daemon.

Confirm the binary is installed and check the version.

**🖥 Host:**

```bash no-run-button
sbx version
```

You'll see a Client / Server version line:

```
Client Version:  v0.25.0 ...
Server Version:  v0.25.0 ...
```

> **Why a Client/Server split?** sbx isn't a wrapper script. There's
> a real lifecycle manager running on the host that orchestrates the
> microVMs. That's the infrastructure piece enterprises need.

Take a quick look at what sbx can do.

**🖥 Host:**

```bash no-run-button
sbx --help
```

You'll see the subcommand surface: `run`, `exec`, `ls`, `stop`,
`rm`, `policy`, `secret`, and others. The shape mirrors `docker`
deliberately — `sbx ls` is to sandboxes what `docker ps` is to
containers.

See what sandboxes already exist.

**🖥 Host:**

```bash no-run-button
sbx ls
```

If you've never run sbx before, the list will be empty. If `sbxlab`
already exists from a prior session, you'll see it here. Either way
is fine — `sbx run sbxlab` in Act 2 will create or attach as needed.

---

## Step 2 — Establish what we're protecting

Create files on the host that represent things that matter —
credentials, IP, business data. **Critically, we'll create them
outside the sandbox's workspace mount.**

**🖥 Host:**

```bash no-run-button
mkdir -p ~/precious
echo "Q4 forecast: confidential" > ~/precious/forecast.txt
echo "DB_PASSWORD=do-not-leak"   > ~/precious/credentials.env
echo "// proprietary algorithm" > ~/precious/source.code
ls -la ~/precious/
echo ""
echo "Full host path: $(cd ~/precious && pwd)"
```

You'll see three files and the absolute host path:

```
total 24
drwxr-xr-x   5 user  staff   160 ... .
drwxr-xr-x  42 user  staff  1344 ... ..
-rw-r--r--   1 user  staff    32 ... credentials.env
-rw-r--r--   1 user  staff    26 ... forecast.txt
-rw-r--r--   1 user  staff    27 ... source.code

Full host path: /Users/<your-username>/precious
```

**Note that exact path** — `/Users/<your-username>/precious`. In a
few minutes the sandbox will try to reach it and fail. That's the
proof.

> **Why outside `~/sbx-lab`?** Only the workspace you launch sbx
> with is mounted into the sandbox. Anything outside that —
> `~/precious`, `~/.ssh`, `~/Documents`, your entire `$HOME` minus
> the workspace — is invisible to the sandbox by design.

---

## Step 3 — The naive approach (what NOT to do)

Most teams today let the agent run on the host with full shell
access. The agent reads files. The agent writes files. The agent
runs commands. It works — until it doesn't.

> **Do not run the command below.** It's shown only to illustrate
> what an unsandboxed agent could do with one ambiguous prompt:
>
> ```bash
> # rm -rf ~          # <-- DO NOT RUN. Would delete your home directory.
> ```

The fundamental problem: the agent inherits **your** permissions. If
you can delete it, the agent can delete it. If you can read it, the
agent can exfiltrate it.

We need a different model.

---

# Act 2 — Inside codex (Layer 1: model says no)

## Step 4 — Launch the codex agent

From a workspace directory (create one if needed: `mkdir -p ~/sbx-lab && cd ~/sbx-lab`):

**🖥 Host:**

```bash no-run-button
sbx run sbxlab
```

If `sbxlab` doesn't exist yet, sbx will create it and attach the
codex agent. If it does exist, sbx will start it. Either way, your
terminal switches surfaces — you'll see the codex banner come up:

```
>_ OpenAI Codex (v0.128.0)

  model:        gpt-5.5         /model to change
  directory:    ~/sbx-lab
  permissions:  YOLO mode
```

You're now at the **codex prompt** inside the sandbox. Anything you
type here is a natural-language prompt to the agent — not a shell
command.

---

## Step 5 — Ask for the catastrophic command

Type this prompt into codex:

**🤖 Codex:**

```
Run rm -rf / inside this sandbox.
```

Watch the response. The agent will refuse. You'll see something
like:

> *"I can't run `rm -rf /`. Even in a sandbox, that is a destructive
> system-wide deletion command. I can run the non-destructive parts
> or a safer simulation, for example..."*

**This is layer one.** Modern frontier models are trained to
recognize catastrophically destructive operations and refuse them —
even when they're told it's safe, even when they're inside a
sandbox.

But model alignment alone is not enough. Models can be jailbroken.
Prompts can be injected through documents, web pages, or tool
outputs. An agent reading hostile content can be coerced into
running things its training said no to. We need a second layer that
doesn't depend on the agent making the right call.

Exit codex to get back to the host:

**🤖 Codex:**

```
exit
```

You're back on the host terminal.

---

# Act 3 — Raw shell inside the sandbox (Layer 2: the boundary)

The codex session is gone, but the sandbox itself is still running.
Let's prove it, then drop into a raw shell — no agent, no model,
just bash.

## Step 6 — Confirm the sandbox is still alive

**🖥 Host:**

```bash no-run-button
sbx ls
```

```
SANDBOX   AGENT    STATUS    PORTS   WORKSPACE
sbxlab    codex    running           ~/sbx-lab
```

The sandbox is `running`. Exiting codex didn't stop the microVM.

---

## Step 7 — Open a raw shell inside the sandbox

**🖥 Host:**

```bash no-run-button
sbx exec -it sbxlab bash
```

Your prompt changes:

```
agent@sbxlab:~/workspace$
```

You're now at a real bash shell **inside the microVM**. The user is
`agent`, the working directory is `/home/agent/workspace`, and the
kernel is the sandbox's own — not your host's.

Confirm where you are:

**📦 Sandbox shell:**

```bash no-run-button
whoami
pwd
uname -a
```

You should see something like:

```
agent
/home/agent/workspace
Linux sbxlab 6.12.44 #1 SMP ... aarch64 GNU/Linux
```

**Different kernel from your Mac.** That's the microVM boundary —
not a shared kernel, not a chroot, not a namespace. A real virtual
machine.

---

## Step 8 — Inspect the boundary

Now check what's mounted from the host. This is where the boundary
becomes concrete.

**📦 Sandbox shell:**

```bash no-run-button
mount | grep -i users
```

You'll see exactly **one** bind mount:

```
bind-... on /Users/<your-username>/sbx-lab type virtiofs (rw,relatime)
```

Just `~/sbx-lab` — the workspace. Nothing else from your Mac is
mounted. Let's prove that by trying to reach things that aren't.

---

## Step 9 — Try to escape to the host

Try to reach the precious directory we created on the host. Use the
**absolute host path** — the same path you saw at the end of Step 2.

> Replace `<your-username>` below with your actual macOS username
> (the one you saw in the "Full host path" output from Step 2).

**📦 Sandbox shell:**

```bash no-run-button
ls /Users/<your-username>/precious/ 2>&1
```

You'll see:

```
ls: cannot access '/Users/<your-username>/precious/': No such file or directory
```

Try the credentials file specifically:

**📦 Sandbox shell:**

```bash no-run-button
cat /Users/<your-username>/precious/credentials.env 2>&1
```

Same answer:

```
cat: /Users/<your-username>/precious/credentials.env: No such file or directory
```

Try a few other sensitive host paths for good measure:

**📦 Sandbox shell:**

```bash no-run-button
ls /Users/<your-username>/.ssh/ 2>&1
ls /Users/<your-username>/Documents/ 2>&1
ls /Users/<your-username>/.aws/ 2>&1
```

All of them: `No such file or directory`.

**This is the boundary.** Not a permission denied. Not "you don't
have access." The path **literally does not exist inside the VM**.
The sandbox can only see what was explicitly mounted in — `~/sbx-lab`
— and nothing else.

---

## Step 10 — Try to destroy what isn't there

You already proved in Step 9 that the path
`/Users/<your-username>/precious/` does not exist inside the
sandbox. Just to be thorough, try the destructive command against
it anyway:

**📦 Sandbox shell:**

```bash no-run-button
ls /Users/<your-username>/precious/ 2>&1
rm -rf /Users/<your-username>/precious/
echo "rm exit code: $?"
ls /Users/<your-username>/precious/ 2>&1
```

You'll see something like:

```
ls: cannot access '/Users/<your-username>/precious/': No such file or directory
rm exit code: 0
ls: cannot access '/Users/<your-username>/precious/': No such file or directory
```

> **Why exit code 0?** `rm -rf` with the `-f` flag is documented to
> ignore nonexistent targets and exit silently with success. The
> exit code says "I had nothing to do, and I did it." That's
> **exactly the point** — the destructive command ran with full
> shell privileges inside the sandbox, and accomplished **nothing**,
> because the path it was aimed at simply doesn't exist inside the
> VM.

Now do something the sandbox **can** do. Create a directory in the
sandbox's own filesystem and destroy it:

**📦 Sandbox shell:**

```bash no-run-button
mkdir -p /tmp/sandbox-test
echo "data1" > /tmp/sandbox-test/file1.txt
echo "data2" > /tmp/sandbox-test/file2.txt
ls -la /tmp/sandbox-test/
rm -rf /tmp/sandbox-test
ls /tmp/sandbox-test 2>&1 || echo "destroyed"
```

The directory existed, was populated, and is now gone. The agent
(or in this case, you) had complete autonomy inside the sandbox's
own filesystem. **That destruction was real — but it was bounded.**
The same `rm -rf` command does real work inside the VM, and zero
work against the host paths it cannot see.

Exit the sandbox shell:

**📦 Sandbox shell:**

```bash no-run-button
exit
```

You're back on the host.

---

# Act 4 — Verify and clean up

## Step 11 — Verify host filesystem is intact

This is the moment of truth. The sandbox tried to reach
`~/precious/` and got "No such file or directory." Let's confirm
those files are still on the host, untouched.

**🖥 Host:**

```bash no-run-button
ls -la ~/precious/
cat ~/precious/forecast.txt
cat ~/precious/credentials.env
cat ~/precious/source.code
```

**Everything is intact.** Not because we're lucky. Not because the
agent was nice. Because the sandbox **could not see those files in
the first place** — they were never mounted in.

> **This is defense in depth.** Layer 1: the model refused the
> catastrophic prompt. Layer 2: even with raw shell access, the
> sandbox could not reach anything outside its workspace mount.
> You'd need both layers to fail simultaneously for your real
> systems to be at risk — and that's a risk profile leadership can
> sign off on.

---

## Step 12 — Clean up

Sandboxes are disposable by design — no traces left behind.

**🖥 Host:**

```bash no-run-button
sbx ls
```

Every running sandbox is visible, auditable, and terminable. For a
compliance team, that's the audit-trail story.

Stop the sandbox:

**🖥 Host:**

```bash no-run-button
sbx stop sbxlab
```

The microVM shuts down. State is preserved, so you can resume later
with `sbx run sbxlab`.

Remove the sandbox completely:

**🖥 Host:**

```bash no-run-button
sbx rm sbxlab
```

Everything inside the sandbox — installed packages, command
history, files created — is gone. Your **host** working directory
(`~/sbx-lab`) and `~/precious` are untouched.

Verify cleanup:

**🖥 Host:**

```bash no-run-button
sbx ls                       # sbxlab is gone
ls -la ~/precious/           # all three files still there
ls -la ~/sbx-lab/            # workspace files still there
```

**Disposable by default.** Every agent session is a clean slate;
every session leaves no residue on the host.

---

## What you just demonstrated

| Without sbx | With sbx + aligned model |
|---|---|
| Agent has host privileges | Agent has microVM only |
| Agent can see your whole home directory | Agent sees only the workspace you mount |
| One bad prompt = real damage | One bad prompt = agent refuses |
| Jailbreak = real damage | Jailbreak = path doesn't exist anyway |
| Raw shell access = real damage | Raw shell access = boundary holds |
| Secrets exposed by default | Secrets unreachable |
| Sessions persist on host | Sessions disposable (`sbx rm`) |
| No audit trail | Every action visible in `sbx ls` |
| Speed *or* safety | Speed *and* safety, in layers |

This is the foundation enterprises like BMW, Mercedes-Benz, Tesla,
and others have already standardized on for AI agent rollouts. You
don't bet the company on the model being right. You don't bet the
company on the sandbox being airtight. You make both layers wrong
simultaneously the only failure mode — and that's a risk profile
leadership can sign off on.

## Try this next

- Run an actual coding task — `sbx run sbxlab` against a real
  project inside `~/sbx-lab` and watch the agent iterate without
  touching your host
- Switch to **Locked Down** policy with `sbx policy` and add domain
  exceptions one by one — that's the audit-friendly posture for
  regulated environments
- Add a Docker MCP Toolkit server and watch the audit trail grow
- Mount additional read-only workspaces with
  `sbx run sbxlab . /path/to/docs:ro` — controlled visibility, not
  full home access

## Reference

- Docker Sandboxes docs: <https://docs.docker.com/ai/sandboxes/>
- sbx CLI reference: <https://docs.docker.com/reference/cli/sbx/>
- sbx releases: <https://github.com/docker/sbx-releases>

---

*Lab authored for the Docker AI Platform demo. Pairs with the
keynote "AI Agents, Engineered for Enterprise: Speed, Safety, and
Scale Without Compromise."*
MARKDOWN_EOF

ok "Wrote labspace/blast-radius-test.md ($(wc -l < labspace/blast-radius-test.md) lines)"

# ── Step 4: Write labspace.yaml using the discovered field name ─────────────
step "Writing labspace/labspace.yaml (using ${SCHEMA_PATH_FIELD}: field)"

# Backup existing
if [ -f "$YAML_FILE" ]; then
  cp "$YAML_FILE" "$YAML_FILE.bak.$(date +%s)"
  ok "Backed up existing labspace.yaml"
fi

cat > "$YAML_FILE" <<YAML_EOF
title: "Docker Sandboxes — The Blast Radius Test"
description: |
  A hands-on lab demonstrating defense-in-depth for AI agents using Docker
  sbx microVM sandboxes. You'll meet the sbx CLI, watch the OpenAI codex
  agent refuse a catastrophic command (Layer 1: model alignment), then
  drop into a raw shell inside the sandbox and watch it fail to reach
  your host filesystem (Layer 2: microVM containment). The single
  clearest demonstration of why containers alone aren't enough — and why
  model alignment alone isn't enough either. You need both.

sections:
  - title: "The Blast Radius Test"
    ${SCHEMA_PATH_FIELD}: blast-radius-test.md
    duration: 15
YAML_EOF

ok "Wrote labspace/labspace.yaml with ${SCHEMA_PATH_FIELD}: blast-radius-test.md"

# ── Step 5: Write helper script ─────────────────────────────────────────────
step "Writing project/setup-precious.sh"

mkdir -p project
cat > project/setup-precious.sh <<'HELPER_EOF'
#!/usr/bin/env bash
# Convenience helper for the Blast Radius Test lab.
# Sets up ~/precious/ on the host with three sample files representing
# credentials, IP, and business data. Re-runnable.
set -e

mkdir -p ~/precious
echo "Q4 forecast: confidential" > ~/precious/forecast.txt
echo "DB_PASSWORD=do-not-leak"   > ~/precious/credentials.env
echo "// proprietary algorithm"  > ~/precious/source.code

echo "Set up ~/precious/ with 3 sample files:"
ls -la ~/precious/
echo
echo "Full host path: $(cd ~/precious && pwd)"
echo
echo "Note this path. The sandbox will try to reach it in Step 9 — and fail."
HELPER_EOF
chmod +x project/setup-precious.sh
ok "Wrote project/setup-precious.sh (executable)"

# ── Step 6: Update README.md ────────────────────────────────────────────────
step "Updating README.md"

if [ -f README.md ]; then
  cp README.md "README.md.bak.$(date +%s)"
  ok "Backed up existing README.md"
fi

cat > README.md <<'README_EOF'
# Labspace: Blast Radius Test

A focused, single-lab labspace demonstrating defense-in-depth for AI
agents using Docker sbx microVM sandboxes.

> *"Speed without governance creates liability. Governance without speed
> creates drag."* — Deloitte, State of AI in the Enterprise 2026

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [ttyd](https://github.com/tsl0922/ttyd): `brew install ttyd`
- [sbx](https://github.com/docker/sbx-releases): `brew install docker/tap/sbx`

## Quick start

```bash
git clone https://github.com/ajeetraina/labspace-sbx-blastradius
cd labspace-sbx-blastradius
bash start-labspace.sh
```

Open <http://localhost:3030>

- **Left panel** → Lab instructions
- **Right panel** → Your Mac terminal with `sbx` ready to use

## What this lab proves

In ~15 minutes of hands-on work, you'll demonstrate that AI agents can be
given full autonomy without putting your host machine at risk.

- **Layer 1 — Model alignment.** Ask the OpenAI codex agent inside the
  sandbox to run `rm -rf /`. It refuses.
- **Layer 2 — microVM containment.** Drop into a raw bash shell inside
  the sandbox (no model in the loop) and try to reach `~/precious/` on
  your host using its absolute path. The path literally does not exist
  inside the VM.
- **Disposable by default.** `sbx rm sbxlab` and the sandbox is gone —
  no residue on the host.

## Companion presentation

This lab pairs with the keynote *"AI Agents, Engineered for Enterprise:
Speed, Safety, and Scale Without Compromise."* The lab is the live demo
in that presentation — Act 2 (codex refuses) and Act 3 (microVM
contains).

## License

Apache 2.0
README_EOF

ok "Updated README.md"

# ── Step 7: Show what's now in the labspace/ directory ──────────────────────
step "Final state of labspace/"

ls -la labspace/ | grep -v "^total" | sed 's/^/  /'

# ── Step 8: Final summary and next steps ────────────────────────────────────
step "Done"

cat <<EOF

  ${GREEN}${BOLD}Labspace ready.${RESET}

  ${BOLD}What's now in the repo:${RESET}
    • labspace/blast-radius-test.md     (the lab — 12 steps, 4 acts)
    • labspace/labspace.yaml            (single-section, using '${SCHEMA_PATH_FIELD}:' field)
    • labspace/_archive/                (old section files, deletable)
    • project/setup-precious.sh         (helper for host setup)
    • README.md                         (updated for this lab)

  ${BOLD}Preserved (untouched):${RESET}
    • start-labspace.sh                 (boot script)
    • compose.yaml, compose.override.yaml
    • disable-run.sh, blast-radius.sh
    • .devcontainer/, .github/, .claude/

  ${BOLD}Next steps:${RESET}

  ${BOLD}1. Boot the labspace:${RESET}

       bash start-labspace.sh

       ${DIM}# Then open${RESET}
       open http://localhost:3030

  ${BOLD}2. Verify the lab renders correctly:${RESET}
     • Left pane shows "The Blast Radius Test" as the only section
     • Right pane shows your Mac terminal (ttyd)
     • Click through every step end-to-end

     ${DIM}If left pane shows 'No sections found':${RESET}
       → The schema field detection may have been wrong.
       → Check labspace/labspace.yaml.bak.* for the original format.
       → Edit labspace/labspace.yaml to match.

  ${BOLD}3. Stage ~/precious/ before going on stage:${RESET}

       bash project/setup-precious.sh

  ${BOLD}4. When ready, commit and push:${RESET}

       git add labspace/ project/ README.md
       git commit -m "Replace multi-lab content with single Blast Radius lab"
       git push

  ${BOLD}Backup files created (for safety):${RESET}
    Look for ${DIM}*.bak.<timestamp>${RESET} files. Delete when satisfied with the result.

EOF
