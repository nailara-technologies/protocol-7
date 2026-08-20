# OpenCV Zenka Design

## Overview
GPU-accelerated computer vision zenka providing OpenCV bindings for Protocol-7.

## Dependencies

### Debian Packages
- `libopencv-core-dev`
- `libopencv-imgproc-dev`
- `libopencv-imgcodecs-dev`
- `libopencv-videoio-dev`
- `libopencv-objdetect-dev`
- `libopencv-dnn-dev`

### CPAN Modules
- `PDL::OpenCV` - Perl Data Language bindings for OpenCV
- `PDL::OpenCV::Imgproc` - Image processing
- `PDL::OpenCV::Imgcodecs` - Image codecs
- `PDL::OpenCV::Objdetect` - Object detection
- `PDL::OpenCV::Dnn` - Deep neural networks
- `PDL::OpenCV::Tracking` - Object tracking

## Architecture

### Commands
```
opencv.features.detect <image> <method>    - Detect features (SIFT, SURF, ORB)
opencv.features.match <img1> <img2>         - Match features between images
opencv.faces.detect <image>                 - Face detection
opencv.objects.track <video> <roi>          - Object tracking in video
opencv.dnn.infer <model> <image>            - DNN inference
opencv.filter.apply <image> <filter>        - Apply filters (blur, sharpen, etc.)
opencv.transform.warp <image> <matrix>      - Perspective transformation
opencv.stereo.calibrate <images...>         - Stereo camera calibration
opencv.optical.flow <video>                 - Optical flow computation
```

## Integration Points

### With graphics-matrix
- Feature detection for enhanced similarity
- Face detection for identity-aware clustering
- Optical flow for video deduplication

### With lm-vision
- Pre-processing pipeline (resize, denoise, enhance)
- Region-of-interest extraction
- Attention heatmap generation

### With data zenka
- Feature vector storage in cubic topology
- Visual descriptor indexing
- Similarity graph construction

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] Create `cfg/zenki/opencv/start`
- [ ] Create `modules/opencv.init_code`
- [ ] Add to `base.known_dependencies`
- [ ] Add to `.deps/profiles.yaml`

### Phase 2: Feature Detection
- [ ] `opencv.cmd.features-detect`
- [ ] `opencv.cmd.features-match`
- [ ] `opencv.cmd.features-compare`

### Phase 3: Object Detection
- [ ] `opencv.cmd.faces-detect`
- [ ] `opencv.cmd.objects-detect`
- [ ] Integration with graphics-matrix for smart cropping

### Phase 4: Video Processing
- [ ] `opencv.cmd.video-track`
- [ ] `opencv.cmd.optical-flow`
- [ ] Frame deduplication pipeline

## Cubic Topology Mapping

```
Core (0):   Feature descriptors (128-512 dims)
Inner (1):  Object bounding boxes
Mid (2):    Region proposals
Outer (3):  Full frame features
Halo (4):   Temporal features
Nebula (5): Multi-frame sequences
Void (6):   Video streams
```

## Usage Examples

```bash
# Feature detection
p7c "opencv.features.detect /path/to/image.png ORB"

# Face detection with graphics-matrix dedup
p7c "opencv.faces.detect /path/to/photo.jpg" | \
    p7c "graphics-matrix.assert-similarity - -"

# DNN inference
p7c "opencv.dnn.infer /models/yolo.onnx /path/to/image.png"
```

---
*Design document for Protocol-7 OpenCV integration*

---
*Signature: 7VNKDBUU6DTBNJ2OK7EMV3WTD72AHBLQTAGMKOIKBZJI2NXDZOBQ*

#,,..,.,.,.,,,.,,,,..,,.,,,..,...,,.,,.,,,,..,..,,...,...,..,,...,,.,,,.,,.,.,
#CKDEFJOGR36N6KTNMDOQNNIKPQLCRYFFB4Y635EDTO6ALSMNBVOMCKAZQBJSU5FBTVDUSSIGW6KF2
#\\\|BMKPSOIBRZZ6BXDKCXQCN6GGQX6U4SAD4Y63II2MXWNFX7BJMGR \ / AMOS7 \ YOURUM ::
#\[7]HY65RO7QWQBKFAQRGE7B7HCCPMZEE4ZSHNE7EEFNUG6554Y4HCBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
