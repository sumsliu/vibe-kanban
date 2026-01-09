#!/bin/bash
# Smart Mirror Selection Script with Fallback
# Auto-selects fastest available mirror for Debian APT packages

set -e

echo "🔍 Testing Debian mirrors for best connectivity..."

# Define mirrors with priority order
declare -A mirrors=(
    ["deb.debian.org"]="Official Debian (default)"
    ["mirrors.tuna.tsinghua.edu.cn"]="Tsinghua Mirror (CN)"
    ["mirrors.ustc.edu.cn"]="USTC Mirror (CN)"
    ["mirrors.aliyun.com"]="Aliyun Mirror (CN)"
    ["mirrors.163.com"]="NetEase Mirror (CN)"
)

# Test mirror connectivity
test_mirror() {
    local mirror=$1
    local timeout=5

    # Test Release file accessibility
    if timeout $timeout curl -sf "http://${mirror}/debian/dists/bookworm/Release" > /dev/null 2>&1; then
        # Measure response time
        local time_ms=$(timeout $timeout curl -w "%{time_total}" -o /dev/null -sf "http://${mirror}/debian/dists/bookworm/Release" 2>&1)
        echo "$time_ms"
        return 0
    else
        echo "999.999"  # Unreachable
        return 1
    fi
}

# Find fastest available mirror
best_mirror="deb.debian.org"
best_time="999.999"

for mirror in "${!mirrors[@]}"; do
    echo "  Testing: ${mirrors[$mirror]} ($mirror)"
    time=$(test_mirror "$mirror")

    if (( $(echo "$time < $best_time" | bc -l) )); then
        best_mirror="$mirror"
        best_time="$time"
        echo "    ✅ Responsive (${time}s) - New best!"
    elif [ "$time" = "999.999" ]; then
        echo "    ❌ Unreachable"
    else
        echo "    ✅ Responsive (${time}s)"
    fi
done

echo ""
echo "🎯 Selected mirror: ${mirrors[$best_mirror]} ($best_mirror)"
echo "   Response time: ${best_time}s"
echo ""

# Apply mirror if not using official
if [ "$best_mirror" != "deb.debian.org" ]; then
    echo "📝 Configuring APT to use $best_mirror..."

    # Backup original sources
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak
        sed -i "s|deb.debian.org|${best_mirror}|g" /etc/apt/sources.list.d/debian.sources
        echo "   ✅ Updated /etc/apt/sources.list.d/debian.sources"
    fi

    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        sed -i "s|deb.debian.org|${best_mirror}|g" /etc/apt/sources.list
        echo "   ✅ Updated /etc/apt/sources.list"
    fi
else
    echo "✅ Using official Debian mirror (no changes needed)"
fi

echo ""
echo "✅ Mirror selection complete!"
