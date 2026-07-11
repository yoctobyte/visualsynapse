# Visual Synapse

Component wrappers and **server implementations** built on top of the
[Ararat Synapse](https://synapse.ararat.cz/) TCP/IP library, for Delphi, Kylix,
Free Pascal / Lazarus and C++ Builder.

Where Ararat Synapse provides the low-level sockets and client protocols, Visual
Synapse adds two things Synapse itself did not ship:

1. **RAD components** — drop-on-form, Object-Inspector-configurable wrappers over
   Synapse's client protocols (HTTP, UDP, DNS, ICMP, TCP, SMTP).
2. **Servers** — from-scratch protocol *server* implementations: HTTP, FTP,
   SMTP, telnet, and a SQL server component. These are the bulk of the code.

It also carries **`pastella.pas`** — `TPastella`, an experimental peer-to-peer
connection layer (a content-addressed offer/fetch gossip protocol, Gnutella
lineage; the name honours Pascal). Alpha, historically unfinished; present in the
tree since 2004.

## History

This repository reconstructs the original SourceForge project history from its
dated file releases (2004–2008), each commit backdated to its real release date
and authored as `artee` (René Tegel), then continued on GitHub. Granularity is
release-level — the original CVS repository was retired by SourceForge in 2025.

Timeline: `visualsynapse 0.21` (2004-06) → server components → `pastella` appears
(2004-09) → merged `0.40` (2005) → `0.60` (2008, final SF release) → modernization
here.

Original project: https://sourceforge.net/projects/visualsynapse/

## Dependencies

Ararat Synapse is **not** bundled — fetch it from https://synapse.ararat.cz/ .
Visual Synapse is a layer on top of it, and exists to honour that project.

## License

Released under a choice of OSI-approved licenses (see `mpl.txt`, `gpl.txt`,
`lgpl.txt`, `license.txt`) — MPL / GPL / LGPL, per the unit headers. Use under
the terms of at least one.

## Security

**Do not run the 0.60 servers in production.** See [`SECURITY.md`](SECURITY.md)
— the 0.60 HTTP server has a known, unpatched directory-traversal, and this
release predates modern transport hardening. History is preserved for fidelity;
fixes land in later commits.
