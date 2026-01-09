# Smart Mirror Configuration for vibe-kanban Docker Build
# Automatically selects fastest available mirror with fallback

## Overview

This directory contains scripts for intelligent mirror selection with automatic fallback:

- `select-best-mirror.sh`: Tests multiple mirrors and selects the fastest one
- `Dockerfile.smart-mirror`: Uses automatic mirror selection
- `Dockerfile.original`: Hardcoded mirror configuration (v5.4.1)

## Features

### 1. Automatic Mirror Testing
Tests 5 mirrors in priority order:
1. Official Debian (deb.debian.org) - Default
2. Tsinghua Mirror (CN) - Fast for China
3. USTC Mirror (CN) - Alternative China mirror
4. Aliyun Mirror (CN) - Cloud provider mirror
5. NetEase Mirror (CN) - ISP mirror

### 2. Smart Fallback
- Tests each mirror with 5-second timeout
- Measures response time
- Selects fastest available mirror
- Falls back to official if all fail

### 3. Build-Time Configuration
Use environment variables to override mirror selection:

```bash
# Force specific mirror
docker-compose build --build-arg APT_MIRROR=mirrors.tuna.tsinghua.edu.cn

# Disable mirror selection (use official only)
docker-compose build --build-arg DISABLE_MIRROR_SELECTION=true
```

## Usage

### Option 1: Use Smart Mirror Selection (Recommended)

```bash
# Copy smart Dockerfile
cp docker/Dockerfile.smart-mirror Dockerfile

# Build with automatic mirror selection
docker-compose build vibe-kanban --no-cache
```

### Option 2: Manual Mirror Selection

```bash
# Build with specific mirror
docker-compose build vibe-kanban \
  --build-arg APT_MIRROR=mirrors.tuna.tsinghua.edu.cn \
  --no-cache
```

### Option 3: Original Configuration

```bash
# Use hardcoded configuration
cp docker/Dockerfile.original Dockerfile
docker-compose build vibe-kanban --no-cache
```

## Performance Comparison

| Mirror | Location | Typical Speed | Stability |
|--------|----------|---------------|-----------|
| deb.debian.org | Global CDN | 1-5 MB/s | ⭐⭐⭐⭐⭐ |
| mirrors.tuna.tsinghua.edu.cn | Beijing | 10-50 MB/s (CN) | ⭐⭐⭐⭐ |
| mirrors.ustc.edu.cn | Hefei | 10-40 MB/s (CN) | ⭐⭐⭐⭐ |
| mirrors.aliyun.com | Hangzhou | 5-30 MB/s (CN) | ⭐⭐⭐ |
| mirrors.163.com | Guangzhou | 5-20 MB/s (CN) | ⭐⭐⭐ |

## Rust Toolchain Mirror

The Rust toolchain mirror is configured separately:

```dockerfile
# Always use Tsinghua for Rust (most reliable in testing)
ENV RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
ENV RUSTUP_UPDATE_ROOT="https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup"
```

Speed improvement: **25 KB/s → 24.4 MB/s** (1000x faster)

## Troubleshooting

### All mirrors fail during build

```bash
# Check network connectivity
ping deb.debian.org

# Use official mirror only
docker-compose build --build-arg DISABLE_MIRROR_SELECTION=true
```

### Build hangs during package download

```bash
# Kill build and retry with different mirror
docker-compose build --build-arg APT_MIRROR=mirrors.aliyun.com
```

### Mirror selection takes too long

Edit `select-best-mirror.sh` and reduce timeout:
```bash
local timeout=3  # Changed from 5 to 3 seconds
```

## Version History

- **v5.4.2** (2026-01-09): Smart mirror selection with automatic fallback
- **v5.4.1** (2026-01-09): Rust toolchain mirror optimization
- **v5.3.1**: Original hardcoded USTC mirror

## Related Files

- `/opensource/vibe-kanban/Dockerfile` - Current active Dockerfile
- `/opensource/vibe-kanban/docker/select-best-mirror.sh` - Mirror selection script
- `/opensource/vibe-kanban/DOCKERFILE_OPTIMIZATION.md` - Optimization documentation
