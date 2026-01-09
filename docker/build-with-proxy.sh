#!/bin/bash
# Rebuild vibe-kanban with Clash proxy support
# Detected Clash Verge on port 7897

set -e

echo "🚀 Building vibe-kanban with Clash proxy acceleration"
echo "======================================================"
echo ""
echo "Detected Configuration:"
echo "  - Clash proxy: http://host.docker.internal:7897"
echo "  - Rust mirror: Tsinghua (24.4 MB/s)"
echo "  - APT source: Official Debian (via proxy)"
echo ""

cd /Users/liuzf/writing/opensource/vibe-kanban

# Build with proxy
docker-compose build vibe-kanban \
  --build-arg HTTP_PROXY=http://host.docker.internal:7897 \
  --build-arg HTTPS_PROXY=http://host.docker.internal:7897 \
  --no-cache

echo ""
echo "✅ Build complete!"
echo ""
echo "Next steps:"
echo "  1. Restart container: docker-compose up -d vibe-kanban"
echo "  2. Check status: docker-compose ps vibe-kanban"
echo "  3. View logs: docker-compose logs -f vibe-kanban"
