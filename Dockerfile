# Build stage - Debian-based for glibc compatibility (v5.1.21)
FROM docker.m.daocloud.io/library/node:24-slim AS builder

# v5.3.1: 使用构建参数传递代理设置 (用于 Rust 工具链下载)
ARG HTTP_PROXY=""
ARG HTTPS_PROXY=""
ENV http_proxy=${HTTP_PROXY} https_proxy=${HTTPS_PROXY}

# v5.4.4: APT 并行下载优化 (10 并发连接，提升 2-3 倍速度)
ARG APT_PARALLEL=10
RUN if [ -n "$APT_PARALLEL" ] && [ "$APT_PARALLEL" != "0" ]; then \
        echo "Acquire::Queue-Mode \"host\";" > /etc/apt/apt.conf.d/99parallel && \
        echo "Acquire::http::Pipeline-Depth \"${APT_PARALLEL}\";" >> /etc/apt/apt.conf.d/99parallel; \
    fi

# Install build dependencies (Debian packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    build-essential \
    pkg-config \
    libssl-dev \
    libclang-dev \
    perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# v5.4.1: 配置 Rust 工具链镜像（加速 cargo/clippy/rust-analyzer 下载）
# 使用清华镜像 - 速度测试结果：24.4 MB/s (官方源仅 25 KB/s)
ENV RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
ENV RUSTUP_UPDATE_ROOT="https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup"

# Install Rust (使用镜像下载工具链)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Configure Cargo to use Chinese mirror (rsproxy.cn)
RUN mkdir -p /root/.cargo && \
    echo '[source.crates-io]' > /root/.cargo/config.toml && \
    echo 'replace-with = "rsproxy-sparse"' >> /root/.cargo/config.toml && \
    echo '[source.rsproxy-sparse]' >> /root/.cargo/config.toml && \
    echo 'registry = "sparse+https://rsproxy.cn/index/"' >> /root/.cargo/config.toml && \
    echo '[registries.rsproxy]' >> /root/.cargo/config.toml && \
    echo 'index = "https://rsproxy.cn/crates.io-index"' >> /root/.cargo/config.toml && \
    echo '[net]' >> /root/.cargo/config.toml && \
    echo 'git-fetch-with-cli = true' >> /root/.cargo/config.toml

ARG POSTHOG_API_KEY
ARG POSTHOG_API_ENDPOINT

ENV VITE_PUBLIC_POSTHOG_KEY=$POSTHOG_API_KEY
ENV VITE_PUBLIC_POSTHOG_HOST=$POSTHOG_API_ENDPOINT

# Set working directory
WORKDIR /app

# Copy package files for dependency caching
COPY package*.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY frontend/package*.json ./frontend/
COPY npx-cli/package*.json ./npx-cli/

# Install pnpm and dependencies
RUN npm install -g pnpm && pnpm install

# Copy source code
COPY . .

# Build application (use full paths for cargo)
RUN /root/.cargo/bin/cargo run --bin generate_types

# Build frontend with increased memory limit (fix OOM error)
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN cd frontend && pnpm run build
RUN /root/.cargo/bin/cargo build --release --bin server

# Runtime stage - 使用本地缓存的 Python slim (v5.1.22)
# 本地已有 python:3.11-slim 缓存 (Debian trixie)
FROM python:3.11-slim AS runtime

# 设置环境变量 - 清除代理设置使用直连
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH="/opt/conda/envs/researstudio/bin:/opt/conda/bin:$PATH"
ENV http_proxy="" https_proxy="" HTTP_PROXY="" HTTPS_PROXY="" no_proxy="*"

# 配置 Debian 使用中科大镜像源 (v5.1.22 - 解决 deb.debian.org 超时)
# 临时禁用：镜像连接失败，使用官方源
# RUN sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g' /etc/apt/sources.list.d/debian.sources 2>/dev/null || \
#     sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g' /etc/apt/sources.list 2>/dev/null || true

# v5.4.4: APT 并行下载优化 (10 并发连接，提升 2-3 倍速度)
ARG APT_PARALLEL=10
RUN if [ -n "$APT_PARALLEL" ] && [ "$APT_PARALLEL" != "0" ]; then \
        echo "Acquire::Queue-Mode \"host\";" > /etc/apt/apt.conf.d/99parallel && \
        echo "Acquire::http::Pipeline-Depth \"${APT_PARALLEL}\";" >> /etc/apt/apt.conf.d/99parallel; \
    fi

# 安装基础依赖和编译工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    ca-certificates \
    git \
    tini \
    bzip2 \
    build-essential \
    gcc \
    g++ \
    gfortran \
    libopenblas-dev \
    liblapack-dev \
    bash \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 下载并安装 Miniconda (使用清华镜像 - ARM64 版本 for Apple Silicon)
RUN wget -q https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-py311_24.7.1-0-Linux-aarch64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh && \
    /opt/conda/bin/conda install -y -n base conda-libmamba-solver && \
    /opt/conda/bin/conda config --set solver libmamba && \
    /opt/conda/bin/conda clean -afy

# 设置 conda 配置 (v5.1.22 - channels 已在 environment.yml 中定义)
RUN /opt/conda/bin/conda config --set show_channel_urls yes && \
    /opt/conda/bin/conda config --set remote_connect_timeout_secs 30 && \
    /opt/conda/bin/conda config --set remote_read_timeout_secs 120

# 复制并安装 conda 环境 (使用 libmamba solver，更快更稳定)
COPY docker/environment-docker.yml /tmp/environment.yml
RUN /opt/conda/bin/conda env create -f /tmp/environment.yml && \
    /opt/conda/bin/conda clean -afy && \
    rm -rf /tmp/environment.yml /root/.cache

# 单独安装 PyTorch CPU版 (从官方源，避免镜像大文件问题)
RUN /opt/conda/envs/researstudio/bin/pip install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cpu

# v5.1.26: 安装 MCP (Model Context Protocol) 模块 - Claude Code MCP 服务器依赖
RUN /opt/conda/envs/researstudio/bin/pip install --no-cache-dir mcp aiohttp

# v5.1.24: Configure conda auto-activation for non-interactive shells
# Step 1: Create symlinks for direct binary access
RUN ln -sf /opt/conda/envs/researstudio/bin/python /usr/local/bin/python && \
    ln -sf /opt/conda/envs/researstudio/bin/python3 /usr/local/bin/python3 && \
    ln -sf /opt/conda/envs/researstudio/bin/pip /usr/local/bin/pip && \
    ln -sf /opt/conda/envs/researstudio/bin/pip3 /usr/local/bin/pip3 && \
    ln -sf /opt/conda/envs/researstudio/bin/pytest /usr/local/bin/pytest

# Step 2: Configure bash to activate conda in non-interactive mode
RUN echo '. /opt/conda/etc/profile.d/conda.sh && conda activate researstudio' >> /root/.bashrc && \
    echo '. /opt/conda/etc/profile.d/conda.sh && conda activate researstudio' >> /etc/bash.bashrc

# 安装 Node.js (用于 Claude Code CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g @anthropic-ai/claude-code && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /app/target/release/server /usr/local/bin/server

# Create non-root user for Claude Code (v5.1.28 - fix root + skip-permissions conflict)
RUN groupadd -r claude && useradd -r -g claude -m -d /home/claude claude

# Create working directories with proper permissions
RUN mkdir -p /repos /writing && \
    chown -R claude:claude /repos /writing

# Configure conda and npm for non-root user
RUN mkdir -p /home/claude/.npm /home/claude/.config && \
    chown -R claude:claude /home/claude && \
    echo '. /opt/conda/etc/profile.d/conda.sh && conda activate researstudio' >> /home/claude/.bashrc

# Set runtime environment
ENV HOST=0.0.0.0
ENV PORT=3000
ENV SHELL=/bin/bash
ENV PYTHONPATH="/writing/modules:/writing"
# v5.1.24: Force bash to source bashrc in non-interactive shells
ENV BASH_ENV=/home/claude/.bashrc
ENV HOME=/home/claude
EXPOSE 3000

# Set working directory
WORKDIR /repos

# Switch to non-root user for Claude Code execution
USER claude

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider "http://${HOST:-localhost}:${PORT:-3000}/api/health" || exit 1

# Run the application
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["server"]
