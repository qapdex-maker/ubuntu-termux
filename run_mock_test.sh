#!/bin/bash
set -e

echo "=== Setting up mock environment ==="
MOCK_DIR=$(mktemp -d)
mkdir -p "$MOCK_DIR/bin"
mkdir -p "$MOCK_DIR/test_run"

# Create mock dpkg
cat << 'EOF' > "$MOCK_DIR/bin/dpkg"
#!/bin/bash
if [ "$1" = "--print-architecture" ]; then
    echo "amd64"
else
    exit 1
fi
EOF
chmod +x "$MOCK_DIR/bin/dpkg"

# Create mock proot
cat << 'EOF' > "$MOCK_DIR/bin/proot"
#!/bin/bash
# Shift past options and option-arguments to run the underlying command
while [ $# -gt 0 ]; do
    case "$1" in
        -r|-b|-w|-k|-q)
            shift 2
            ;;
        -*)
            shift
            ;;
        *)
            break
            ;;
    esac
done
exec "$@"
EOF
chmod +x "$MOCK_DIR/bin/proot"

# Create mock termux-fix-shebang
cat << 'EOF' > "$MOCK_DIR/bin/termux-fix-shebang"
#!/bin/bash
exit 0
EOF
chmod +x "$MOCK_DIR/bin/termux-fix-shebang"

# Save original path and export mock PATH
ORIG_PATH="$PATH"
export PATH="$MOCK_DIR/bin:$PATH"

# Copy install.sh to the test run directory
cp install.sh "$MOCK_DIR/test_run/"
cd "$MOCK_DIR/test_run"

# Pre-download the official archive so we have a local cache to test with
echo "=== Pre-downloading a copy of rootfs for testing cache ==="
wget https://cdimage.ubuntu.com/ubuntu-base/releases/24.04.4/release/ubuntu-base-24.04.4-base-amd64.tar.gz -q -O valid_ubuntu.tar.gz

# Run Test 1: Full Download & Verify (Clean Run - no cached archive)
echo "=== Running Test 1: install.sh (First installation - clean) ==="
rm -f ubuntu.tar.gz ubuntu-fs ubuntu-binds startubuntu.sh
bash install.sh -y

echo "=== Verification of Test 1 ==="
if [ -d "ubuntu-fs" ]; then
    echo "SUCCESS: ubuntu-fs directory was created!"
else
    echo "FAILED: ubuntu-fs directory was not created!"
    exit 1
fi

if [ -f "startubuntu.sh" ]; then
    echo "SUCCESS: startubuntu.sh script was created!"
else
    echo "FAILED: startubuntu.sh was not created!"
    exit 1
fi

if [ -x "ubuntu-fs/usr/bin/groups" ]; then
    echo "SUCCESS: usr/bin/groups stub is executable!"
else
    echo "FAILED: usr/bin/groups stub is not executable!"
    exit 1
fi

# Clean up extracted files
rm -rf ubuntu-fs ubuntu-binds startubuntu.sh

# Run Test 2: Caching Skip (Valid ubuntu.tar.gz exists)
echo "=== Running Test 2: install.sh (Caching - valid ubuntu.tar.gz exists) ==="
cp valid_ubuntu.tar.gz ubuntu.tar.gz

# Run install.sh and capture output to verify it skips downloading
OUTPUT=$(bash install.sh -y 2>&1)
echo "$OUTPUT"

if echo "$OUTPUT" | grep -q "Existing ubuntu.tar.gz is valid! Skipping download."; then
    echo "SUCCESS: Successfully detected valid archive and skipped download!"
else
    echo "FAILED: Did not skip download for a valid archive!"
    exit 1
fi

# Clean up extracted files
rm -rf ubuntu-fs ubuntu-binds startubuntu.sh

# Run Test 3: Standard Help Flag (-h)
echo "=== Running Test 3: install.sh (-h help flag) ==="
HELP_OUTPUT=$(bash install.sh -h)
if echo "$HELP_OUTPUT" | grep -q "Ubuntu-in-Termux Installer" && echo "$HELP_OUTPUT" | grep -q "\-\-yes"; then
    echo "SUCCESS: -h option displayed help message correctly!"
else
    echo "FAILED: -h option did not display expected help message!"
    exit 1
fi

# Run Test 4: Long Help Flag (--help)
echo "=== Running Test 4: install.sh (--help flag) ==="
HELP_OUTPUT_LONG=$(bash install.sh --help)
if echo "$HELP_OUTPUT_LONG" | grep -q "Ubuntu-in-Termux Installer"; then
    echo "SUCCESS: --help option displayed help message correctly!"
else
    echo "FAILED: --help option did not display expected help message!"
    exit 1
fi

# Run Test 5: Long Yes Flag (--yes)
echo "=== Running Test 5: install.sh (--yes flag) ==="
cp valid_ubuntu.tar.gz ubuntu.tar.gz
YES_OUTPUT=$(bash install.sh --yes 2>&1)
if echo "$YES_OUTPUT" | grep -q "Installation completed successfully!"; then
    echo "SUCCESS: --yes flag ran installation successfully!"
else
    echo "FAILED: --yes flag failed to run installation!"
    exit 1
fi

# Run Test 6: startubuntu.sh Inline Command Execution
echo "=== Running Test 6: startubuntu.sh inline command execution ==="
INLINE_OUTPUT=$(bash ./startubuntu.sh "echo hello_inline_test")
if echo "$INLINE_OUTPUT" | grep -q "hello_inline_test"; then
    echo "SUCCESS: Inline command executed successfully via startubuntu.sh!"
else
    echo "FAILED: Inline command failed to execute!"
    exit 1
fi

# Run Test 7: Invalid Remote Checksum Handling
echo "=== Running Test 7: install.sh (Invalid remote checksum handling) ==="
rm -rf ubuntu-fs ubuntu-binds startubuntu.sh ubuntu.tar.gz
# Override wget in mock PATH temporarily to simulate invalid remote SHA256 response
cat << 'EOF' > "$MOCK_DIR/bin/wget"
#!/bin/bash
if [[ "$*" == *"SHA256SUMS"* ]]; then
    echo "invalid_hash_string  ubuntu-base-24.04.4-base-amd64.tar.gz"
else
    exec /usr/bin/wget "$@"
fi
EOF
chmod +x "$MOCK_DIR/bin/wget"

set +e
INVALID_CHECKSUM_OUTPUT=$(bash install.sh -y 2>&1)
EXIT_CODE=$?
set -e

# Restore standard wget in mock PATH
rm -f "$MOCK_DIR/bin/wget"

if [ $EXIT_CODE -ne 0 ] && echo "$INVALID_CHECKSUM_OUTPUT" | grep -q "Failed to retrieve a valid remote SHA256 checksum"; then
    echo "SUCCESS: Correctly rejected malformed remote SHA256 checksum!"
else
    echo "FAILED: Did not handle malformed remote SHA256 checksum correctly!"
    exit 1
fi

# Clean up temporary test_run directory
cd /
rm -rf "$MOCK_DIR"

echo "=== All Tests Completed successfully! ==="
