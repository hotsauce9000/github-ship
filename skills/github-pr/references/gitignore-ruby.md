# Ruby .gitignore Best Practices

## Must-Have Entries

```gitignore
# Dependencies
.bundle/
vendor/bundle

# Gems
*.gem

# Debug history
.byebug_history

# Logs & temp
log/
tmp/

# Testing & coverage
coverage/
.rspec_status

# Environment & secrets
.env
```

## Common Mistakes

- Committing `vendor/bundle` — dependencies should be installed via `bundle install`
- Committing `.byebug_history` with debug session data

## How to Check

Run `git status` and look for:
1. Any files matching patterns above that aren't in `.gitignore`
2. Any large binary files (images, databases, zips)
3. Any files containing secrets (search for "api_key", "password", "token", "secret")
