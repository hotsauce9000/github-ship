# Go .gitignore Best Practices

## Must-Have Entries

```gitignore
# Dependency directory (if using Go modules)
vendor/

# Compiled binaries
*.exe
*.exe~
*.dll
*.so
*.dylib

# Test binaries
*.test

# Output of go cover
*.out

# Go workspace file
go.work
```

## Common Mistakes

- Committing compiled binaries to the repository
- Ignoring `go.sum` — it should be committed to ensure reproducible builds

## How to Check

Run `git status` and look for:
1. Any files matching patterns above that aren't in `.gitignore`
2. Any large binary files (images, databases, zips)
3. Any files containing secrets (search for "api_key", "password", "token", "secret")
