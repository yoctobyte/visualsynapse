# Security

## The 0.60 release is a historical import — do not run its servers in production

This repository's pre-2026 history is the original SourceForge releases,
reconstructed for provenance. Those baselines have **known, unpatched issues**.
They are preserved as history, not as runnable production software.

### Known issues in the historical baselines

- **HTTP server — directory traversal.** The 0.60 HTTP server does not fully
  normalize request paths, allowing traversal outside the served root. Reported
  historically, never patched in the original project. Fix tracked as
  post-import modernization work.
- **General transport hardening.** The code predates SPF/modern-TLS-era
  assumptions. Request parsing was not fuzzed. Treat every server as
  network-untrusted surface until the modernization pass lands.

### Reporting

For issues in the modernized code, open a GitHub issue (or, for anything
sensitive, contact the maintainer privately before public disclosure).

### Note

A sibling historical project, `eemailer`, is intentionally **not** revived: its
pre-SPF open SMTP auto-resolve behaviour made it abusable as a spam relay. It
remains an archive-only museum piece, never a runnable tool. Same principle
applies here — history is preserved with warnings, not resurrected blind.
