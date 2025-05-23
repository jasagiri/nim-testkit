# VCS Configuration Examples

This guide shows how to configure Nim TestKit for different version control systems.

## Git Only

For projects using only Git:

```toml
[vcs]
git = true
jujutsu = false
mercurial = false
svn = false
fossil = false
```

## Jujutsu with Git Colocated

For projects using Jujutsu with a colocated Git repository:

```toml
[vcs]
git = true      # Enable for Git hooks
jujutsu = true  # Enable for Jujutsu features
mercurial = false
svn = false
fossil = false
```

## Mercurial

For projects using Mercurial:

```toml
[vcs]
git = false
jujutsu = false
mercurial = true
svn = false
fossil = false
```

## Multiple VCS

For projects that might be cloned with different VCS (e.g., a project mirrored to both Git and Mercurial):

```toml
[vcs]
git = true
jujutsu = false
mercurial = true
svn = false
fossil = false
```

## Disable All VCS

To disable all VCS integration (tests always run on all files):

```toml
[vcs]
git = false
jujutsu = false
mercurial = false
svn = false
fossil = false
```

## Advanced Jujutsu with MCP

For advanced Jujutsu features with MCP-Jujutsu:

```toml
[vcs]
git = false     # Disable if using pure Jujutsu
jujutsu = true  # Enable MCP-Jujutsu features
mercurial = false
svn = false
fossil = false
```

This enables:
- Change-based test caching
- Conflict-aware testing
- Best practices guidance
- Operation-based test history