# General .gitignore Best Practices

## Must-Have Entries

```gitignore
# Secrets & credentials
.env
*.env
.env.*
*.pem
*.key

# IDE / editor
.vscode/
.idea/
*.swp
*.swo
*~

# OS files
.DS_Store
Thumbs.db
desktop.ini

# Build output
dist/
build/
out/
target/

# Dependencies
node_modules/
vendor/
.bundle/

# Logs
*.log
logs/

# Coverage
coverage/
.nyc_output/
htmlcov/
```

## Common Mistakes

- Committing `.env` files with API keys or secrets
- Committing IDE config files that contain personal paths or local settings
- Committing large binary files (images, databases, zips, compiled artifacts)

## How to Check

Run `git status` and look for:
1. Any files matching patterns above that aren't in `.gitignore`
2. Any large binary files (images, databases, zips)
3. Any files containing secrets (search for "api_key", "password", "token", "secret")
