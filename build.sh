#!/bin/bash

# ZMK Firmware Build Script
# Builds both left and right halves of the Corne keyboard

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BOARD="nice_nano_v2"
SHIELDS=("corne_left nice_view_adapter nice_view" "corne_right nice_view_adapter nice_view")
CONFIG_DIR="$(pwd)/config"
APP_DIR="$(pwd)/zmk/app"
FIRMWARE_DIR="$(pwd)/firmware"

# Check if we're in the right directory
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}Error: zmk/app directory not found. Are you in the zmk-config root?${NC}"
    exit 1
fi

# Set up environment variables
export ZEPHYR_SDK_INSTALL_DIR="${ZEPHYR_SDK_INSTALL_DIR:-$HOME/zephyr-sdk-0.16.9}"
export ZEPHYR_TOOLCHAIN_VARIANT="${ZEPHYR_TOOLCHAIN_VARIANT:-zephyr}"

# Verify SDK is set up
if [ ! -d "$ZEPHYR_SDK_INSTALL_DIR" ]; then
    echo -e "${RED}Error: Zephyr SDK not found at $ZEPHYR_SDK_INSTALL_DIR${NC}"
    echo "Please set ZEPHYR_SDK_INSTALL_DIR or install the SDK."
    exit 1
fi

echo -e "${GREEN}=== ZMK Firmware Build Script ===${NC}"
echo "Board: $BOARD"
echo "Config: $CONFIG_DIR"
echo "SDK: $ZEPHYR_SDK_INSTALL_DIR"
echo ""

# Create firmware output directory
mkdir -p "$FIRMWARE_DIR"

# Build function
build_shield() {
    local shield=$1
    # Sanitize shield name for directory (replace spaces with underscores)
    local shield_sanitized=$(echo "$shield" | tr ' ' '_')
    local build_dir="$APP_DIR/build_${shield_sanitized}"
    
    echo -e "${YELLOW}Building $shield...${NC}"
    
    # Clean previous build for this shield
    if [ -d "$build_dir" ]; then
        rm -rf "$build_dir"
    fi
    
    # Build
    cd "$APP_DIR"
    west build -b "$BOARD" \
        --build-dir "$build_dir" \
        -- -DSHIELD="$shield" \
           -DZMK_CONFIG="$CONFIG_DIR"
    
    # Copy firmware to output directory
    local firmware_file="$build_dir/zephyr/zmk.uf2"
    local output_file="$FIRMWARE_DIR/${shield_sanitized}.uf2"
    
    if [ -f "$firmware_file" ]; then
        cp "$firmware_file" "$output_file"
        local size=$(ls -lh "$output_file" | awk '{print $5}')
        echo -e "${GREEN}✓ Built $shield: $output_file ($size)${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to build $shield${NC}"
        return 1
    fi
}

# Build all shields
failed=0
for shield in "${SHIELDS[@]}"; do
    if ! build_shield "$shield"; then
        failed=$((failed + 1))
    fi
    echo ""
done

# Summary
echo -e "${GREEN}=== Build Summary ===${NC}"
if [ $failed -eq 0 ]; then
    echo -e "${GREEN}All builds completed successfully!${NC}"
    echo ""
    echo "Firmware files:"
    ls -lh "$FIRMWARE_DIR"/*.uf2 2>/dev/null || echo "No firmware files found"
    exit 0
else
    echo -e "${RED}$failed build(s) failed${NC}"
    exit 1
fi

