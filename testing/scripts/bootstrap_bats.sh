#!/bin/sh
# bootstrap_bats.sh - Install Bats and its plugins
set -e

# Configuration
BATS_VERSION="1.9.0"
BATS_SUPPORT_VERSION="0.3.0"
BATS_ASSERT_VERSION="2.1.0"
BATS_FILE_VERSION="0.3.0"

# Installation paths
BATS_ROOT="./.bats"
BATS_CORE="${BATS_ROOT}/bats-core"
BATS_SUPPORT="${BATS_ROOT}/bats-support"
BATS_ASSERT="${BATS_ROOT}/bats-assert"
BATS_FILE="${BATS_ROOT}/bats-file"

# Create directory if it doesn't exist
mkdir -p "${BATS_ROOT}"

# Function to download and install a bats component
install_component() {
  component_name=$1
  repo_url=$2
  version=$3
  target_dir=$4

  if [ ! -d "${target_dir}" ]; then
    echo "Installing ${component_name} ${version}..."
    git clone --depth 1 --branch "v${version}" "${repo_url}" "${target_dir}"
    echo "✅ ${component_name} installed"
  else
    echo "✅ ${component_name} already installed"
  fi
}

# Install bats-core
install_component "bats-core" "https://github.com/bats-core/bats-core.git" "${BATS_VERSION}" "${BATS_CORE}"

# Install bats-support
install_component "bats-support" "https://github.com/bats-core/bats-support.git" "${BATS_SUPPORT_VERSION}" "${BATS_SUPPORT}"

# Install bats-assert
install_component "bats-assert" "https://github.com/bats-core/bats-assert.git" "${BATS_ASSERT_VERSION}" "${BATS_ASSERT}"

# Install bats-file
install_component "bats-file" "https://github.com/bats-core/bats-file.git" "${BATS_FILE_VERSION}" "${BATS_FILE}"

# Create a bats launcher script
cat > "${BATS_ROOT}/bats" << EOF
#!/bin/sh
# Wrapper for Bats with module loading
BATS_ROOT="\$(cd "\$(dirname "\$0")" && pwd)"
BATS_LIBPATH="\${BATS_ROOT}/bats-support:\${BATS_ROOT}/bats-assert:\${BATS_ROOT}/bats-file"
export BATS_LIB_PATH="\${BATS_LIBPATH}"
export PATH="\${BATS_ROOT}/bats-core/bin:\${PATH}"
exec "\${BATS_ROOT}/bats-core/bin/bats" "\$@"
EOF

chmod +x "${BATS_ROOT}/bats"

# Create an alias script at the top level
cat > "./testing/bats" << EOF
#!/bin/sh
# Helper script to run bats from the testing directory
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
exec "\${SCRIPT_DIR}/.bats/bats" "\$@"
EOF

chmod +x "./testing/bats"

# Print success message
echo "======================================================"
echo "✅ Bats and plugins installed successfully!"
echo "✅ You can now run tests with: ./testing/bats specs/"
echo "======================================================"
