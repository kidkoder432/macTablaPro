# macTablaPro Release Blueprint & CLI Runbook

This document contains the release strategy, versioning rules, and GitHub CLI publication runbook for **macTablaPro**.

---

## 1. Versioning Strategy

Following **Semantic Versioning (SemVer 2.0)**:
- **Pre-1.0 Phase (`v0.9.x-beta`)**: Active development, testing, and community feedback prior to general release.
- **GitHub Pre-Release Badge**: All releases in the `0.9.x` series will use GitHub's `--prerelease` flag.
- **v1.0 Milestone**: Reserved for the polished, full-featured general availability release.

---

## 2. Step-by-Step CLI Release Procedure

When you are ready to publish a release from the command line, follow these steps:

### Step 1: Sync Marketing Version in Xcode (Optional)
Ensure `MARKETING_VERSION` in `macTablaPro.xcodeproj/project.pbxproj` matches your target release (e.g., `0.9.0`).

### Step 2: Build & Package App Bundle
Run the packaging script to generate the signed `.app` and `.zip`:
```bash
./export_app.sh
```
This will generate `~/Desktop/macTablaPro.zip`.

### Step 3: Stage and Tag Git Commit
```bash
# Verify working tree is clean
git status

# Create an annotated git tag
git tag -a v0.9.0-beta -m "macTablaPro v0.9.0 Beta Preview"

# Push tag to GitHub
git push origin v0.9.0-beta
```

### Step 4: Create GitHub Release via `gh` CLI
```bash
# Package with specific version name
cp "$HOME/Desktop/macTablaPro.zip" "./macTablaPro-v0.9.0-beta.zip"

# Publish as a pre-release with attached binary
gh release create v0.9.0-beta ./macTablaPro-v0.9.0-beta.zip \
  --title "macTablaPro v0.9.0 (Beta Preview)" \
  --prerelease \
  --notes "### What's New in macTablaPro v0.9.0 Beta
- High-performance native macOS classical Indian music accompaniment workstation.
- Tabla engine with authentic Taals, variations, shuffle styles, and visual LED display.
- Dual Tanpura with independent fine-tuning and tempo sync.
- Swar Mandal with raag scales and continuous hover strumming.
- Studio channel-strip mixer and master Sa pitch controls.
- Integrated Sankalp practice log & riyaaz tracker.
- Presets system with iTablaPro compatibility.

### Installation (Zero Terminal Needed)
1. Download \`macTablaPro-v0.9.0-beta.zip\` below and unzip.
2. Drag \`macTablaPro.app\` to your Applications folder.
3. If macOS displays a developer verification notice:
   Open **System Settings > Privacy & Security**, scroll down to **Security**, and click **Open Anyway**."
```

---

## 3. Verification Commands
To verify the release after publishing:
```bash
# View the newly created release
gh release view v0.9.0-beta

# List all releases
gh release list
```
