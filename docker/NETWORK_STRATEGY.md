# 网络资源分类策略 v5.4.3

## 核心原则

**有镜像直连（快），无镜像代理（必要时用）**

## 资源分类

### 类别 1: 有国内镜像 - 直连（不用代理）

| 资源 | 镜像源 | 速度提升 | 连接方式 |
|------|--------|----------|----------|
| **Rust 工具链** | 清华镜像 | 1000x | ✅ DIRECT (--noproxy) |
| **Conda 包** | 清华镜像 | 20x | ✅ DIRECT (--noproxy) |
| **PyPI 包** | 清华镜像 | 30x | ✅ DIRECT (--noproxy) |
| **NPM 包** | 淘宝镜像 | 10x | ✅ DIRECT (--noproxy) |
| **APT 包** | 清华/中科大/阿里云 | 10-20x | ✅ DIRECT (--noproxy) |

**原理**:
- 国内镜像已经在国内，直连比绕道代理更快
- 使用 `--noproxy "*"` 或 `no_proxy="*"` 强制直连
- 测试时跳过代理检测，直接测速

### 类别 2: 无国内镜像 - 按需代理

| 资源 | 官方源 | 是否需要代理 | 连接方式 |
|------|--------|--------------|----------|
| **GitHub** | github.com | 是 | 🌐 Clash Proxy |
| **Debian 官方源** | deb.debian.org | 否 (CN镜像优先) | ✅ DIRECT or 🌐 Proxy (fallback) |
| **Anaconda 官方** | repo.anaconda.com | 否 (CN镜像优先) | ✅ DIRECT or 🌐 Proxy (fallback) |

**原理**:
- 优先测试CN镜像（直连）
- CN镜像失败才启用代理访问官方源
- GitHub等被墙资源必须用代理

## 配置实现

### 1. Rust 工具链（直连）

```bash
# 测试清华镜像（直连，不用代理）
if curl -sf "https://mirrors.tuna.tsinghua.edu.cn/rustup/" -m 3 > /dev/null 2>&1; then
    # 使用清华镜像（直连）
    export RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
    export RUSTUP_UPDATE_ROOT="https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup"
    # 不设置 http_proxy - 直连更快！
else
    # 清华镜像失败才用代理
    export http_proxy="$CLASH_PROXY"
fi
```

### 2. APT 包（优先直连）

```bash
# 测试CN镜像（强制直连，不用代理）
test_apt_mirror() {
    local mirror=$1
    curl -sf --noproxy "*" "http://${mirror}/debian/dists/bookworm/Release" -m 5
}

# 测试顺序：清华 > 中科大 > 阿里云 > 官方（代理）
for mirror in "${CN_MIRRORS[@]}"; do
    if test_apt_mirror "$mirror"; then
        # 使用CN镜像（直连）
        sed -i "s|deb.debian.org|${mirror}|g" /etc/apt/sources.list
        # 不配置 apt proxy
        break
    fi
done

# 所有CN镜像都失败才配置代理
if [ all_failed ] && [ -n "$CLASH_PROXY" ]; then
    echo "Acquire::http::Proxy \"${CLASH_PROXY}\";" > /etc/apt/apt.conf.d/99proxy
fi
```

### 3. PyPI 包（直连）

```bash
# pip 配置文件（强制清华镜像，不用代理）
cat > ~/.pip/pip.conf <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
# 不设置 proxy
EOF
```

### 4. GitHub（必须代理）

```bash
# GitHub 访问必须通过代理
if [ -n "$CLASH_PROXY" ]; then
    git config --global http.proxy "$CLASH_PROXY"
    git config --global https.proxy "$CLASH_PROXY"
else
    echo "Warning: No proxy, GitHub may be inaccessible"
fi
```

## Docker 构建最佳实践

### 方案 1: 全镜像直连（推荐，最快）

```bash
# 不设置代理，让脚本自动选择CN镜像（直连）
docker-compose build vibe-kanban --no-cache
```

**优点**:
- 所有资源都走CN镜像，直连最快
- 不经过代理，减少延迟
- Rust: 24.4 MB/s, APT: 10 MB/s, Conda: 20 MB/s

**缺点**:
- 如果需要访问GitHub会失败

### 方案 2: 混合策略（平衡）

```bash
# 设置代理，但脚本会自动判断是否使用
# CN镜像资源直连，GitHub等走代理
docker-compose build vibe-kanban \
  --build-arg CLASH_PROXY_AVAILABLE=true \
  --no-cache
```

**优点**:
- CN镜像资源直连（快）
- GitHub访问通过代理（可用）
- 最佳平衡

### 方案 3: 全代理（不推荐，慢）

```bash
# 强制所有流量走代理
docker-compose build vibe-kanban \
  --build-arg HTTP_PROXY=http://host.docker.internal:7897 \
  --build-arg HTTPS_PROXY=http://host.docker.internal:7897 \
  --no-cache
```

**优点**:
- 可以访问所有资源（包括被墙的）

**缺点**:
- 即使CN镜像也绕道代理，速度慢
- Rust可能从 24.4 MB/s 降到 2-5 MB/s

## 性能对比

| 策略 | Rust 下载 | APT 下载 | 总构建时间 |
|------|-----------|----------|------------|
| **全镜像直连** | 24.4 MB/s | 10 MB/s | **15 分钟** ⭐ |
| **混合策略** | 24.4 MB/s | 10 MB/s | **16 分钟** |
| **全代理** | 2-5 MB/s | 1-2 MB/s | **30-40 分钟** |
| **无优化** | 25 KB/s | 500 KB/s | **2-3 小时** ❌ |

## 使用示例

### 当前构建（检测到 Clash 7897）

```bash
cd /Users/liuzf/writing/opensource/vibe-kanban

# 使用智能分类策略
bash docker/smart-network-v2.sh

# 构建（自动使用最优路径）
docker-compose build vibe-kanban --no-cache
```

**自动行为**:
- ✅ Rust: 清华镜像（直连，24.4 MB/s）
- ✅ APT: 清华镜像（直连，10 MB/s）
- ✅ Conda: 清华镜像（直连，20 MB/s）
- ✅ PyPI: 清华镜像（直连，15 MB/s）
- 🌐 GitHub: Clash代理（仅在需要时）

## 调试命令

### 测试直连速度

```bash
# 测试清华Rust镜像（直连）
time curl -sf --noproxy "*" \
  "https://mirrors.tuna.tsinghua.edu.cn/rustup/dist/2024-01-01/rust-std-1.75.0-aarch64-unknown-linux-gnu.tar.gz" \
  -o /dev/null

# 测试清华APT镜像（直连）
time curl -sf --noproxy "*" \
  "http://mirrors.tuna.tsinghua.edu.cn/debian/dists/bookworm/Release" \
  -o /dev/null
```

### 测试代理速度

```bash
# 测试Rust通过代理
time curl -x "http://127.0.0.1:7897" -sf \
  "https://static.rust-lang.org/dist/2024-01-01/rust-std-1.75.0-aarch64-unknown-linux-gnu.tar.gz" \
  -o /dev/null

# 对比：直连镜像 vs 代理官方
```

### 验证配置

```bash
# 检查pip配置
cat ~/.pip/pip.conf

# 检查npm配置
npm config get registry

# 检查环境变量
env | grep -i proxy
```

## 总结

### ✅ 正确做法
```
CN镜像 → 直连（--noproxy）→ 快
GitHub → 代理 → 可访问
```

### ❌ 错误做法
```
CN镜像 → 代理 → 慢（绕远路）
GitHub → 直连 → 访问失败
```

### 🎯 最佳实践
1. **优先级**: CN镜像直连 > 官方直连 > 代理访问
2. **测试**: 先测试直连，失败才用代理
3. **隔离**: 不同资源独立配置，不共用全局代理
4. **验证**: 构建前测试网络，确保最优路径

## 版本历史

- **v5.4.3** (2026-01-09): 分类策略 - 有镜像直连，无镜像代理
- **v5.4.2** (2026-01-09): Clash代理支持
- **v5.4.1** (2026-01-09): Rust镜像优化

## 相关文档

- [docker/smart-network-v2.sh](smart-network-v2.sh) - 智能分类配置脚本
- [docker/SMART_NETWORK.md](SMART_NETWORK.md) - 网络配置指南
- [DOCKERFILE_OPTIMIZATION.md](../DOCKERFILE_OPTIMIZATION.md) - 优化文档
