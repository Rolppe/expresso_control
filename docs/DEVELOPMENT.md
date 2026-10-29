# Development notes

How this app was developed, and a guide to the internal working files that are kept in the repository. Those files are in Finnish and were not written for publication; they are left in as a record of the process.

## How development worked

Mikko Paaso set the goal (the existing Android app for the Silvia controller, ported to an iPhone, then extended with Wi-Fi) and made the decisions. Claude Code agents in two roles did the rest:

- **Planner** (a stronger model in an interactive session, recorded in `paketit/delegation.jsonl` as Opus 5.5 for the first two packets and Fable 5.1 for the last two). It reads the registers, measures the environment, and writes a brief plus, for scripts, a spec.
- **Executor** (a Sonnet subagent, `model: sonnet` in all four logged packets). It runs the brief's steps and reports in a fixed format: files changed, acceptance result, budget verdict, iterations, whether it stopped, and at most one question.

A brief in `paketit/` has the same sections each time: Task, Files (which paths it may touch, which it must not), Do, Acceptance (shell commands whose exit codes decide), Budget (for example a line-count limit with `wc -l`), Stop (conditions under which the agent must stop and ask rather than improvise), Report. Some briefs also have:

- a `.spec.md`, the detailed behaviour of a script;
- `.correction-N.md` files. When a run failed, the planner measured why, wrote down whether the gap was in the spec or in the executor, and issued a correction. Example: an install failing with a transient device error led to "retry up to 3 times, 15 s apart" in `EXPRESSO-IOS-ASENNUS-AGENTTI.correction-1.md`; a diagnosis that the Apple ID was signed out was disproved by measurement (the Mac screen was locked) and led to a lock check in `EXPRESSO-IOS-ASENNUS-AJASTUS.correction-1.md`.

Acceptance gates were commands, not opinions: `flutter analyze` compared with a backup, `flutter test`, a simulator build, a release build, install on the phone, string checks on the built binary, and runs of the XCUITest driver with screenshots. Anything needing the user (a flash of the Pico, locking the phone) was planned as a separate step with the user present.

The delegation log has 4 packets (the wider work, such as the Wi-Fi link in `WIFI-APPI-AEPPI.md`, is described in a brief that has no log line). `delegation.jsonl` records model, turns, wall time in ms, iterations, corrections and a free-text note. Cost fields are null.

## Map of the internal files

| File | What it is |
|---|---|
| `REKISTERI.md` | Register: the current state of the work. Purpose and limits, environment measured on the build Mac, recorded decisions with who made them, open issues table, faults. Last updated 7 Oct 2026. |
| `HISTORIA.md` | Change history, newest first: what was done each session, with the commands run and the evidence (logs, screenshots, commit ids). Covers 5-7 Oct 2026. |
| `ARKISTO.md` | Archive of closed work: text removed or replaced in the register, kept verbatim and never edited. Read it only to find out what the register used to say. |
| `paketit/*.brief.md` | Work packets for executors: `ALUSTA` (create the iOS project), `NAYTTO` (keep-screen-on setting), `ASENNUS-AGENTTI` (install script and launch agent), `ASENNUS-AJASTUS` (scheduled renewal). |
| `paketit/*.spec.md`, `*.correction-N.md` | Script specification and post-failure corrections for the install packets. |
| `paketit/WIFI-APPI-AEPPI.md` | Brief for the app side of the Wi-Fi link (MachineLink, WifiRepository, LinkSelector, key store, settings, tests). |
| `paketit/delegation.jsonl` | One JSON object per packet: model, turns, time, iterations, corrections, note. |
| `app-lahde-20261028.patch` | See below. |
| `uitest/askeleet/*.txt` | Step files for the XCUITest driver, each with a comment on what it verifies. |

The registers were written in a harness with its own conventions (scopes, `/pura` and `/pakkaa` to unpack and pack a conversation, `SEURAAVA PAKETTI` as the pointer to the next packet). They mention paths and machines of the author's private setup. Dates run from 5 Oct 2026 (project start) to 7 Oct in the registers; the Wi-Fi brief is dated 20 Oct and the patch 28 Oct.

## The patch: `app-lahde-20261028.patch`

It is a recursive `diff -ruN` of two trees: the mirror of the app that was built and installed on the phone (lines starting with `-`) against the author's working copy of the app source (lines starting with `+`), taken on 28 Oct 2026. The `lib/` and `test/` in this repository correspond to the installed side. The patch therefore holds newer UI changes from 25-26 Oct that were not yet installed. By file headers these are:

- `machine_data_notifier.dart`, `machine_status.dart` (+ regenerated freezed/json files): a `flowData` series.
- `graph_widget.dart`: draws that flow series on the chart.
- `controls_widget.dart` and `settings_view.dart`: the standby settings (start delay, post-shot delay, temperature) move from Settings to the controls panel.
- `landscape_layout.dart`, `tare_button.dart`, `value_display.dart`: layout and widget changes.
- `test/ui_uudistukset_test.dart`: a new widget test file (about 338 lines) for these changes.

The patch also carries noise: IDE files under `.idea/` and `.flutter-plugins-dependencies`, which are not part of the app. The file headers use the author's absolute paths (shortened with `~`), so it cannot be applied with `patch -p1` as it stands; extract the hunks for `lib/` and `test/` (for example with `filterdiff`) and rewrite the paths. This was not tried, and the patch was not run through `flutter analyze` or the tests.

## Glossary

| Finnish | English | Where it appears |
|---|---|---|
| uutto | extraction, a shot of espresso | `brew_log_notifier.dart` notification text, step files |
| uuttoloki, keittoloki | shot log (`brew_log` objects, `brew_shots.jsonl`) | `lib/features/brew_log/`, `luo-uutto.txt` |
| tyytyväisyys | satisfaction rating (1-4, emoji) | `BrewSatisfaction`, `uitest/tyytyvaisyys.sh`, `vaihda.txt` |
| Vaihda / Lisää / Peruuta | Change / Add / Cancel (buttons of the rating sheet) | `vaihda.txt`, `brew_logs_list_view.dart` |
| valmiustila, lepotila | standby (rest state of the machine) | `standby_timeout.dart`, `standby_overlay.dart`, `valmiustila*.txt` |
| lepolampo | standby temperature ("lepolämpö" without diacritics) | `uitest/askeleet/lepolampo.txt` |
| Pidä näyttö päällä | keep the screen on | `settings_view.dart`, `keep_screen_on.dart` |
| Yhteys | connection (the Auto / Wi-Fi / Bluetooth setting) | `link_settings.dart`, `linkModeProvider` |
| vaaka | scale | calibration views |
| asennus | installation | `mac/expresso-asennus.sh`, `ASENNUS-*` packets |
| ajastus | scheduling (timed renewal) | `ASENNUS-AJASTUS` packet, `--ajastus` flag |
| agentti | agent (here: the launch agent, or the AI agent) | `--agentti` flag, `ASENNUS-AGENTTI` |
| uusinta | renewal (of the 7-day signing) | `expresso-asennus.sh` log lines |
| laite | device (the iPhone) | `expresso-asennus.sh` (`laitetila`) |
| lukko / lukittu | lock / locked | `expresso-asennus.sh` (directory lock, screen lock) |
| tila | state | `$T/tila` status file in the install script |
| ohjain | controller (the XCUITest driver) | `uitest/UITests/Ohjain.swift` |
| askeleet | steps | `uitest/askeleet/` |
| ajo | run | `uitest/ajo.sh` |
| rekisteri | register | `REKISTERI.md` |
| historia | history | `HISTORIA.md` |
| arkisto | archive | `ARKISTO.md` |
| paketti, paketit | work packet(s) | `paketit/`, `SEURAAVA PAKETTI` |
| toteuttaja | executor | `delegation.jsonl` notes, agent roles |
| suunnittelija | planner | `delegation.jsonl` notes |
| hyväksyntä | acceptance | brief section `Acceptance`, log notes |
| päätökset | decisions | `REKISTERI.md` section |
| avoimet asiat | open issues | `REKISTERI.md` table |
| viat | faults | `REKISTERI.md` section |
| ALUSTA / NAYTTO | platform setup / display | packet names |
| PARITEETTI | parity (iOS matching the Android app's background behaviour) | register and history entries |
| skooppi | scope (a work area in the author's agent harness) | registers |
| pura / pakkaa | unpack / pack (load or save the context of a conversation) | registers, history |
| Ohita | Skip | demo shot-log form button, step files |
| Uutto tallennettu | "Shot saved" | local notification text |
