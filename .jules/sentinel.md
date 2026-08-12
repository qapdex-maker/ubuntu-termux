# Sentinel Security Journal

## 2026-08-12 - Secure Streaming Checksum Verification
**Vulnerability:** Classic installer scripts often download checksum files and write them to temporary files locally before running verification. If the directory is shared or writeable by other users, this can expose the installation to local race conditions, symlink attacks, or local file pollution/conflicts.
**Learning:** By piping the downloaded checksum file directly through standard utility chains (`wget -q -O- | grep | sed | sha256sum -c -`), we can fully stream the validation in-memory without ever creating insecure, static temporary files on disk.
**Prevention:** Avoid writing insecure temporary files with static or predictable names in script directories. Use standard input streams and Unix pipelines to perform integrity verification securely.
