<!--
  AI Governance setup bar
  =======================
  Top-of-chapter widget with two parts:
  1. A "Set Docker Hub Org" form that remembers the org slug in localStorage.
  2. Three quick-jump links into the Admin Console's AI governance subpages.

  Important: the links are LIVE by default. Even before an org is set
  (or if the labspace renderer doesn't execute the inline <script>), the
  three links point at https://app.docker.com/admin — which resolves to
  whichever org the user has selected in the Admin Console. The JS only
  *upgrades* them to org-specific deep-links when a slug is set.
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
  .gov-bar__label { font-weight: 600; color: #1f2328; margin-right: 4px; }
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
  .gov-bar__links { display: flex; flex-wrap: wrap; gap: 14px; }
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
  .gov-bar__links a.is-deep-link {
    background: #eaf2ff;
    border-color: #b6daff;
  }
  .gov-bar__links a.needs-org {
    color: #8c959f;
    background: #f0f1f2;
    border-color: #e6e8eb;
    cursor: not-allowed;
  }
  .gov-bar__status { color: #57606a; font-size: 13px; }
  .gov-bar__status.error { color: #cf222e; }
  .gov-bar__status.ok    { color: #1a7f37; }
</style>

<div class="gov-bar" id="gov-bar">
  <div class="gov-bar__row" id="gov-bar-input-row">
    <span class="gov-bar__label">🏢 Docker Hub Org:</span>
    <input type="text" id="gov-bar-input" placeholder="e.g. dockerdevrel" autocomplete="off" spellcheck="false" />
    <button id="gov-bar-set">Set org</button>
    <span class="gov-bar__status" id="gov-bar-status"></span>
  </div>
  <div class="gov-bar__row" id="gov-bar-summary-row" style="display:none;">
    <span class="gov-bar__label">🏢 Org:</span>
    <strong id="gov-bar-current"></strong>
    <button class="gov-bar__change" id="gov-bar-change">change</button>
  </div>
  <div class="gov-bar__row gov-bar__links">
    <a id="gov-link-manage"     href="https://app.docker.com/admin" target="_blank" rel="noopener" class="needs-org">⚙️  Manage AI governance</a>
    <a id="gov-link-network"    href="https://app.docker.com/admin" target="_blank" rel="noopener" class="needs-org">🛜 Network access</a>
    <a id="gov-link-filesystem" href="https://app.docker.com/admin" target="_blank" rel="noopener" class="needs-org">📂 Filesystem access</a>
  </div>
</div>

<script>
(function () {
  var STORAGE_KEY = 'labspace.sbx.governance.org';
  var SLUG_RE = /^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/;

  function $(id) { return document.getElementById(id); }
  var input      = $('gov-bar-input');
  var setBtn     = $('gov-bar-set');
  var changeBtn  = $('gov-bar-change');
  var status     = $('gov-bar-status');
  var inputRow   = $('gov-bar-input-row');
  var summaryRow = $('gov-bar-summary-row');
  var current    = $('gov-bar-current');
  var links = {
    manage:     $('gov-link-manage'),
    network:    $('gov-link-network'),
    filesystem: $('gov-link-filesystem')
  };
  if (!input || !setBtn) return;

  // The Admin Console deep-link pattern:
  //   https://app.docker.com/accounts/<org>/admin/ai-governance/<sub>
  // where <sub> is one of: manage, network-access, filesystem-access.
  function urlFor(org, sub) {
    return 'https://app.docker.com/accounts/' + encodeURIComponent(org) + '/admin/ai-governance/' + sub;
  }

  function activate(org) {
    inputRow.style.display = 'none';
    summaryRow.style.display = 'flex';
    current.textContent = org;
    links.manage.href     = urlFor(org, 'manage');
    links.network.href    = urlFor(org, 'network-access');
    links.filesystem.href = urlFor(org, 'filesystem-access');
    Object.keys(links).forEach(function (k) {
      links[k].classList.add('is-deep-link');
      links[k].classList.remove('needs-org');
    });
  }

  function deactivate() {
    inputRow.style.display = 'flex';
    summaryRow.style.display = 'none';
    status.className = 'gov-bar__status';
    status.textContent = '';
    Object.keys(links).forEach(function (k) {
      links[k].href = 'https://app.docker.com/admin';
      links[k].classList.remove('is-deep-link');
      links[k].classList.add('needs-org');
    });
  }

  // Block clicks on the deep-link buttons while no org is set, and nudge
  // the user back to the input. Without this, the buttons would all
  // bounce to /admin and look like the chapter is broken.
  function guardClick(a) {
    a.addEventListener('click', function (e) {
      if (a.classList.contains('needs-org')) {
        e.preventDefault();
        status.className = 'gov-bar__status error';
        status.textContent = 'Set your Docker Hub org slug first \u2014 then the buttons will deep-link into the right page.';
        input.focus();
      }
    });
  }
  Object.keys(links).forEach(function (k) { guardClick(links[k]); });

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
    try { localStorage.setItem(STORAGE_KEY, org); } catch (e) {}
    activate(org);
  }

  setBtn.addEventListener('click', commit);
  input.addEventListener('keydown', function (e) { if (e.key === 'Enter') commit(); });
  if (changeBtn) {
    changeBtn.addEventListener('click', function () {
      try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
      input.value = '';
      deactivate();
      input.focus();
    });
  }

  var saved = null;
  try { saved = localStorage.getItem(STORAGE_KEY); } catch (e) {}
  if (saved && SLUG_RE.test(saved)) {
    input.value = saved;
    activate(saved);
  } else {
    deactivate();
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

> **Before you start — set your Docker Hub Org**
>
> The three buttons at the top of this chapter (⚙️ Manage AI
> governance, 🛜 Network access, 📂 Filesystem access) deep-link
> straight into your org's pages — but only once you've told them
> which org. Type your slug into the **Docker Hub Org** input and
> click **Set org**. The slug is saved in your browser so you only
> set it once. Until then the buttons are inert; clicking one
> nudges you back to the input.

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

🌐 **Admin Console** → click **⚙️ Manage AI governance** (top bar):

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

🌐 **Admin Console** → click **🛜 Network access** (top bar)
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

🌐 **Admin Console** → click **🛜 Network access** (top bar) →
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

🌐 **Admin Console** → click **📂 Filesystem access** (top bar) →
add these rules:

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
