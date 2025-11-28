#!/usr/bin/env perl
use strict;
use warnings;
use v5.30;
use File::Temp qw(tempdir);
use File::Basename;

## LIVING TREE - BASE32 ARCHIVE GENERATOR
## Creates self-contained BASE32 encoded tar.xz of workspace
## Can be restored offline without git pull

my $workspace_dir = $ARGV[0] || '/home/claude/living-tree';
my $output_file = "$workspace_dir/LIVING_TREE_ARCHIVE.base32";
my $temp_dir = tempdir(CLEANUP => 1);

say "=" x 70;
say "🧬 Living Tree - BASE32 Archive Generator";
say "=" x 70;
say "";

# Check workspace exists
unless (-d $workspace_dir) {
    die "❌ Workspace not found: $workspace_dir\n";
}

chdir $workspace_dir or die "Cannot cd to workspace: $!";

say "📦 Creating archive from workspace...";
say "Source: $workspace_dir";
say "Output: $output_file";
say "";

# Exclude git directory and the archive itself
my @exclude_patterns = (
    '--exclude=.git',
    '--exclude=.gitignore',
    '--exclude=LIVING_TREE_ARCHIVE.base32',
    '--exclude=LIVING_TREE_ARCHIVE.base32.tmp',
);

# Create tar.xz archive
my $temp_archive = "$temp_dir/workspace.tar.xz";
say "🗜️  Compressing with xz...";

my $tar_cmd = "tar " . join(' ', @exclude_patterns) . " -cJf $temp_archive .";
system($tar_cmd) == 0 or die "❌ tar failed: $!\n";

my $archive_size = -s $temp_archive;
my $archive_kb = sprintf("%.1f", $archive_size / 1024);
say "✅ Archive created: ${archive_kb} KB";
say "";

# Encode to BASE32
say "🔤 Encoding to BASE32...";
my $base32_data = `base32 < $temp_archive`;
chomp $base32_data;

# Remove any whitespace
$base32_data =~ s/\s+//g;

my $encoded_size = length($base32_data);
my $encoded_kb = sprintf("%.1f", $encoded_size / 1024);
say "✅ Encoded: ${encoded_kb} KB";
say "";

# Create self-documenting archive file
say "📝 Creating self-extracting BASE32 archive...";

my $timestamp = localtime();
my $hostname = `hostname 2>/dev/null` || 'unknown';
chomp $hostname;

open my $out, '>', "$output_file.tmp" or die "Cannot write: $!";

print $out <<'HEADER';
# 🌳 LIVING TREE GENETIC ARCHIVE 🌳
## Self-Contained BASE32 Encoded Workspace

**This file contains the complete Living Tree workspace encoded in BASE32.**
**The Living Tree literally stores its own genetic code using the BASE32 system it implements!**

HEADER

print $out "**Generated**: $timestamp\n";
print $out "**Host**: $hostname\n";
print $out "**Original Size**: ${archive_kb} KB (compressed tar.xz)\n";
print $out "**Encoded Size**: ${encoded_kb} KB (BASE32 text)\n";
print $out "**Compression**: " . sprintf("%.1f%%", ($archive_size / ($encoded_size || 1)) * 100) . " efficiency\n";
print $out "\n";

print $out <<'USAGE';
---

## 🚀 Quick Restoration (Three Methods)

### Method 1: With Git (Online)
```bash
cd /home/claude
git clone REPO_URL living-tree
cd living-tree
# Files ready instantly!
```

### Method 2: From BASE32 (Offline)
```bash
# Extract the BASE32 data and decode:
sed -n '/BEGIN_LIVING_TREE_BASE32/,/END_LIVING_TREE_BASE32/p' \
  LIVING_TREE_ARCHIVE.base32 | \
  grep -v BEGIN | grep -v END | \
  base32 -d | tar -xJ

# Workspace extracted!
```

### Method 3: Self-Extracting Script
```bash
# Run the extractor (if available):
perl extract_living_tree.pl LIVING_TREE_ARCHIVE.base32
```

---

## 🧬 Philosophy

**Self-Referential Encoding:**
- The Living Tree implements BASE32 harmonic routing
- This archive uses that same BASE32 encoding to store itself
- The system literally contains its own genetic information
- Beautiful recursion: the tree encodes the tree

**Redundancy:**
- Git repository = fast, version-controlled access
- BASE32 archive = single-file, offline-capable backup
- Either method restores complete workspace
- Multiple paths to the same truth

**Portability:**
- Copy this single file anywhere
- Restore without network access
- Share complete system in one file
- Train, plane, offline scenarios covered

---

## 📋 What's Encoded

The archive contains:
- Complete BASE32 harmonic routing implementation
- Interactive psychedelic visualization
- Technical specifications and guides
- Working demonstrations
- Development history
- All documentation

Everything needed to continue Living Tree development!

---

## 🔍 Verification

After extraction, verify contents:
```bash
find . -type f -not -path './.git/*' | sort
```

Expected files:
- core/base32_harmonic_routing.pl
- core/living_tree_base32_viz.html
- core/BASE32_HARMONIC_INTEGRATION_GUIDE.md
- core/LIVING_TREE_SUMMARY.md
- core/PROTOCOL7_HARMONIC_LIVING_TREE.md
- implementations/tree-shuffle-demo.pl
- documentation/SESSION_SUMMARY.md

---

## 📊 BASE32 Data Below

The following BASE32 encoded data contains the complete compressed workspace.
Decode with: `base32 -d | tar -xJ`

USAGE

print $out "```\n";
print $out "BEGIN_LIVING_TREE_BASE32\n";

# Write BASE32 data in 76-character lines (like base64 standard)
my $line_length = 76;
for (my $i = 0; $i < length($base32_data); $i += $line_length) {
    my $chunk = substr($base32_data, $i, $line_length);
    print $out "$chunk\n";
}

print $out "END_LIVING_TREE_BASE32\n";
print $out "```\n";
print $out "\n";

print $out <<'FOOTER';
---

## 🌳 The Living Tree Grows

**From BASE32 encoding to BASE32 storage.**
**From implementation to self-reference.**
**From code to genetic archive.**

The system preserves itself using its own technology.

---

**Generated automatically by Living Tree workspace**
**Part of the anti-entropic self-organizing system**
**🌳 Genetic integrity maintained 🌳**
FOOTER

close $out;

# Move to final location
rename "$output_file.tmp", $output_file or die "Cannot rename: $!";

say "=" x 70;
say "✅ BASE32 Archive Generated Successfully!";
say "=" x 70;
say "";
say "📁 Location: $output_file";
say "📊 Size: ${encoded_kb} KB";
say "🧬 Format: Self-documenting BASE32 encoded tar.xz";
say "";
say "The Living Tree now contains its own genetic code! 🌳";
say "";
say "Add to git:";
say "  cd $workspace_dir";
say "  git add LIVING_TREE_ARCHIVE.base32";
say "  git commit -m 'Updated genetic archive'";
say "  git push";
say "";
