#!/bin/sh
# Install VCS hooks for Nim TestKit
# Supports Git, Jujutsu, Mercurial

# Get the script directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
ROOT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")

echo "Installing VCS hooks..."

# Function to install Git hooks
install_git_hooks() {
  if [ -d ".git" ]; then
    echo "Installing Git hooks..."
    if [ ! -d ".git/hooks" ]; then
      mkdir -p .git/hooks
    fi
    cp "$SCRIPT_DIR/pre-commit" ".git/hooks/"
    chmod +x ".git/hooks/pre-commit"
    echo "✓ Git hooks installed"
  fi
}

# Function to install Jujutsu hooks
install_jujutsu_hooks() {
  if [ -d ".jj" ]; then
    echo "Installing Jujutsu hooks..."
    if [ ! -d ".jj/hooks" ]; then
      mkdir -p .jj/hooks
    fi
    
    # Create post-new hook for Jujutsu
    cat > ".jj/hooks/post-new" << 'EOF'
#!/bin/sh
# Auto-run tests on jj new
echo "Running tests for new change..."
nimble test
EOF
    chmod +x ".jj/hooks/post-new"
    echo "✓ Jujutsu hooks installed"
  fi
}

# Function to install Mercurial hooks
install_mercurial_hooks() {
  if [ -d ".hg" ]; then
    echo "Installing Mercurial hooks..."
    
    # Check if .hg/hgrc exists
    if [ ! -f ".hg/hgrc" ]; then
      touch ".hg/hgrc"
    fi
    
    # Add pre-commit hook to hgrc if not already present
    if ! grep -q "pretxncommit.nimtestkit" ".hg/hgrc"; then
      cat >> ".hg/hgrc" << EOF

[hooks]
pretxncommit.nimtestkit = $SCRIPT_DIR/pre-commit
EOF
      echo "✓ Mercurial hooks configured in .hg/hgrc"
    else
      echo "✓ Mercurial hooks already configured"
    fi
  fi
}

# Function to show SVN hook instructions
show_svn_instructions() {
  if [ -d ".svn" ]; then
    echo ""
    echo "SVN hooks must be installed on the server side."
    echo "Please contact your SVN administrator to install pre-commit hooks."
  fi
}

# Function to show Fossil hook instructions
show_fossil_instructions() {
  if [ -f ".fslckout" ] || [ -f "_FOSSIL_" ]; then
    echo ""
    echo "Fossil hooks can be configured using:"
    echo "  fossil hook add --command '$SCRIPT_DIR/pre-commit' pre-commit"
  fi
}

# Detect and install hooks for all VCS
VCS_FOUND=false

if [ -d ".git" ]; then
  VCS_FOUND=true
  install_git_hooks
fi

if [ -d ".jj" ]; then
  VCS_FOUND=true
  install_jujutsu_hooks
fi

if [ -d ".hg" ]; then
  VCS_FOUND=true
  install_mercurial_hooks
fi

if [ -d ".svn" ]; then
  VCS_FOUND=true
  show_svn_instructions
fi

if [ -f ".fslckout" ] || [ -f "_FOSSIL_" ]; then
  VCS_FOUND=true
  show_fossil_instructions
fi

if [ "$VCS_FOUND" = false ]; then
  echo "Error: No supported VCS repository found"
  echo "Supported: Git, Jujutsu, Mercurial, SVN, Fossil"
  exit 1
fi

echo ""
echo "VCS hooks installation complete!"