# Invoke.ai Migration Plan
## Safe Transfer from Old to New Installation

---

## Current Situation Analysis

### What's Working
- ✅ **38,315 images** in database
- ✅ **81GB of outputs** preserved in `/mnt/ext-xfs-data/backup.invoke-outputs/`
- ✅ **Model metadata** intact in database (31 models catalogued)
- ✅ **Prompts/settings** preserved with each image

### What's Broken
- ❌ **Model files deleted** (382GB) - flat directory structure vs UUID expected
- ❌ **Windows paths** may exist in database from transfer
- ❌ **Old installation** may be unstable

---

## Phase 1: Export Everything (SAFETY FIRST)

### 1.1 Export Configuration

```bash
# Export all metadata to YAML
bin/scripts/invoke-ai/invoke-export-config -output /mnt/ext-xfs-data/invoke-full-backup-$(date +%Y%m%d).yaml

# Include image metadata (bigger file, but complete)
bin/scripts/invoke-ai/invoke-export-config -include-images -output /mnt/ext-xfs-data/invoke-complete-backup.yaml

# Compress for archival
xz -9 -k /mnt/ext-xfs-data/invoke-complete-backup.yaml
```

### 1.2 Backup Raw Outputs

```bash
# Ensure outputs are safe
rsync -avP /mnt/ext-xfs-data/backup.invoke-outputs/ /mnt/ext-xfs-data/invoke-outputs-backup-$(date +%Y%m%d)/
```

### 1.3 Database Backup

```bash
# SQLite backup
cp ~/.invokeai/db/invokeai.db /mnt/ext-xfs-data/invoke-database-backup-$(date +%Y%m%d).db
```

---

## Phase 2: Install New Invoke.ai

### 2.1 Fresh Installation

```bash
# Choose ONE method:

# Option A: Official installer
# Download from https://invoke-ai.github.io/InvokeAI/
# Run installer, choose NEW directory

# Option B: pip/uv in new venv
cd /opt
mkdir invokeai-new
cd invokeai-new
uv venv --python 3.11
source .venv/bin/activate
uv pip install invokeai

# Configure for NEW paths
export INVOKEAI_ROOT=/mnt/ext-xfs-data/invokeai-new
invokeai-configure
```

### 2.2 Configure New Instance

```yaml
# /mnt/ext-xfs-data/invokeai-new/invokeai.yaml
schema_version: 4.0.2

host: 0.0.0.0
port: 9090  # Different from old port

# Model paths
models_dir: /mnt/ext-xfs-data/invokeai-new/models
outputs_dir: /mnt/ext-xfs-data/invokeai-new/outputs

cache:
  dir: /var/cache/invoke-ai/huggingface  # Separate from models

# HuggingFace token (for downloads)
huggingface:
  token: ${HF_TOKEN}
```

---

## Phase 3: Recover Models (Properly)

### 3.1 Download to Correct Structure

```bash
# Use our recovery script - it will create UUID-based folders
# with HF token for auth
export HF_TOKEN=your_token
bin/scripts/invoke-ai/invoke-model-recover -download

# This creates proper structure:
# models/
#   a8090866-2511-4088-9277-0df7f54a94c0/
#     model_index.json
#     ...
```

### 3.2 Import from Windows Backup

```bash
# Copy remaining models from Windows
# PRESERVE the UUID subdirectories!
rsync -avP /mnt/windows-disk/user/Invoke/models/* \
    /mnt/ext-xfs-data/invokeai-new/models/
```

### 3.3 Scan and Register

```bash
# Tell Invoke.ai to scan and register models
invokeai-scan-models /mnt/ext-xfs-data/invokeai-new/models
```

---

## Phase 4: Migrate Images & Metadata

### 4.1 Import Images to New DB

Option A: Direct database migration (advanced):
```bash
# Export old image records
sqlite3 ~/.invokeai/db/invokeai.db ".dump images" > /tmp/images_dump.sql

# Import to new database (adjust paths first!)
sqlite3 /mnt/ext-xfs-data/invokeai-new/db/invokeai.db < /tmp/images_dump.sql
```

Option B: Re-import outputs:
```bash
# Copy outputs to new location
rsync -avP /mnt/ext-xfs-data/backup.invoke-outputs/ \
    /mnt/ext-xfs-data/invokeai-new/outputs/

# Use Invoke.ai's import feature (if available)
# Or scan and re-index
invokeai-scan-outputs /mnt/ext-xfs-data/invokeai-new/outputs/
```

### 4.2 Preserve Prompt History

The critical data (prompts, seeds, settings) is in the database - ensure it's migrated.

---

## Phase 5: Verification

### 5.1 Check Everything

```bash
# Verify models
bin/scripts/invoke-ai/invoke-model-recover -check

# Verify images
echo "Images in old DB: $(sqlite3 ~/.invokeai/db/invokeai.db 'SELECT COUNT(*) FROM images;')"
echo "Images in new DB: $(sqlite3 /mnt/ext-xfs-data/invokeai-new/db/invokeai.db 'SELECT COUNT(*) FROM images;')"

# Verify outputs
find /mnt/ext-xfs-data/invokeai-new/outputs -name "*.png" | wc -l
```

### 5.2 Test Generation

1. Start new Invoke.ai: `invokeai-web --host 0.0.0.0 --port 9090`
2. Open web UI
3. Test generation with each model
4. Verify outputs appear in gallery

### 5.3 Test Resume

1. Find an old generation in database
2. Click "Use for new generation"
3. Verify all settings (prompt, seed, model) load correctly

---

## Phase 6: Cleanup Old Installation

Only after verification:

```bash
# Archive old installation
tar czf /mnt/ext-xfs-data/invokeai-old-archive-$(date +%Y%m%d).tar.gz \
    ~/invokeai/ \
    ~/.invokeai/

# Keep for 30 days, then delete if new works
```

---

## Disaster Recovery

### If New Installation Fails

```bash
# Restore old installation
tar xzf /mnt/ext-xfs-data/invokeai-old-archive-*.tar.gz -C ~/

# Restore database
cp /mnt/ext-xfs-data/invoke-database-backup-*.db ~/.invokeai/db/invokeai.db

# Re-run recovery script
bin/scripts/invoke-ai/invoke-model-recover -download
```

---

## File Locations Summary

| Data | Old Location | New Location | Backup |
|------|--------------|--------------|--------|
| Config | ~/invokeai/invokeai.yaml | /mnt/ext-xfs-data/invokeai-new/invokeai.yaml | invoke-full-backup.yaml |
| Database | ~/.invokeai/db/invokeai.db | /mnt/ext-xfs-data/invokeai-new/db/ | invoke-database-backup.db |
| Models | /mnt/ext-xfs-data/models-invoke/ (DELETED) | /mnt/ext-xfs-data/invokeai-new/models/ | Windows: /user/Invoke/models/ |
| Outputs | /mnt/ext-xfs-data/backup.invoke-outputs/ | /mnt/ext-xfs-data/invokeai-new/outputs/ | Same |
| Images | 38,315 in DB | Migrate to new DB | YAML export |

---

## Critical Success Factors

1. ✅ **Never delete old installation until new works**
2. ✅ **Always backup before operations**
3. ✅ **Use UUID-based model structure** (not flat)
4. ✅ **Keep HuggingFace cache separate**
5. ✅ **Test generation before declaring success**

---

## Ready to Start?

Phase 1 (export) is safe and non-destructive. Want me to:
1. Run the export now?
2. Create additional backup scripts?
3. Set up the new installation directory structure?

The 47170 images and their metadata are the irreplaceable treasure - let's secure them! 🛡️

---

#,,.,,,,.,,..,...,.,.,,,.,.,.,..,,...,..,,,,,,.,.,...,...,,,.,,,,,...,...,,,,,
#AI3RSXZIHIRLJDTXLGV4MT6NSQ7LJ3NAWMGXUIOIE2ULAU5TF2HUQ2Z4H5HE57P5KR7XAG3ASX4BC
#\\\|3PWULFKWRR6YMX7UHJM5VRCKLRL6TUUJIKGZTECZOXT2WCWKODG \ / AMOS7 \ YOURUM ::
#\[7]FDN22G3H4E635JFZNTIWP5K6ZNTCUINBDX6BYDOHN2T65VF2JGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
