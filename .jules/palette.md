# Palette UX Journal

## 2026-08-13 - CLI Prompt Defaults
**Learning:** In interactive CLI tools, displaying options like `[Y/n]` indicates to the user that "Yes" is the default option and hitting "Enter" (submitting empty input) will select it. Standardizing interactive prompts to accept empty inputs, as well as variations like "yes", "YES", or "y", improves overall flow and prevents frustrating accidental aborts.
**Action:** Always handle empty inputs (`""`) as the default capitalized option in interactive CLI prompts, and robustly match yes/no variations.
