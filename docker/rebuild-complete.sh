#!/bin/bash
# Complete rebuild with all optimizations
# v5.4.2 - Clash proxy + Rust mirror + Stable toolchain

set -e

cd /Users/liuzf/writing/opensource/vibe-kanban

echo "🚀 Vibe-Kanban Complete Rebuild v5.4.2"
echo "========================================"
echo ""
echo "✅ Configuration Applied:"
echo "  - Rust toolchain: stable (reliable)"
echo "  - Rust mirror: Tsinghua (24.4 MB/s)"
echo "  - Clash proxy: http://host.docker.internal:7897"
echo "  - APT source: Official Debian (via proxy)"
echo ""

# Kill any existing build
echo "🛑 Stopping any existing build..."
docker-compose kill vibe-kanban 2>/dev/null || true

# Clean up
echo "🧹 Cleaning up..."
docker-compose rm -f vibe-kanban 2>/dev/null || true

# Build with full optimizations
echo ""
echo "🔨 Starting build (this will take 15-20 minutes)..."
echo ""

docker-compose build vibe-kanban \
  --build-arg HTTP_PROXY=http://host.docker.internal:7897 \
  --build-arg HTTPS_PROXY=http://host.docker.internal:7897 \
  --no-cache 2>&1 | tee /tmp/vibe-build-final.log

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📊 Build Summary:"
    echo "  - Image size: $(docker images writing-vibe-kanban:latest --format '{{.Size}}')"
    echo "  - Created: $(docker images writing-vibe-kanban:latest --format '{{.CreatedAt}}')"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Restart container:"
    echo "     cd /Users/liuzf/writing && docker-compose up -d vibe-kanban"
    echo ""
    echo "  2. Check status:"
    echo "     docker-compose ps vibe-kanban"
    echo ""
    echo "  3. View logs:"
    echo "     docker-compose logs -f vibe-kanban | tail -50"
    echo ""
    echo "  4. Test Claude Code CLI:"
    echo "     docker exec academic_vibe_kanban claude --version"
else
    echo ""
    echo "❌ Build failed! Check logs:"
    echo "   tail -100 /tmp/vibe-build-final.log"
    exit 1
fi
