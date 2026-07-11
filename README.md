# Visual Synapse

RAD **component wrappers** and from-scratch **protocol servers** built on top of
the [Ararat Synapse](https://synapse.ararat.cz/) TCP/IP library — for Delphi,
Kylix, Free Pascal / Lazarus and C++ Builder.

Ararat Synapse gives you the low-level sockets and *client* protocols. Visual
Synapse adds the two things Synapse itself never shipped:

1. **RAD components** — drop-on-form, Object-Inspector-configurable wrappers over
   Synapse's client protocols (HTTP, UDP, DNS, ICMP, TCP, SMTP). Commands run on
   a background thread; a callback fires per result.
2. **Servers** — hand-written protocol *server* implementations: HTTP, FTP, SMTP,
   telnet, and a SQL server component. This is the bulk of the code, and the part
   Synapse+Indy didn't cover in this shape at the time.

It also carries **`pastella.pas`** — `TPastella`, an experimental peer-to-peer
layer: a content-addressed offer/fetch gossip protocol (Gnutella lineage; the
name is a Pascal pun). Alpha, historically unfinished — present in the tree since
2004.

> ⚠️ **The old SourceForge project is stale/archived.** All development and the
> full history now live here on GitHub. Do not use the SourceForge downloads as
> a source of truth — they are frozen at the 2008 `0.60` release.

## Migration (2026)

Migrated from SourceForge to GitHub on **2026-07-11**. The pre-2026 commit
history was **reconstructed from the dated SourceForge file releases (2004–2008)**
— each commit is backdated to its real release date and authored as `artee`
(René Tegel), the original SourceForge account. Granularity is *release-level*,
not per-commit: SourceForge retired the original CVS repository in 2025, so the
finer CVS history no longer exists. Every date shown is a genuine release date.

Original (archived) project:
<https://sourceforge.net/projects/visualsynapse/>

## Repository layout

| Unit | Role |
|------|------|
| `visualsynapse.pas` | Client component wrappers (self-contained) |
| `visualserverbase.pas` | Server base — threading, connection handling |
| `visualservercomponents.pas` | Server component registration |
| `httpserver.pas` | HTTP server |
| `ftpserver.pas` | FTP server |
| `smtpserver.pas` | SMTP server |
| `telnetserver.pas` | Telnet server |
| `visualsqlserver.pas` | SQL server component |
| `tcpserver.pas` | Generic TCP server |
| `ExecCGI.pas` | CGI execution for the HTTP server |
| `authentication.pas` | Auth helpers |
| `FileLogger.pas` | Logging |
| `rawip.pas` | Raw IP helpers |
| `vstypedef.pas` | Shared type definitions |
| `pastella.pas` | `TPastella` P2P layer (alpha) |

## History (release timeline)

```
2004-06  0.21   first Synapse client wrapper
2004-08  0.1    first server components (http/tcp)
2004-09  0.27   pastella (P2P) appears; ftp/smtp/telnet servers
2004-11  0.30
2004-12  TClamav 0.1
2005-05  0.40   merged lib+server distribution
2008-10  0.60   OSI relicense, FPC-tested, pastella marked alpha (final SF)
2026-07  →       migrated to GitHub, modernization begins
```

## Dependencies

Ararat Synapse is **not bundled** — fetch it from <https://synapse.ararat.cz/>.
Visual Synapse is a layer on top of it, and exists in part to honour that
project, which is still alive and BSD-licensed.

## Status & roadmap

The imported code is a faithful 2008 baseline; it is **not yet verified against
modern FPC/Lazarus**. Planned modernization:

- [ ] Compile clean under FPC 3.2+ / Lazarus
- [ ] Unicode-string safety (the code assumes 1-byte `String`; breaks on
      Delphi 2009+/`UnicodeString`)
- [ ] **Fix the HTTP server directory-traversal** (see `SECURITY.md`)
- [ ] Fuzz the request parsers; treat all servers as untrusted surface
- [ ] Proper Lazarus package (`.lpk`) with palette registration + design-time
- [ ] Resurrect / harden `pastella` (lock hierarchy, N-peer test harness);
      cross-platform P2P is the long-term aim

Contributions welcome once the baseline compiles green.

## Security

**Do not run the 0.60 servers in production.** See [`SECURITY.md`](SECURITY.md):
the 0.60 HTTP server has a known, unpatched directory-traversal, and the code
predates modern transport hardening. History is preserved for fidelity; fixes
land in later commits.

## License

Choice of OSI-approved licenses (see `mpl.txt`, `gpl.txt`, `lgpl.txt`,
`license.txt`) — MPL / GPL / LGPL, per the unit headers. Use under the terms of
at least one.

## Credits

Written by **René Tegel** (`artee`), 2004–2008. Built on **Ararat Synapse** by
Lukas Gebauer. Revived and migrated to GitHub in 2026.
