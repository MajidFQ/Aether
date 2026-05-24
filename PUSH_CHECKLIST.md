# Push Checklist - Read Before Pushing! ⚠️

## Current Status

✅ **Completed:**
- Removed `lib/firebase_options.dart` from git tracking
- Added sensitive files to `.gitignore`
- Created template files (`.example`)
- Created `SETUP.md` for new developers
- Committed security changes

⚠️ **Still Need to Do:**
- Rotate your API keys (see below)
- Clean git history OR create new repo
- Push to GitHub

---

## CRITICAL: Before You Push

### Step 1: Rotate Your API Keys

Your Firebase and Groq API keys were exposed in previous commits. You MUST rotate them:

**Firebase:**
1. Go to https://console.firebase.google.com/
2. Select your "aether-a9407" project
3. Project Settings → General
4. Delete current app registrations
5. Re-add apps (generates new keys)
6. Run: `flutterfire configure`

**Groq:**
1. Go to https://console.groq.com/keys
2. Delete your current API key
3. Create a new one
4. Update `assets/.env` with new key

### Step 2: Choose Your Approach

**Option A: Force Push (Quickest)**
```bash
git push origin main --force
```
- ⚠️ This will overwrite remote history
- ✅ Removes sensitive files from history
- ⚠️ Coordinate with team members first

**Option B: Create New Repository (Safest)**
1. Create new GitHub repo
2. Copy code (not .git folder)
3. Fresh git init
4. Push to new repo
5. Update team with new URL

**Option C: Clean History with git-filter-repo**
See `SECURITY_CLEANUP.md` for detailed instructions

---

## After Pushing

### 1. Verify on GitHub
- Check that `lib/firebase_options.dart` is NOT visible
- Check that `assets/.env` is NOT visible
- Verify `.gitignore` is present

### 2. Check Secret Alerts
- Go to: Repository → Settings → Security
- Check "Secret scanning alerts"
- Should show no active alerts (or resolved)

### 3. Test Clone
```bash
cd /tmp
git clone <your-repo-url> test-clone
cd test-clone
# Verify sensitive files are missing
ls lib/firebase_options.dart  # Should not exist
ls assets/.env                # Should not exist
```

### 4. Update Team
Send this message to collaborators:

```
Hi team,

I've updated the repository security:
- Sensitive files are now in .gitignore
- You'll need to set up your own Firebase and Groq configs
- Follow the instructions in SETUP.md

Please:
1. Pull the latest changes
2. Copy lib/firebase_options.dart.example to lib/firebase_options.dart
3. Copy assets/.env.example to assets/.env
4. Add your own API keys

Let me know if you need help!
```

---

## Files That Are Now Protected

These files are in `.gitignore` and will NOT be pushed:

- ✅ `lib/firebase_options.dart` (Firebase config)
- ✅ `assets/.env` (Groq API key)
- ✅ Build artifacts
- ✅ IDE settings

These files WILL be pushed (safe):

- ✅ `lib/firebase_options.dart.example` (template)
- ✅ `assets/.env.example` (template)
- ✅ `SETUP.md` (setup instructions)
- ✅ `.gitignore` (ignore rules)
- ✅ All source code

---

## Quick Command Reference

```bash
# Check what will be pushed
git log origin/main..HEAD --oneline

# Check for sensitive files
git ls-files | grep -E "(firebase_options\.dart|\.env)$"

# Should return nothing (or only .example files)

# Push (after rotating keys!)
git push origin main --force

# If push is rejected
git pull --rebase origin main
git push origin main --force
```

---

## Emergency: If You Accidentally Pushed Secrets

1. **Immediately rotate ALL API keys**
2. **Delete the repository on GitHub**
3. **Create a new repository**
4. **Push clean code**
5. **Update team with new URL**

---

## Summary

Before pushing:
1. ✅ Rotate Firebase API keys
2. ✅ Rotate Groq API key
3. ✅ Choose push approach (force push or new repo)
4. ✅ Push to GitHub
5. ✅ Verify on GitHub
6. ✅ Check secret alerts
7. ✅ Update team

**DO NOT SKIP STEP 1 (Rotate Keys)!**

Your old keys are in git history and could be accessed by anyone who clones the repo before you force push.
