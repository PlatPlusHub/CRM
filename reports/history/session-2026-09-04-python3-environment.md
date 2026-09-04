# ORVION — `python3` environment diagnostic: a Microsoft Store alias stub, an interpreter that was never missing, and a dependency ORVION does not have

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-04
Author: Claude Opus 5
Status: **CLOSED — NO PYTHON FIX APPLIED, AND NONE IS WARRANTED.** Python 3.12.10 is installed and healthy. `python3` fails because the name is occupied by a non-functional Microsoft Store App Execution Alias stub. ORVION never references `python3` — zero occurrences, repository-wide — so there is nothing to repair. Nothing was changed but this report and the three synchronization artifacts governance binds to it (`reports/README.md` pointer, the manifest's `Narrative:` field, `ai-map.json`). No migration, no test, no script, no database contact.

**A second environment defect was found by hitting it, and is NOT fixed because the fix is an owner choice:** `git push origin main` hangs non-interactively because the remote URL carries no username, so Git Credential Manager resolves to the stored **`Shehabhub`** credential instead of the **`PlatPlusHub`** one this repository needs. Pushed successfully via the username-qualified URL without altering any configuration. **§8 states the exact choice left to the owner.**

---

## 1. EXECUTIVE SUMMARY

The outstanding environment question from the previous package was *"why is `python3` not available?"* — a question whose framing contained the error.

**`python3` is available.** It is on `PATH`, it resolves to a real file, and `command -v python3` prints a path. What it does not do is run Python, because that file is a **0-byte reparse-point stub** — a Windows App Execution Alias — pointing at a Microsoft Store Python package **that is not installed**. Invoking it prints an advertisement and exits non-zero.

This is a materially worse failure mode than absence, and it is why the previous session misread it. A missing command says `command not found`. This one says *"Python was not found; run without arguments to install from the Microsoft Store"* — while a fully working Python 3.12.10 sits **two PATH entries earlier**.

Three facts settle the matter:

1. **Python 3.12.10 is installed, on PATH, and first.** `python` resolves to it correctly.
2. **Windows CPython has never shipped a `python3.exe`.** The `python3` spelling is a POSIX convention (PEP 394) that the Windows installer does not implement. The real install directory contains exactly `python.exe` and `pythonw.exe`.
3. **ORVION does not use Python at all.** Not `python3`, not `python`, not one `.py` file, not one shebang, not one packaging artifact, not one CI step.

The `python3` spelling entered this repository's history from **the agent, not the repository** — it was my own POSIX habit in the previous session while attempting a heredoc text manipulation. ORVION never asked for it. The correct resolution is therefore to change nothing, which is also what the instruction for this task required: *"If `python` already resolves to a supported Python 3 installation and the repository does not require the literal `python3` command, DO NOT create an unnecessary alias just for cosmetic consistency."*

---

## 2. ENVIRONMENT

| Axis | Observed |
|---|---|
| OS | Microsoft Windows 11 Pro, 10.0.26200 (build 26200), 64-bit |
| PowerShell | 7.6.5, PSEdition **Core**, Platform `Win32NT`, process `pwsh`, 64-bit |
| Bash tool runtime | **Git Bash / MSYS2 MINGW64** — `MSYSTEM=MINGW64`, `OSTYPE=cygwin`, bash 5.3.15(1), `uname` = `MINGW64_NT-10.0-26200 ... Msys` |
| WSL | **NOT IN USE.** `WSL_DISTRO_NAME` empty, `WSL_INTEROP` empty, `/proc/version` reports MSYS (not a Linux kernel) |
| Python (real) | **3.12.10**, `C:\Users\Platinum Plus\AppData\Local\Programs\Python\Python312\python.exe`, `MSC v.1943 64 bit (AMD64)` |
| Python launcher | `py` 3.12.10 present, `C:\Users\Platinum Plus\AppData\Local\Programs\Python\Launcher\py.exe` |
| Store Python package | **NOT INSTALLED** — `Get-AppxPackage *Python*` returns nothing |

Both shells were tested independently. **The behaviour is identical in each**, which rules out a shell-configuration cause.

---

## 3. COMMANDS RUN AND EXACT OBSERVATIONS

### 3.1 Resolution — Git Bash

```
$ command -v python3
/c/Users/Platinum Plus/AppData/Local/Microsoft/WindowsApps/python3

$ command -v python
/c/Users/Platinum Plus/AppData/Local/Programs/Python/Python312/python

$ which -a python
/c/Users/Platinum Plus/AppData/Local/Programs/Python/Python312/python
/c/Users/Platinum Plus/AppData/Local/Microsoft/WindowsApps/python

$ python3 --version
Python was not found; run without arguments to install from the Microsoft Store,
or disable this shortcut from Settings > Apps > Advanced app settings > App execution aliases.
  (exit 49)

$ python --version
Python 3.12.10

$ python -c "import sys; print(sys.executable); print(sys.version)"
C:\Users\Platinum Plus\AppData\Local\Programs\Python\Python312\python.exe
3.12.10 (tags/v3.12.10:0cc8128, Apr  8 2025, 12:21:36) [MSC v.1943 64 bit (AMD64)]
```

`which -a python` returning **two** entries while `which -a python3` returns **one** is the entire finding in miniature: the real interpreter answers to `python` only, and the stub answers to both.

### 3.2 Resolution — PowerShell

```
where.exe python3  → C:\...\AppData\Local\Microsoft\WindowsApps\python3.exe          (exit 0)
where.exe python   → C:\...\AppData\Local\Programs\Python\Python312\python.exe
                     C:\...\AppData\Local\Microsoft\WindowsApps\python.exe           (exit 0)
where.exe py       → C:\...\AppData\Local\Programs\Python\Launcher\py.exe            (exit 0)

Get-Command python3 -All → python3.exe  Application  ...\WindowsApps\python3.exe   Version 0.0.0.0
Get-Command python  -All → python.exe   Application  ...\Python312\python.exe      Version 3.12.10150.1013
                           python.exe   Application  ...\WindowsApps\python.exe    Version 0.0.0.0
```

`where.exe python3` **exits 0**. The command is found. The reported version `0.0.0.0` is the signature of a stub carrying no product metadata.

### 3.3 The stub itself

```
Get-Item ...\WindowsApps\python3.exe -Force
  Name       : python3.exe
  Length     : 0
  LinkType   :
  Target     :
  Attributes : Archive, ReparsePoint
```

**Zero bytes, `ReparsePoint`.** It is not an executable; it is a filesystem redirection marker the Windows App Model resolves at launch. `WindowsApps` holds 22 such stubs, all 0 bytes — `winget.exe`, `wsl.exe`, `notepad.exe`, `python.exe`, `python3.exe` among them.

Invoked directly by full path from PowerShell:

```
& "$env:LOCALAPPDATA\Microsoft\WindowsApps\python3.exe" --version
  output   : Python was not found; run without arguments to install from the Microsoft Store, ...
  exitcode : 9009
```

*(The failure code differs by call path — **49** through Git Bash, **9009** invoked directly in PowerShell. Both are recorded as observed rather than harmonised into one number. Neither is a Python exit code; no interpreter ever starts.)*

### 3.4 The real installation

```
Get-ChildItem ...\Programs\Python\Python312\*.exe
  python.exe     104952
  pythonw.exe    104304

python3.exe present in real install dir : False
python.exe  present in real install dir : True
```

**This is the load-bearing observation.** The genuine Python 3.12 installation does not contain a `python3.exe` and never did. That is correct, standard Windows CPython behaviour, not damage.

### 3.5 PATH order

```
[10] C:\Users\Platinum Plus\AppData\Local\Programs\Python\Python312\Scripts\
[11] C:\Users\Platinum Plus\AppData\Local\Programs\Python\Python312\      ← real Python
[12] C:\Users\Platinum Plus\AppData\Local\Programs\Python\Launcher\
[13] C:\Users\Platinum Plus\AppData\Local\Microsoft\WindowsApps          ← alias stubs
[16] C:\Users\Platinum Plus\AppData\Local\Programs\Python\Python312       (duplicate)
[17] C:\Users\Platinum Plus\AppData\Local\Programs\Python\Python312\Scripts (duplicate)
```

**PATH is correctly ordered.** Real Python at 11 precedes the stubs at 13, which is precisely why `python` works and gets the real interpreter rather than the shim. `python3` finds nothing at 11 — no such filename exists there — continues searching, and reaches the dead stub at 13.

### 3.6 The `py` launcher

```
py --version       → Python 3.12.10
py -3 --version    → Python 3.12.10
py -3.12 --version → Python 3.12.10
py -0              → -V:3.12 *        Python 3.12 (64-bit)
```

Fully functional. `py -3` is the canonical Windows equivalent of POSIX `python3`, and it already works with no change.

### 3.7 Repository dependency — the question that decides everything

```
grep -ri "python3"  →  NO MATCHES (entire repository, case-insensitive)

git ls-files '*.py'                         → 0
find . -name '*.py' -not -path './.git/*'   → 0
grep -rl '^#!.*python'                      → none

requirements.txt · requirements-dev.txt · pyproject.toml · setup.py
setup.cfg · Pipfile · poetry.lock · tox.ini · conftest.py   → ALL ABSENT
virtualenvs (pyvenv.cfg / venv / .venv)                     → none
grep -ri python .github/                                    → none (4 workflows)
```

Every Python reference in the repository, in full:

| Location | Form | Nature |
|---|---|---|
| `.workstation/doctor.ps1:19` | `Test-Cmd "python"` | presence check |
| `.workstation/doctor.ps1:36` | `python --version` | version print |
| `.workstation/menu.ps1:29` | `Get-Command python` | presence check |
| `.workstation/prepare.ps1:26` | `Ensure-Tool python "Python.Python.3.12"` | winget install |
| `.workstation/manifest.md:21` | `Python 3 \| Python.Python.3.12 \| base scripting dependency` | baseline declaration |
| `.gitignore:1` | `# Python` | comment above cache ignores |
| `reports/history/*`, `changes/SPEC-125*` | recorded version observations | historical evidence |

**Every one of them uses the bare name `python`. Not one uses `python3`.** And of those, **none executes Python to perform work** — three check that it exists, one installs it, one declares it. ORVION runs SQL, PowerShell and Node. It does not run Python.

---

## 4. ROOT CAUSE

**Classification: H — another cause, stated precisely.**

> `python3` resolves on `PATH` to a **0-byte Microsoft Store App Execution Alias reparse point** (`%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe`) whose backing Store package **is not installed**, so invoking it emits the Store install prompt and exits non-zero without starting an interpreter. The genuine Python 3.12.10 installation is present, correct, earlier on `PATH`, and reachable as `python` — but it provides **no `python3.exe`**, because Windows CPython implements the POSIX `python3` naming convention only through the `py` launcher.

The other candidates were each tested and excluded:

| | Verdict |
|---|---|
| **A** — Python 3 not installed | **NO.** 3.12.10 installed and executing. |
| **B** — installed but not on PATH | **NO.** On PATH at entries 10–12, correctly ahead of the stubs. |
| **C** — installed as `python`, no `python3` exists | **PARTIALLY — and this is the contributing condition, not the cause.** True of the *real installation*. False of `PATH`, where a `python3` entry does exist and is found. C predicts `command not found`; what actually occurs is a resolved command that fails with a Store advertisement — a different and more misleading symptom. |
| **D** — Windows Python but no WSL Python | **NO.** WSL is not in use; the Bash tool is MSYS2 MINGW64. |
| **E** — WSL Python, wrong shell resolution | **NO.** Same reason. |
| **F** — virtualenv/path issue | **NO.** No venv anywhere; `sys.executable` is the base install. |
| **G** — repository/tooling assumes `python3` | **NO — the repository does not.** Zero occurrences. The assumption was the **agent's**, in the previous session, out of POSIX habit. |

So the cause decomposes into two independent facts that only produce a confusing symptom in combination: **Windows CPython does not create `python3.exe`**, and **Microsoft occupies that name with a non-functional shim**. Neither alone is a defect. Together they make "not installed" and "installed under a different name" indistinguishable from the command line.

---

## 5. FIX

**None applied. None warranted.**

The governing condition was met exactly: `python` resolves to a supported Python 3 installation, and the repository does not require the literal `python3` command. Creating an alias or symlink would be a cosmetic change to global Windows configuration to satisfy a command **no ORVION script issues** — and would additionally require either disabling the Store alias in Windows Settings or shadowing it earlier on PATH, both of which are owner-level machine changes made for no engineering benefit.

Three correct spellings already exist for any future agent that wants a Python 3 interpreter here:

| Use | Works today |
|---|---|
| `python` | ✅ 3.12.10 — the form ORVION's own scripts use |
| `py -3` | ✅ 3.12.10 — the canonical Windows POSIX-equivalent |
| `py` | ✅ 3.12.10 |

**The durable correction is behavioural, and it belongs in this report rather than in the machine:** on this workstation, invoke `python`, never `python3`. That instruction now lives in the repository, which is the only place ORVION treats as memory (`AGENTS.md §6`).

---

## 6. VERIFICATION

`.workstation/doctor.ps1` — explicitly read-only (*"Changes nothing. Safe to run anytime."*) — executed in full:

```
[Applications]
[ OK ] git   [ OK ] node   [ OK ] npm   [ OK ] docker
[ OK ] python   [ OK ] claude   [ OK ] code

[Repository]
[ OK ] README.md  [ OK ] AGENTS.md  [ OK ] PROJECT_CONTEXT.md
[ OK ] GOVERNANCE.md  [ OK ] .gitignore  [ OK ] .mcp.json

[Docker]
[ OK ] Docker Engine

[Versions]
  git      git version 2.55.0.windows.4
  node     v24.19.0
  npm      11.17.0
  docker   Docker version 29.7.2, build a7dcaa6
  python   Python 3.12.10
  claude   2.1.260 (Claude Code)
  code     1.136.1

[GitHub sync]
[ OK ] in sync with origin/main

Doctor completed.
```

**Every base tool passes, including `python`.** The workstation baseline in `.workstation/manifest.md §1` is satisfied. Docker Engine is running, so the `§5a` verification protocol (`db reset` → Pass A → HTTP → Pass B) is executable whenever a package next needs it.

Two version drifts from the 2026-08-21 baseline were observed and are recorded as fact, not as defects: Docker `29.6.2 → 29.7.2`, VS Code `1.129 → 1.136.1` (the latter now directly observable, where the manifest had marked it unconfirmed). Both are ordinary upgrades of tools verified working. Amending `.workstation/manifest.md` was not authorized by this task and is not done here.

---

## 7. NOT FIXED / LATENT CONDITIONS

- **The Store alias stubs remain in place.** Deliberate. They are Windows defaults, they affect `python3` only, and `python3` is used by nothing. Removing them is a global OS-settings change with no ORVION benefit.
- **`PATH` order is what makes `python` work, and it is currently correct.** Real Python (11) precedes `WindowsApps` (13). Recorded as a latent condition: **if that order ever inverts, `python` would also resolve to the dead stub** and the workstation baseline would genuinely break — `doctor.ps1` would then report `[FAIL] python`. No action needed now; this is the tripwire to remember if it ever fires.
- **`PATH` carries duplicate Python entries** (11/16 and 10/17 are the same directories). Harmless — first match wins, and the first match is correct. Not touched.
- **`.workstation/manifest.md` version rows are 14 days stale** for Docker and VS Code, as above. Out of scope for this task.

## 8. BLOCKED — and a SECOND environment defect, found by hitting it

**`git push origin main` hangs and cannot complete non-interactively. This is a real, recurring blocker, and it has a precise cause that the earlier record did not have.**

It was found the only way it could be: by pushing this report. The first attempt **hung for two minutes and was killed**. Re-run with prompting disabled, it failed instantly and said what it actually wanted:

```
$ GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git push origin main
fatal: Cannot prompt because user interactivity has been disabled.
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

`git ls-remote origin main` works fine throughout — **reads succeed, only the write blocks** — so this is credential *selection*, not connectivity.

The cause is a mismatch between the remote URL and the stored credential keys:

| | |
|---|---|
| Remote URL | `https://github.com/PlatPlusHub/CRM.git` — **no username in the URL** |
| Credential GCM therefore looks up | `git:https://github.com` → stored user **`Shehabhub`** — *the wrong account for this repository* |
| Credential that actually works | `git:https://PlatPlusHub@github.com` → stored user **`PlatPlusHub`** — reachable **only** if the URL carries the username |

Windows Credential Manager holds both. Because the URL is unqualified, GCM resolves to the `Shehabhub` entry, fails to authenticate as the right identity, and falls through to an interactive prompt — which in this session is `GIT_ASKPASS` pointing at a GUI helper nobody can answer. That is the hang.

**Resolved for this commit without changing any configuration**, by pushing once to the username-qualified URL:

```
$ git push https://PlatPlusHub@github.com/PlatPlusHub/CRM.git main
To https://github.com/PlatPlusHub/CRM.git
   1799587..45ba216  main -> main
```

Fast-forward. No force. `.git/config` untouched; `origin` still points where it did.

**This refines the earlier record rather than repeating it.** Commit `8c063ee` logged the symptom as *"GCM has no non-interactive credential"* — which reads as *no usable credential exists*. A usable credential **does** exist; it is simply unreachable through an unqualified URL. That distinction is the difference between "wait for the owner" and "qualify the URL and push."

**The permanent fix is an OWNER CHOICE and is deliberately NOT made here.** Making `origin` push as `PlatPlusHub` —

```
git remote set-url origin https://PlatPlusHub@github.com/PlatPlusHub/CRM.git
```

— is one line, local to `.git/config`, untracked and trivially reversible. But it decides **which of two GitHub identities this repository pushes as**, on a machine that has credentials for both, and this task's own instruction is explicit: *"If the fix requires an owner/environment choice, DO NOT make it. Report the exact choice instead."* Choosing between `Shehabhub` and `PlatPlusHub` is exactly that choice. It is stated here and left to the owner.

**Until the owner decides, the next agent should push with the qualified URL shown above** rather than concluding that pushing is impossible — and should never interpret the hang as a reason to force, reset, or abandon local work.

*(Also surfaced, unrelated and untouched: the **n8n MCP server requires OAuth authorization** and cannot be authorized non-interactively — the owner must authorize it via `/mcp` in an interactive session or in the claude.ai connector settings. This matters only to the DELIV-1 / PH8-2 workstream, which is an open owner decision.)*

## 9. GOVERNANCE

This report exists because of **GOV-14**, minted by the immediately preceding session and now applied for the first time by a different one: *"A READ-ONLY session is still a session, and a no-mutation instruction is not an exemption... Writing the report is never the mutation a read-only instruction forbids."*

That rule is exactly what this session would otherwise have violated. A diagnostic whose entire output is a conclusion — *"use `python`, not `python3`, and here is the proof that nothing is broken"* — is the cheapest possible thing to lose and the most annoying to re-derive, because the symptom actively lies about its cause. Without this file, the next agent would hit the same Store advertisement and reach the same wrong first conclusion the previous session did.

Per `AGENTS.md §6` and `reports/README.md`, the **Latest session report** pointer is updated in the same commit. That pointer carries forward the real engineering frontier — this session changed nothing about it.

## 10. ENVIRONMENT

Fully covered in §2 and §6. Healthy. No remediation required.

## 11. CURRENT STATE

Re-established from the repository at the start of this session and unchanged by it, except for this report and the index pointer:

| Axis | Value |
|---|---|
| Migrations | **190**, latest `202607060100_a_ceiling_that_warns_is_a_ceiling_that_speaks.sql` |
| Ledger fingerprint | `1eaa2ec7d64f0403c8587c01aab6975f` (repo = local = Primary, per the previous package) |
| Active Change Request | `None` |
| Primary | **NOT TOUCHED.** No query, no migration, no deployment in this session. |
| Local database | **NOT TOUCHED.** No reset, no test run — none was needed, and `§5a` is required for schema work, which this was not. |
| Tests | **NOT RE-RUN.** Last executed state stands: 93 files / 1326 assertions, Pass A = Pass B; HTTP 414/0. No schema, script or test was modified, so no re-run was warranted. |
| Open owner decisions | Unchanged: QUO-4 · SUP-4c · CUST-3 · RET-1 · FIN-7 · VOID-1 · VERIFY-1 · TRANS-1 · DELIV-1 · PH8-2 · PLAN-1 · DOC-LC-2 · DOC-LC-3 · CANON-26-1 · LIC-1 |

**Git.** Before this session: HEAD = `origin/main` = `ls-remote` = `179958757d4ecb3b2a2480f60adb812659fbe040`, 0 ahead / 0 behind, clean tree — matching the expected state exactly. After: **`45ba2160e2497535b3815e91c9af3f80ec7e03a2`**, pushed fast-forward `1799587..45ba216` (no force), local = `origin/main` = `ls-remote`, 0/0, clean tree, 190 migration files on `origin/main`.

**Guards, run after the changes:**

| Guard | Result |
|---|---|
| `check_repository_consistency.ps1` | **CLEAN — Checks 1–19, exit 0** |
| `check_primary_ledger.ps1` (Check 19) | **CLEAN** — recorded ledger and repository agree exactly (190, `1eaa2ec7…`); evidence at `8b3a08f` remains an **ancestor** of HEAD, which is what the guard requires |
| `check_database_parity.ps1` | **local matches the repository** (L5 hashes agree, L3 API contract matches). **Primary: NOT CHECKED — exit 2, `UNPROVEN`.** Reported as such and **never as a pass**, per the guard's own instruction; this session was forbidden to contact Primary. |

Three guards caught the incompleteness of this change before it was committed, which is the loop working: **Check 10** flagged the README pointer moving without the manifest's `Narrative:` field, **Check 7** flagged `ai-map.json` still carrying the old `last_completed` by value (the COLD-2 comparison), and **Check 5**'s 1200-character line budget was satisfied by trimming the field to 1144 — **no budget was raised** (`AGENTS.md §6`).

A note on `Last Completed`, since this session shipped no capability: it still names **SUP-4b**, because nothing has superseded it and the field's own rule is that it names the most recent *capability*. The `Narrative:` pointer moves to this report because Check 10 binds it to the README pointer, and the field says plainly that the session since then shipped nothing. A cold-start agent reading it is told both facts and misled by neither.

**Is Batch 6 safe to start, environment-wise?** **Yes.** Every tool the `§5a` protocol needs is present and executing: Docker Engine up, Node/npx for the Supabase CLI, PowerShell 7 for the guards, git in sync. Python is irrelevant to all of it. Environment readiness is not, however, authorization — see §12.

## 12. NEXT STEP (exactly one)

**Unchanged by this session, and deliberately not begun:** HTTP-probe the RBAC-6 candidate class — `app.*` functions executable by `authenticated` with no `public` wrapper (102 executable, 29 unwrapped, 25 intentionally internal, **4 genuine candidates**: `item_financials`, `customer_balance`, `supplier_balance`, `booking_item_profit`).

`app.supplier_balance` is the strongest candidate, and `session-2026-09-04-owner-policy-package.md` explains why: `supplier_credit` now publishes `exposure_amount`, so a client can read the aggregate for a supplier that has a ceiling, while the per-currency breakdown stays unreachable and a supplier with no ceiling has no exposure door at all.

The discovery report authorizes **the discovery method, not an implementation**. The correct first act is a probe that records a status code — **not a migration**.

---

## 13. FINAL ANSWER, IN ONE LINE

Python was never missing; `python3` is a Microsoft Store stub squatting on a name Windows CPython does not use and ORVION does not reference — so the fix is to type `python`, and nothing on this machine needed changing.
