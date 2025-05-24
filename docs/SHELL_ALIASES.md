# Shell Aliases for nim-testkit

To make nim-testkit commands shorter, you can add these aliases to your shell configuration.

## Bash/Zsh (~/.bashrc or ~/.zshrc)

```bash
# nim-testkit aliases
alias ntk='ntk'                    # Short unified command (if installed)
alias ntest='nimtestkit_runner'    # Run tests
alias ngen='nimtestkit_generator'  # Generate tests
alias ncov='coverage_helper'       # Coverage report
alias nwatch='test_guard'          # Watch mode
alias ninit='nimtestkit_init'      # Initialize project

# Even shorter aliases
alias nt='nimtestkit_runner'
alias ng='nimtestkit_generator'
alias nc='coverage_helper'
alias nw='test_guard'
```

## Fish (~/.config/fish/config.fish)

```fish
# nim-testkit aliases
alias ntk 'ntk'
alias ntest 'nimtestkit_runner'
alias ngen 'nimtestkit_generator'
alias ncov 'coverage_helper'
alias nwatch 'test_guard'
alias ninit 'nimtestkit_init'
```

## PowerShell ($PROFILE)

```powershell
# nim-testkit aliases
Set-Alias ntk ntk
Set-Alias ntest nimtestkit_runner
Set-Alias ngen nimtestkit_generator
Set-Alias ncov coverage_helper
Set-Alias nwatch test_guard
Set-Alias ninit nimtestkit_init
```

## Usage Examples

After adding aliases:

```bash
# Instead of:
nimtestkit_init myproject
nimtestkit_runner
nimtestkit_generator
coverage_helper

# You can use:
ninit myproject
ntest
ngen
ncov

# Or with the unified command:
ntk init myproject
ntk test
ntk gen
ntk cov
```