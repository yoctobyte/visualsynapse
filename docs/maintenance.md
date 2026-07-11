# Visual Synapse — maintenance log

A running, honest record of the revival/maintenance work. **Every change is
documented here** (thread carefully). North star: **maintain `TPastella`**. The
HTTP/FTP servers are a sidetrack. Rewrites are on the table (for pastella *and*
the servers) but are reached by evidence, not led with.

---

## 2026-07-11 — Baseline assessment (discovery, no code changed)

### Toolchain
- Free Pascal **3.2.2**, Lazarus **3.0** present.
- Dependency: **Ararat Synapse** (`geby/synapse`), not bundled — add to unit path
  (`-Fu`). Probes used a local checkout.

### Build state on Linux: nothing compiles as-is
**10 of 14 units `uses Windows`** (Windows-only unit), so the library does not
build on Linux/FPC out of the box. This is the headline finding, and it is
exactly the cross-platform blocker that matters for the pastella-on-anything goal.

`pastella.pas` fails immediately:
```
pastella.pas(52,6) Fatal: Can't find unit Windows used by pastella
```

### Depth of the Windows coupling (what each unit actually uses)
Not all coupling is equal. Probed for real Win32 symbols:

| Unit | Win32 surface | Depth |
|------|---------------|-------|
| **pastella** | `GetTickCount`, `Sleep` only | **shallow** |
| visualserverbase | `Sleep`, `DWord` | shallow |
| visualsynapse | `CreateThread`, `Sleep` | shallow |
| ftpserver | `Sleep` | shallow |
| FileLogger | `Sleep` | shallow |
| authentication | `Handle` (type) | shallow |
| visualsqlserver | `Handle` | shallow |
| httpserver | `CreateFile` (file serving) | moderate |
| telnetserver | `ReadFile`/`WriteFile`/`HANDLE` | moderate |
| ExecCGI | pipes: `ReadFile`/`WriteFile`/`HANDLE` | deep |
| rawip | `WSAIoctl` (raw-socket ioctl) | deep (Win-specific) |

### What this means

- **`TPastella` is close to portable.** Its only hard Windows deps are
  `GetTickCount` (×3) and `Sleep` (×4). `TCriticalSection` already comes from the
  cross-platform `syncobjs`. Replace `GetTickCount`→`GetTickCount64` (SysUtils)
  and drop the `Windows` uses, and it should compile cross-platform. **The
  "total rewrite" question for pastella is NOT about portability — it is about
  architecture** (the lock-ordering, busy-poll, and half-wired packet types noted
  in the code review). Those are separable concerns.
- **Core (visualserverbase, visualsynapse) is shallow** too — a small,
  documented portability shim gets the client/component layer building.
- **Servers split:** ftp/http are shallow-to-moderate but carry known defects
  (HTTP directory-traversal per `SECURITY.md`; FTP passive-port thread leak per
  the original readme). They are the *sidetrack* — port/fix only as needed.
- **Deep Win32 (ExecCGI, telnet, rawip)** is the most work; `rawip` (raw-socket
  ioctl) is fundamentally Windows and may stay Windows-only or be dropped. Defer.

### Direction (decided 2026-07-11)
**Linux/POSIX is now the primary target. Windows is optional.** Most `uses
Windows` are for *types* (`DWord`, `Handle`) that FPC provides cross-platform, or
for `Sleep`/`GetTickCount` that have portable equivalents. The uniform fix:
`uses Windows` → `{$IFDEF MSWINDOWS} Windows,{$ENDIF}`, add portable shims for the
few real calls, keep Windows working behind the ifdef where it's cheap. Drop or
Windows-gate the genuinely Win32-specific bits (`rawip` WSAIoctl, `ExecCGI`
pipes) rather than porting them first.

### Open decisions (for the maintainer)
1. **pastella: shim-and-keep vs. rewrite.** Portability is a small shim either
   way. The real call is whether to *fix the existing architecture in place*
   (lock hierarchy, kill busy-poll, wire or remove the half-done packet types) or
   *rewrite the core* around the good idea (content-addressed offer/fetch gossip)
   as protocol-pure-functions + pluggable transport — the shape that would run on
   ESP32 and be testable with an N-peer loopback harness. Evidence leans toward a
   core rewrite preserving the protocol; the wire format and offer/fetch logic are
   worth keeping, the threading/locking is not.
2. **Scope:** how far to take the servers (sidetrack) — port + traversal fix, or
   leave historical.

*No code changed in this entry — discovery only.*

---

## 2026-07-11 — pastella compiles on Linux/POSIX (north-star milestone)

Goal: get `TPastella` (and its dependency chain) building under FPC 3.2.2 on
Linux, so its runtime behaviour can actually be observed before any fix-vs-rewrite
decision. **Achieved — `pastella.pas` compiles, exit 0** (deprecation warnings
only). Changes, each small and reversible:

- **`FileLogger.pas` → `filelogger.pas`** — Linux is case-sensitive; `uses
  filelogger` could not find the mixed-case file. Lowercased the source name.
- **Duplicate/stray `{$MODE DELPHI}` after `interface`** removed in
  `visualserverbase.pas`, `authentication.pas`, `ExecCGI.pas` — FPC 3.2.2 rejects
  a mode switch after `interface` (older FPC tolerated the duplicate). The correct
  pre-`interface` directive is kept.
- **`visualserverbase.pas`: added `synaip` to `uses`** — `IsIP` moved from
  `synautil` to `synaip` in modern Ararat Synapse (API drift).
- **`pastella.pas`: dropped the hard `Windows` dependency** — `uses Windows` →
  `{$IFDEF MSWINDOWS}Windows,{$ENDIF}`, plus a non-Windows `GetTickCount` shim
  over `SysUtils.GetTickCount64`. `Sleep` and `TCriticalSection` were already
  cross-platform (SysUtils / syncobjs). This confirms the assessment: pastella's
  Windows coupling was shallow.

Compiles clean chain: `vstypedef` → `filelogger`/`authentication` →
`visualserverbase` → `pastella` (against Ararat Synapse on the unit path).

### Follow-ups noted (non-blocking, modernization)
- `TThread.Resume` is deprecated → use `Start` (pastella, visualserverbase,
  filelogger).
- `DecimalSeparator` (global) deprecated → `FormatSettings.DecimalSeparator`
  (pastella `CreateHash`, line ~2045).
- `authentication.pas(207)`: "Function result does not seem to be set" — a real
  latent bug (possible garbage return); investigate.
- Synapse-internal deprecations (`HostToNet`/`TimeSeparator`/…) are upstream, not
  ours.

**No behaviour changed** — this is a compile-enablement port. Runtime observation
(and the fix-vs-rewrite decision) comes next.
