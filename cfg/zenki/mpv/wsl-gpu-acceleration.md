# MPV GPU Acceleration in Debian WSL

## GPU Video Output in mpv on WSL

**Yes, mpv can use GPU-accelerated video output (VO) in Debian WSL with your RTX 3060**, but there are some important caveats and configuration steps required.

## Current Status & Limitations

**WSLg supports GPU video acceleration via VA-API** through the D3D12 Mesa Gallium driver. GeForce RTX 20/30 series (including RTX 3060) are officially supported with driver version 526.47+. However, **GPU video output (`--vo=gpu`) works with limitations**:

- **Hardware decoding (`--hwdec`)** works well via VA-API/NVDEC
- **Basic GPU rendering** works for playback in X11/Wayland windows
- **Advanced compositing/texture-sharing** has known issues (DRI3 limitations in WSLg)

A recent GitHub issue (October 2025) confirms that while mpv can play videos smoothly with GPU acceleration, **embedding GPU-rendered video into other applications (like Flutter) fails due to WSLg's lack of DRI3 support for zero-copy texture sharing**.

## Configuration Steps

### 1. Enable WSLg GPU Video Acceleration

First, verify your environment supports VA-API:

```bash
# Install VA-API tools
sudo apt install vainfo mesa-va-drivers

# Set environment variables (add to ~/.bashrc)
export GALLIUM_DRIVER=d3d12
export LIBVA_DRIVER_NAME=d3d12
export MESA_D3D12_DEFAULT_ADAPTER_NAME=nvidia

# Test VA-API support
vainfo
```

You should see output showing **VA-API version**, **Mesa Gallium driver for D3D12**, and supported profiles (H264, HEVC, etc.).

### 2. Configure mpv for GPU Acceleration

Create or edit `~/.config/mpv/mpv.conf`:

```conf
# Hardware decoding
hwdec=auto

# GPU video output
vo=gpu

# For better compatibility in WSL, try:
# vo=gpu-next
# gpu-api=vulkan
# gpu-context=wayland
```

**Test playback:**

```bash
# Basic test with environment variables
GALLIUM_DRIVER=d3d12 LIBVA_DRIVER_NAME=d3d12 \
MESA_D3D12_DEFAULT_ADAPTER_NAME=nvidia \
mpv your_video.mp4
```

When working correctly, mpv's terminal output will show:
```
Using hardware decoding (vaapi).
VO: [gpu] 1920x1080 vaapi
```

## Troubleshooting

### If video plays but with software decoding:

Try explicitly setting the hardware decoder:
```bash
mpv --hwdec=vaapi --vo=gpu video.mp4
```

Or for NVIDIA-specific decoding:
```bash
mpv --hwdec=nvdec --vo=gpu video.mp4
```

### If you see DRI3 warnings:

This is **expected in WSLg** and doesn't necessarily prevent playback—it only affects advanced texture-sharing scenarios. Basic mpv playback should still work.

### Monitor GPU usage:

```bash
# Install nvidia monitoring tools
sudo apt install nvidia-utils-535  # or your driver version

# Watch GPU activity while playing video
watch -n 1 nvidia-smi
```

You should see **GPU utilization** and **video decode engine activity** when hardware acceleration is working.

## What Works vs. What Doesn't

| Feature | Status | Notes |
|---------|--------|-------|
| **Hardware video decoding** | ✅ Works | VA-API/NVDEC supported via D3D12 backend |
| **GPU video output (basic)** | ✅ Works | `--vo=gpu` renders in X11/Wayland windows |
| **4K/high-bitrate playback** | ⚠️ Depends | Profile/level limitations apply (High 4:2:2, >50Mbps may fail) |
| **Texture sharing/compositing** | ❌ Limited | DRI3 not supported; embedding in other apps fails |
| **Vulkan rendering** | ⚠️ Partial | Requires WSL kernel >= 5.15, may have performance impact |

## WSL Mode Implementation Notes

For Protocol-7 mpv zenka, consider implementing:
1. **Runtime detection** of WSL environment (`grep -i microsoft /proc/version`)
2. **Automatic fallback** from advanced GPU features to basic VA-API if in WSL
3. **Environment variable injection** for D3D12 driver when running video playback commands
4. **Optional WSL mode flag** in zenka config to explicitly enable/disable WSL optimizations

#,,,,,...,,.,,,,.,.,.,,..,,,,,,,,,,..,...,..,,..,,...,...,,..,..,,,.,,.,.,,..,
#C722UGPAX5MGMR5DRB44YDI276F3VLQZHSMSIQL3RJ6GKQXSOIX2V5EUAU4WJWG2ZYSLVA3NSESXS
#\\\|HIFOYPRUW5N7G5BV6K7CXAEXKENXEQCDZJNFMRRHLSX2DYJIUPZ \ / AMOS7 \ YOURUM ::
#\[7]XBQGEMGNCCRJB4YSS44MIYAWPMKFFFXUT4ICEJIOTNLHVIANJKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
