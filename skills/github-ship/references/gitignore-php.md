# PHP .gitignore Best Practices

## Must-Have Entries

```gitignore
# Dependencies
vendor/

# PHPUnit cache
.phpunit.result.cache

# Phar archives
*.phar

# Environment & secrets
.env

# composer.lock — ignore for libraries only, commit for applications
# composer.lock

# Laravel / framework storage
storage/
bootstrap/cache/
```

## Common Mistakes

- Committing `vendor/` — dependencies should be installed via `composer install`
- Ignoring `composer.lock` for applications — it should be committed to ensure reproducible builds

## How to Check

Run `git status` and look for:
1. Any files matching patterns above that aren't in `.gitignore`
2. Any large binary files (images, databases, zips)
3. Any files containing secrets (search for "api_key", "password", "token", "secret")
