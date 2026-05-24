# Security Cleanup Instructions

⚠️ **IMPORTANT:** Your `firebase_options.dart` file was previously committed to git history. Even though we removed it, it still exists in old commits. GitHub detected this and flagged it.

## What You Need to Do

### Option 1: Rotate Your API Keys (RECOMMENDED)

This is the safest approach:

1. **Rotate Firebase API Keys:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings → General
   - Under "Your apps", delete the current app registrations
   - Re-add your apps (this generates new API keys)
   - Run `flutterfire configure` again to get new `firebase_options.dart`

2. **Rotate Groq API Key:**
   - Go to [Groq Console](https://console.groq.com/keys)
   - Delete your current API key
   - Create a new API key
   - Update your `assets/.env` file

3. **Push the cleaned repository:**
   ```bash
   git push origin main --force
   ```

### Option 2: Clean Git History (Advanced)

If you want to remove the sensitive files from git history entirely:

⚠️ **WARNING:** This rewrites git history and will require force push. Coordinate with team members first!

```bash
# Install git-filter-repo (if not installed)
# Ubuntu/Debian:
sudo apt-get install git-filter-repo

# macOS:
brew install git-filter-repo

# Remove the file from all commits
git filter-repo --path lib/firebase_options.dart --invert-paths

# Force push to remote
git push origin main --force
```

### Option 3: Create a New Repository (Easiest)

If this is a new project with few commits:

1. Create a new GitHub repository
2. Copy your current code (excluding `.git` folder)
3. Initialize fresh git:
   ```bash
   rm -rf .git
   git init
   git add .
   git commit -m "Initial commit with secure configuration"
   git remote add origin <new-repo-url>
   git push -u origin main
   ```

## After Cleanup

1. Verify sensitive files are not in git:
   ```bash
   git log --all --full-history -- lib/firebase_options.dart
   ```
   (Should show nothing or only the deletion commit)

2. Check GitHub for secret alerts:
   - Go to your repository on GitHub
   - Settings → Security → Secret scanning alerts
   - Verify alerts are resolved

3. Add branch protection (optional but recommended):
   - Settings → Branches → Add rule
   - Require pull request reviews
   - Prevent force pushes (after cleanup)

## Prevention Checklist

✅ `.gitignore` includes sensitive files
✅ Template files (`.example`) are provided
✅ `SETUP.md` has clear instructions
✅ API keys have been rotated
✅ Git history is clean
✅ Team members are aware of security practices

## What Files Should NEVER Be Committed

- `lib/firebase_options.dart` (Firebase config)
- `assets/.env` (API keys)
- `*.keystore` (Android signing keys)
- `*.p12` (iOS certificates)
- `google-services.json` (Android Firebase config)
- `GoogleService-Info.plist` (iOS Firebase config)
- Any file containing passwords, tokens, or API keys

## Resources

- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [Git Filter Repo](https://github.com/newren/git-filter-repo)
- [Firebase Security Best Practices](https://firebase.google.com/docs/projects/api-keys)
