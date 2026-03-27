# Python .gitignore Best Practices

## Must-Have Entries

```gitignore
# Environment & secrets
.env
*.env
.env.*

# Python bytecode
__pycache__/
*.py[cod]
*$py.class
*.so

# Distribution / packaging
dist/
build/
*.egg-info/
*.egg

# Virtual environments
venv/
.venv/
env/

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/
.nox/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS files
.DS_Store
Thumbs.db
desktop.ini

# Jupyter
.ipynb_checkpoints/

# Type checking
.mypy_cache/
.pytype/
```

## Common Mistakes

- Committing `.env` files with API keys or secrets
- Committing `__pycache__/` directories
- Committing large data files that can be regenerated
- Missing `venv/` or `.venv/` directories
- Committing IDE-specific config (`.vscode/settings.json` with personal paths)

## How to Check

Run `git status` and look for:
1. Any files matching patterns above that aren't in `.gitignore`
2. Any large binary files (images, databases, zips)
3. Any files containing secrets (search for "api_key", "password", "token", "secret")
