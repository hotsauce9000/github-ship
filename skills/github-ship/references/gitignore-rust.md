# Rust .gitignore Best Practices

## Must-Have Entries

```gitignore
# Build output
target/

# Cargo.lock — ignore for libraries only, commit for binaries
# Cargo.lock

# Debug symbols
*.pdb

# Backup files
**/*.rs.bk
```

## Common Mistakes

- Ignoring `Cargo.lock` for binary projects — it should be committed to ensure reproducible builds
- Committing the `target/` directory with compiled artifacts

## How to Check

Run `git status` and look for:
1. Any files matching patterns above that aren't in `.gitignore`
2. Any large binary files (images, databases, zips)
3. Any files containing secrets (search for "api_key", "password", "token", "secret")
