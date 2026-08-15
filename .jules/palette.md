# Palette UX Journal

## 2026-08-13 - CLI Prompt Defaults
**Learning:** In interactive CLI tools, displaying options like `[Y/n]` indicates to the user that "Yes" is the default option and hitting "Enter" (submitting empty input) will select it. Standardizing interactive prompts to accept empty inputs, as well as variations like "yes", "YES", or "y", improves overall flow and prevents frustrating accidental aborts.
**Action:** Always handle empty inputs (`""`) as the default capitalized option in interactive CLI prompts, and robustly match yes/no variations.

## 2026-08-14 - Standard CLI Help & Alias Options
**Learning:** Command-line installer scripts should provide standard help flags (`-h`, `--help`) and long option aliases (`--yes` alongside `-y`). Unclear or missing CLI flag help forces users to guess or read raw shell scripts to discover options.
**Action:** Always implement formatted `--help` / `-h` text in CLI utilities and pair short flags with intuitive long options (`--yes`).
