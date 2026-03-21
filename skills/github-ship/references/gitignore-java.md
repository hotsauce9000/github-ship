# Java .gitignore Best Practices

## Must-Have Entries

```gitignore
# Build output
target/
build/
out/

# Compiled class files
*.class

# Package files
*.jar
*.war
*.ear

# Gradle
.gradle/

# Eclipse
.settings/
.classpath
.project

# IntelliJ
*.iml

# JVM crash logs
hs_err_pid*
```

## Common Mistakes

- Committing `target/` or `build/` directories with compiled artifacts
- Committing IDE-specific `.settings/` directory with local configuration

## How to Check

Run `git status` and look for:
1. Any files matching patterns above that aren't in `.gitignore`
2. Any large binary files (images, databases, zips)
3. Any files containing secrets (search for "api_key", "password", "token", "secret")
