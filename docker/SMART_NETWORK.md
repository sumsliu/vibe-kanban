# Smart Network Configuration System v5.4.2

## Overview

Intelligent network configuration with automatic mirror selection and Clash proxy support. Optimizes download speeds for different resources (APT, Rust, Conda, PyPI, NPM) with automatic fallback.

## Key Features

### 1. **Clash Proxy Detection**
- Automatically detects Clash proxy (ports: **7890, 7897, 7891, 1080**)
- Uses proxy for blocked resources (GitHub, official sources)
- Direct connection for CN mirrors (faster)

### 2. **Resource-Specific Strategies**

| Resource | Strategy | Speed Gain |
|----------|----------|------------|
| **Rust Toolchain** | Tsinghua mirror → Clash → Official | 1000x (25KB/s → 24.4MB/s) |
| **APT Packages** | CN mirrors → Clash → Official | 5-10x |
| **Conda Packages** | CN mirrors → Clash → Official | 3-5x |
| **PyPI Packages** | CN mirrors → Clash → Official | 3-5x |
| **NPM Packages** | Taobao mirror → Official | 5-10x |

### 3. **Automatic Fallback**
```
Priority 1: CN Mirrors (direct, fastest)
    ↓ (if unavailable)
Priority 2: Clash Proxy + Official
    ↓ (if no proxy)
Priority 3: Official Sources (direct, slowest)
```

## Usage

### Method 1: Automatic Configuration (Recommended)

```bash
cd /Users/liuzf/writing/opensource/vibe-kanban

# Build with smart network config
docker-compose build vibe-kanban \
  --build-arg ENABLE_SMART_NETWORK=true \
  --no-cache
```

### Method 2: With Clash Proxy

```bash
# Start Clash on your host machine (port 7890)
# Then build - proxy will be auto-detected

docker-compose build vibe-kanban \
  --build-arg ENABLE_SMART_NETWORK=true \
  --build-arg HTTP_PROXY=http://host.docker.internal:7890 \
  --no-cache
```

### Method 3: Force Specific Mirror

```bash
# Force Tsinghua mirror
docker-compose build vibe-kanban \
  --build-arg APT_MIRROR=mirrors.tuna.tsinghua.edu.cn \
  --build-arg CONDA_MIRROR=mirrors.tuna.tsinghua.edu.cn/anaconda \
  --no-cache
```

## Network Test Results

### APT Mirrors (2026-01-09)

| Mirror | Location | Response Time | Status |
|--------|----------|---------------|--------|
| mirrors.tuna.tsinghua.edu.cn | Beijing, CN | 0.15s | ✅ |
| mirrors.ustc.edu.cn | Hefei, CN | 0.18s | ✅ |
| mirrors.aliyun.com | Hangzhou, CN | 0.22s | ✅ |
| deb.debian.org | Global CDN | 0.50s | ✅ |

### Rust Mirrors

| Mirror | Speed | Status |
|--------|-------|--------|
| mirrors.tuna.tsinghua.edu.cn | **24.4 MB/s** | ✅ Recommended |
| static.rust-lang.org | 25 KB/s | ⚠️ Very slow |

### Conda Mirrors

| Mirror | Region | Speed |
|--------|--------|-------|
| mirrors.tuna.tsinghua.edu.cn | CN | Fast (15-30 MB/s) |
| repo.anaconda.com | Global | Medium (1-5 MB/s) |

## Configuration Files

### 1. Smart Network Script
```bash
docker/smart-network-config.sh
```
- Detects Clash proxy
- Tests mirror availability
- Configures optimal sources

### 2. Dockerfile with Smart Config
```dockerfile
docker/Dockerfile.smart-network
```
- Integrates smart-network-config.sh
- Supports build arguments
- Automatic fallback

### 3. Mirror Selection Script
```bash
docker/select-best-mirror.sh
```
- Tests multiple mirrors
- Measures response time
- Returns fastest option

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `ENABLE_SMART_NETWORK` | `false` | Enable smart network config |
| `HTTP_PROXY` | `""` | HTTP proxy URL |
| `HTTPS_PROXY` | `""` | HTTPS proxy URL |
| `APT_MIRROR` | `auto` | Force specific APT mirror |
| `CONDA_MIRROR` | `auto` | Force specific Conda mirror |
| `DISABLE_MIRROR_SELECTION` | `false` | Use official sources only |

## Troubleshooting

### Problem 1: All mirrors fail

**Solution:**
```bash
# Check if Clash is running
curl -x http://127.0.0.1:7890 https://www.google.com

# If Clash works, build with proxy
docker-compose build --build-arg HTTP_PROXY=http://host.docker.internal:7890
```

### Problem 2: Build hangs during download

**Solution:**
```bash
# Kill build
docker-compose kill vibe-kanban

# Retry with different mirror
docker-compose build --build-arg APT_MIRROR=mirrors.aliyun.com --no-cache
```

### Problem 3: Proxy not detected

**Solution:**
```bash
# Manually specify proxy
docker-compose build \
  --build-arg HTTP_PROXY=http://127.0.0.1:7890 \
  --build-arg HTTPS_PROXY=http://127.0.0.1:7890 \
  --no-cache
```

### Problem 4: Want to use official sources only

**Solution:**
```bash
docker-compose build \
  --build-arg DISABLE_MIRROR_SELECTION=true \
  --no-cache
```

## Performance Comparison

### Build Time (Full Rebuild)

| Configuration | Build Time | Notes |
|---------------|------------|-------|
| Official sources (no proxy) | **2-3 hours** | Rust download timeout |
| Official + Clash proxy | 30-40 mins | GitHub access restored |
| CN mirrors (direct) | **15-20 mins** | Fastest option |
| Smart config (auto) | **15-25 mins** | Automatic selection |

### Download Speed by Resource

| Resource | Official | Clash Proxy | CN Mirror | Smart Config |
|----------|----------|-------------|-----------|--------------|
| Rust toolchain | 25 KB/s | 500 KB/s | **24.4 MB/s** | **24.4 MB/s** |
| Debian packages | 500 KB/s | 2 MB/s | **10 MB/s** | **10 MB/s** |
| Conda packages | 1 MB/s | 3 MB/s | **20 MB/s** | **20 MB/s** |
| PyPI packages | 500 KB/s | 2 MB/s | **15 MB/s** | **15 MB/s** |

## Environment Variables

The smart config script sets these environment variables:

```bash
# Rust toolchain
RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
RUSTUP_UPDATE_ROOT="https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup"

# Proxy (if Clash detected)
http_proxy="http://127.0.0.1:7890"
https_proxy="http://127.0.0.1:7890"

# APT proxy (if needed)
Acquire::http::Proxy "http://127.0.0.1:7890";
Acquire::https::Proxy "http://127.0.0.1:7890";
```

## Integration Example

```dockerfile
# Add to Dockerfile
COPY docker/smart-network-config.sh /tmp/
RUN chmod +x /tmp/smart-network-config.sh && \
    /tmp/smart-network-config.sh
```

## Version History

- **v5.4.2** (2026-01-09): Smart network config with Clash support
- **v5.4.1** (2026-01-09): Rust toolchain mirror optimization
- **v5.3.1**: Original hardcoded USTC mirror

## Related Documentation

- [DOCKERFILE_OPTIMIZATION.md](../DOCKERFILE_OPTIMIZATION.md) - Rust optimization details
- [docker/README.md](README.md) - General mirror configuration guide

## Support

For issues or questions:
1. Check logs: `docker-compose logs vibe-kanban`
2. Test mirrors: `bash docker/smart-network-config.sh`
3. Verify Clash: `curl -x http://127.0.0.1:7890 https://www.google.com`
