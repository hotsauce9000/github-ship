# Node/JS/TS .gitignore Best Practices

## Must-Have Entries

```gitignore
# Dependencies
node_modules/

# Build output
.next/
.nuxt/
dist/
build/

# Environment & secrets
.env
*.env
.env.*

# Testing & coverage
coverage/
.nyc_output/

# Cache
.cache/
*.tsbuildinfo
.eslintcache

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*
```

## Common Mistakes

- Committing `node_modules/` — always install from `package-lock.json` or `yarn.lock`
- Committing `.env` files with API keys or secrets
- Committing `dist/` or `build/` when they can be rebuilt from source

## How to Check

Run `git status` and look for:
1. Any files matching patterns above that aren't in `.gitignore`
2. Any large binary files (images, databases, zips)
3. Any files containing secrets (search for "api_key", "password", "token", "secret")
