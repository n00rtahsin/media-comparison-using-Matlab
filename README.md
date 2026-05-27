<div align="center">

<!-- BANNER -->
<img src="https://img.shields.io/badge/MATLAB-R2021b%2B-0076A8?style=for-the-badge&logo=mathworks&logoColor=white"/>
<img src="https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge"/>
<img src="https://img.shields.io/badge/Version-2.0-00d4d4?style=for-the-badge"/>
<img src="https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-7c3aed?style=for-the-badge"/>

<br/><br/>

# 🎞️ MediaVision Comparison Suite

### *A professional-grade MATLAB toolkit for structural similarity analysis, spatial difference detection, and temporal video analytics — all through a polished dark-themed interactive GUI.*

<br/>

[Features](#-features) · [Screenshots](#-screenshots) · [Requirements](#-requirements) · [Installation](#-installation) · [Quick Start](#-quick-start) · [Architecture](#-architecture) · [API Reference](#-api-reference) · [Contributing](#-contributing)

</div>

---

## 📖 Overview

**MediaVision Comparison Suite v2.0** is a comprehensive MATLAB application for comparing batches of images and videos using perceptual quality metrics. At its core, the tool computes the **Structural Similarity Index (SSIM)** across all pairs of loaded media, visualises the results as an interactive colour-coded heatmap, highlights spatial regions of difference with bounding-box overlays, and performs frame-by-frame temporal analysis on video files — all without writing a single command-line call.

Whether you are a researcher validating image compression artefacts, an engineer monitoring camera feeds for scene changes, a scientist comparing experimental microscopy outputs, or a developer testing rendering pipelines, MediaVision gives you instant, quantitative visual insight.

---

## ✨ Features

### 🖥️ Interactive Dark-Themed GUI
A single-window application built with MATLAB's `uifigure` / `uicontrol` framework, styled with a professional near-black palette and electric-cyan accent colours. Everything is mouse-driven — no scripting required for end-to-end analysis.

### 📊 SSIM-Based Similarity Matrix
Computes a full **N × N similarity matrix** across every loaded file pair using MATLAB's `ssim()` function (Image Processing Toolbox). Results are normalised to a 0–100% scale and rendered as a perceptually meaningful heatmap. The diagonal is always 100% (self-similarity); off-diagonal values quantify how structurally similar any two media files are.

### 🔍 Spatial Difference Detection
For any selected pair of files, the tool:
1. Registers the two images using **phase-correlation** (`imregcorr`) to correct translational camera drift.
2. Computes a per-pixel absolute difference map via `imabsdiff`.
3. Binarises the map using a user-controlled threshold to isolate changed pixels.
4. Removes noise with morphological operations (`bwareaopen`, `imdilate`).
5. Locates connected difference regions with `regionprops` and draws **red bounding boxes** over a colour overlay using `insertShape`.

### 🎬 Temporal Video Analysis
For video files, the suite samples up to **120 uniformly-spaced frames**, then computes consecutive-frame SSIM scores to produce a time-series plot. Anomalous frames (those where SSIM drops below a user-set threshold) are automatically detected, marked with red scatter points on the plot, and displayed side-by-side with their difference overlay — ideal for scene-change detection and video quality monitoring.

### ⚙️ Configurable Parameters (Live Sliders)
| Parameter | Range | Default | Effect |
|---|---|---|---|
| Target Resolution | 256² / 512² / 768² / 1024² | 512 × 512 | Uniform resize target before all processing |
| SSIM Anomaly Threshold | 0.30 – 0.95 | 0.70 | Frame pairs below this value are flagged in video analysis |
| Diff Sensitivity (Binarize) | 0.01 – 0.30 | 0.05 | Pixel difference magnitude required to count as "changed" |

All slider values update live labels in the GUI and are immediately applied to the next pipeline run.

### 📂 Flexible File Loading
- **Folder scan**: Recursively finds all supported image and video files in a chosen directory.
- **Individual file picker**: Multi-select file browser to add specific files across different locations.
- **Batch processing**: The `runBatchComparison()` standalone function processes an entire folder headlessly, exports a CSV of all similarity scores, saves a heatmap PNG, and exports the most-dissimilar pair's difference overlay — no GUI needed.

### 🖨️ Headless / Scripted API
`MediaVisionHelpers.m` exposes a clean set of standalone functions that mirror the GUI's processing pipeline with zero figure dependencies:

```matlab
pct = compareTwoImages('before.png', 'after.png', [512 512]);
runBatchComparison('C:/images', [512 512], 'C:/results');
runSyntheticDemo();   % verify the toolchain without any real files
```

---

## 📸 Screenshots

| Similarity Heatmap | Difference Viewer |
|---|---|
| ![Heatmap](similarity%20matrix%20_heatmap.png) | ![Diff Viewer](diff%20viewer.png) |

> *Left: SSIM similarity matrix rendered as a cyan–amber heatmap. Each cell displays the percentage score. Right: Three-pane difference viewer showing Image A, registered Image B, and the bounding-box difference overlay.*

---

## 🔧 Requirements

### MATLAB Version
- **MATLAB R2021b or later** (recommended: R2023a+)

### Required Toolboxes
| Toolbox | Used For |
|---|---|
| **Image Processing Toolbox** | `ssim`, `imresize`, `imregcorr`, `imwarp`, `imabsdiff`, `imbinarize`, `bwareaopen`, `imdilate`, `regionprops`, `im2double`, `rgb2gray` |
| **Computer Vision Toolbox** | `insertShape` (bounding-box overlays), `VideoReader` frame iteration |

### Supported File Formats

**Images:** `.jpg` / `.jpeg` · `.png` · `.bmp` · `.tif` / `.tiff`

**Videos:** `.mp4` · `.avi` · `.mov` · `.mkv` · `.wmv`

### System
- **OS:** Windows, macOS, or Linux (any platform that runs MATLAB)
- **RAM:** At least 4 GB recommended for 512 × 512 batches of 20+ files; 8 GB+ for 1024 × 1024

---

## 📥 Installation

```bash
# 1. Clone the repository
git clone https://github.com/n00rtahsin/media-comparison-using-Matlab.git

# 2. Open MATLAB and navigate to the project directory
cd media-comparison-using-Matlab
```

No additional package installation, `mex` compilation, or external dependencies are required. Both `.m` files must be in the same directory (or on the MATLAB path).

**Add to MATLAB path permanently (optional):**
```matlab
addpath(genpath('/path/to/media-comparison-using-Matlab'));
savepath;
```

---

## 🚀 Quick Start

### Launch the GUI

```matlab
MediaComparisonTool
```

The 1280 × 780 application window will open immediately.

### Step-by-Step Workflow

```
1. [+] Select Media Folder  →  Point to a directory of images/videos
2. [>] PRE-PROCESS ALL      →  Resize, grayscale-convert, and cache all frames
3. [>] COMPUTE SIMILARITY   →  Build the N×N SSIM matrix and render the heatmap
4. [>] SHOW DIFFERENCES     →  Auto-locate the most dissimilar pair and visualise it
5. [>] ANALYZE VIDEOS       →  Run temporal frame-by-frame SSIM on all videos

— or —

[*] RUN FULL PIPELINE       →  All four steps in a single click
```

### Scripted / Headless Usage

```matlab
% Compare two specific images
pct = compareTwoImages('imageA.png', 'imageB.png', [512 512]);
fprintf('Similarity: %.1f%%\n', pct);

% Batch-process an entire folder and save results to disk
runBatchComparison('C:/my_images', [512 512], 'C:/results');
% → Produces: similarity_matrix.csv
%             similarity_heatmap.png
%             most_dissimilar_pair_diff.png

% Run the built-in synthetic demo (no real files needed)
runSyntheticDemo();
```

---

## 🏗️ Architecture

The project is split across two files with a clear separation of concerns:

```
media-comparison-using-Matlab/
│
├── MediaComparisonTool.m       # Main entry point + full GUI application
│   ├── MediaComparisonTool()   # Entry function — builds and launches the window
│   │
│   ├── SECTION 1 — GUI Construction
│   │   ├── buildHeader()           Dark banner with cyan branding
│   │   ├── buildControlPanel()     Left panel: file I/O, sliders, run buttons
│   │   ├── buildDisplayArea()      Right panel: 4-tab display (heatmap, diff, video, log)
│   │   └── buildStatusBar()        Bottom strip: live status + file count
│   │
│   ├── SECTION 2 — GUI Callbacks
│   │   ├── onSelectFolder()        Folder browser → scan for media files
│   │   ├── onAddFiles()            Multi-select file picker
│   │   ├── onClearFiles()          Reset all state
│   │   ├── onSliderUpdate()        Live slider → label sync
│   │   ├── onPreProcess()          Load + grayscale + resize all files
│   │   ├── onComputeSimilarity()   Build N×N SSIM matrix + render heatmap
│   │   ├── onComparePair()         Align + diff overlay for selected pair
│   │   ├── onShowDifferences()     Auto-select most dissimilar pair
│   │   ├── onAnalyzeSingleVideo()  Temporal SSIM plot for one video
│   │   ├── onAnalyzeVideos()       Batch temporal analysis for all videos
│   │   ├── onRunFull()             Full pipeline in one click
│   │   └── onClose()               Graceful exit with confirmation dialog
│   │
│   └── SECTION 3 — Core Processing (modular, testable helpers)
│       ├── loadAndPreProcessImage()    imread → rgb2gray → imresize → im2double
│       ├── loadAndPreProcessVideo()    VideoReader → sample ≤120 frames → 3D array
│       ├── getRepresentativeFrame()    2D/3D dispatcher
│       ├── calculateSimilarity()       ssim() wrapper → [-1,+1] score
│       ├── alignImages()               Phase-correlation via imregcorr + imwarp
│       ├── highlightDifferences()      imabsdiff → binarize → morphology → insertShape
│       ├── renderHeatmap()             imagesc + custom colormap + numeric annotations
│       ├── processVideoFrames()        Temporal SSIM plot + anomaly detection
│       ├── refreshFileList()           Sync listbox with app state
│       ├── updateStatus()              Status bar text update
│       ├── logMsg()                    Append timestamped line to log tab
│       ├── isVideoFile()               Extension-based file type predicate
│       ├── findVideoIndex()            Map video popup index → file list index
│       └── iif()                       Inline ternary helper
│
└── MediaVisionHelpers.m         # Standalone / headless API (no GUI required)
    ├── compareTwoImages()           Full pipeline → similarity % for any two images
    ├── runBatchComparison()         Folder → CSV + heatmap PNG + diff overlay PNG
    ├── loadAndPreProcessImage_standalone()
    ├── alignImages_standalone()
    ├── highlightDifferences_standalone()
    ├── renderHeatmap_standalone()
    └── runSyntheticDemo()          Self-contained demo with generated test images
```

### Data Flow

```
Loaded Files (cell array of paths)
        │
        ▼
  loadAndPreProcess[Image|Video]()
        │  • rgb2gray  (ITU-R BT.601 luma)
        │  • imresize  (bicubic)
        │  • im2double (→ [0,1])
        ▼
processedData (cell: 2D frames or 3D [H×W×T] stacks)
        │
        ├──► getRepresentativeFrame() ──► calculateSimilarity()
        │                                       │ ssim() → [-1,+1]
        │                                       ▼
        │                               simMatrix (N×N, %)
        │                                       │
        │                               renderHeatmap()
        │
        └──► alignImages()  ──────────► highlightDifferences()
                 imregcorr                  imabsdiff
                 imwarp                     imbinarize
                                            bwareaopen / imdilate
                                            regionprops
                                            insertShape (RGB overlay)
```

---

## 📐 Algorithm Details

### Structural Similarity Index (SSIM)

SSIM measures perceptual image quality by comparing three local statistics computed over an 11 × 11 Gaussian sliding window:

```
SSIM(A, B) = l(A,B) · c(A,B) · s(A,B)

where:
  l(A,B) = (2·μA·μB + C₁) / (μA² + μB² + C₁)          [luminance]
  c(A,B) = (2·σA·σB + C₂) / (σA² + σB² + C₂)            [contrast]
  s(A,B) = (σAB  + C₃)    / (σA·σB + C₃)                 [structure]

  C₁ = (0.01·L)²,  C₂ = (0.03·L)²,  C₃ = C₂/2
  L  = dynamic range (1.0 for [0,1] normalised images)
```

SSIM ∈ [−1, +1]. The tool converts this to a percentage with:

```
Similarity % = (SSIM + 1) / 2 × 100
```

This maps SSIM −1 → 0% and SSIM +1 → 100%, giving an intuitive 0–100 scale.

### Phase-Correlation Image Registration

Before computing differences, moving images are aligned to the reference using `imregcorr` with the `'translation'` model. The cross-power spectrum in the Fourier domain reveals the dominant shift vector (Δx, Δy):

```
R(u,v) = F{A}(u,v) · conj(F{B}(u,v))
         ─────────────────────────────
         |F{A}(u,v) · conj(F{B}(u,v))|
```

`imwarp` then applies the recovered `affine2d` transform with bilinear resampling, snapping the moving image into the reference coordinate frame.

### Difference Highlighting Pipeline

```
|A − B|  →  imbinarize(threshold)  →  bwareaopen(50 px)
   →  imdilate(disk-5)  →  regionprops('BoundingBox')
   →  insertShape(RGB overlay, red boxes, lineWidth=3)
```

The `diffSensitivity` slider directly controls the `imbinarize` threshold; lower values surface subtle differences while higher values suppress noise.

### Video Temporal Analysis

Up to 120 frames are uniformly sampled from each video (`step = floor(totalFrames / 120)`). Consecutive-frame SSIM scores are plotted as a time series. Frames whose SSIM drops below `ssimThreshold` (set via slider) are flagged as anomalies, displayed as red dots on the plot, and shown side-by-side with their difference overlay.

---

## 📚 API Reference

### `MediaComparisonTool()`
Launches the full interactive GUI. No arguments required.

```matlab
MediaComparisonTool
```

---

### `compareTwoImages(pathA, pathB, targetSize)`
Computes and returns the SSIM-based similarity percentage between two image files.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `pathA` | `char` | — | Full path to the first image |
| `pathB` | `char` | — | Full path to the second image |
| `targetSize` | `[1×2 double]` | `[512 512]` | Resize target `[rows cols]` |

**Returns:** `ssimPct` — scalar double in [0, 100]

```matlab
pct = compareTwoImages('img1.jpg', 'img2.jpg');
pct = compareTwoImages('img1.jpg', 'img2.jpg', [256 256]);
```

---

### `runBatchComparison(folderPath, targetSize, outputFolder)`
Headless batch processor. Scans `folderPath` for all supported images, computes the full N×N similarity matrix, and saves results.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `folderPath` | `char` | — | Directory containing input images |
| `targetSize` | `[1×2 double]` | `[512 512]` | Uniform resize target |
| `outputFolder` | `char` | `<folderPath>/MediaVision_Output` | Where to write output files |

**Outputs written to `outputFolder`:**
- `similarity_matrix.csv` — N×N similarity scores with named rows/columns
- `similarity_heatmap.png` — Rendered heatmap (150 DPI)
- `most_dissimilar_pair_diff.png` — Difference overlay of the least-similar pair

```matlab
runBatchComparison('C:/dataset', [512 512], 'C:/results');
```

---

### `runSyntheticDemo()`
Executes a complete self-contained demonstration using synthetically generated images. Requires no real files. Opens three figure windows: similarity heatmap, difference viewer, and temporal analysis plot.

```matlab
runSyntheticDemo();
```

---

## 🎛️ GUI Reference

### Left Control Panel

| Section | Control | Description |
|---|---|---|
| **Input / Output** | `[+] Select Media Folder` | Opens folder browser; scans recursively for all supported extensions |
| | `[+] Add Individual Files` | Multi-select file picker to append specific files |
| | `[-] Clear All Files` | Resets all state, clears all axes |
| **Pre-Processing** | Resolution popup | Sets the uniform resize target (256² / 512² / 768² / 1024²) |
| **Analysis Settings** | SSIM Anomaly Threshold slider | Frames/pairs with SSIM below this are flagged |
| | Diff Sensitivity slider | Binarisation threshold for the pixel-difference mask |
| **Run Pipeline** | `[>] PRE-PROCESS ALL` | Loads, converts, resizes, and caches all files |
| | `[>] COMPUTE SIMILARITY` | Builds N×N SSIM matrix and renders the heatmap |
| | `[>] SHOW DIFFERENCES` | Auto-selects most dissimilar pair and opens diff viewer |
| | `[>] ANALYZE VIDEOS` | Batch temporal SSIM analysis for all loaded videos |
| | `[*] RUN FULL PIPELINE` | Executes all four steps in sequence |
| **Loaded Files** | File listbox | Shows all currently loaded file names |

### Right Display Tabs

| Tab | Contents |
|---|---|
| **Similarity Heatmap** | Annotated colour-coded N×N SSIM matrix. Cyan = high similarity, red = low similarity. |
| **Difference Viewer** | Pair-selector dropdowns + three axes: Image A (aligned), Image B (registered), Difference Overlay. |
| **Video Analysis** | File selector + `ANALYZE VIDEO` button. SSIM time-series plot with anomaly markers + two frame preview axes. |
| **Processing Log** | Timestamped log of all pipeline steps, file loads, and computed scores. |

### Status Bar

- **Left:** Current pipeline status message
- **Right:** Total number of currently loaded files

---

## 💡 Usage Examples

### Compare Two Product Photos
```matlab
pct = compareTwoImages('product_v1.jpg', 'product_v2.jpg', [512 512]);
if pct > 95
    disp('Images are nearly identical.');
elseif pct > 70
    disp('Minor differences detected.');
else
    disp('Significant visual differences found.');
end
```

### Batch Quality Check on a Test Dataset
```matlab
runBatchComparison( ...
    '/data/renders_batch_42', ...
    [512 512], ...
    '/results/batch_42_report' ...
);
```

### Programmatic Difference Overlay
```matlab
% Standalone — no GUI required
imgA = loadAndPreProcessImage_standalone('before.png', [512 512]);
imgB = loadAndPreProcessImage_standalone('after.png',  [512 512]);
imgB_aligned = alignImages_standalone(imgA, imgB);
[overlay, regions] = highlightDifferences_standalone(imgA, imgB_aligned, 0.04);

imshow(overlay);
title(sprintf('%d changed regions detected', numel(regions)));
```

---

## 🗂️ Repository Structure

```
media-comparison-using-Matlab/
├── MediaComparisonTool.m          Main GUI application  (1 314 lines, 50.5 KB)
├── MediaVisionHelpers.m           Standalone helper API   (335 lines, 12.7 KB)
├── diff viewer.png                Example: difference overlay screenshot
├── similarity matrix _heatmap.png Example: SSIM heatmap screenshot
├── README.md                      This file
└── LICENSE                        MIT License
```

---

## ⚠️ Known Limitations

- **Phase-correlation registration** corrects translational shifts only. For rotation or perspective distortion, replace the `'translation'` model in `alignImages()` with `'rigid'` or `'similarity'`.
- **Video sampling** is capped at 120 frames for memory efficiency. Very long videos (>10 min at 30 fps) will have coarser temporal resolution.
- **Batch similarity** is computed on each file's first representative frame. For a more robust video-to-video score, the function can be extended to average SSIM across multiple sampled frames.
- **Large batches** (N > 30 at 1024²) may be slow due to the O(N²) comparison loop. Consider using the 256² resolution setting for rapid screening.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes: `git commit -m 'Add: description of change'`
4. Push to the branch: `git push origin feature/your-feature-name`
5. Open a Pull Request

### Ideas for Future Contributions
- Add PSNR and MS-SSIM metrics alongside SSIM
- Export full PDF report from the GUI
- Support rotation-invariant registration (`'rigid'` model option)
- Add a progress bar / `waitbar` during batch processing
- Export video temporal analysis as an animated GIF

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

- **MathWorks** for the Image Processing and Computer Vision Toolboxes that power the core algorithms
- The SSIM algorithm: Wang, Z., Bovik, A. C., Sheikh, H. R., & Simoncelli, E. P. (2004). *Image quality assessment: from error visibility to structural similarity.* IEEE Transactions on Image Processing, 13(4), 600–612.

---

<div align="center">

Made with ❤️ in MATLAB &nbsp;·&nbsp; [Report a Bug](https://github.com/n00rtahsin/media-comparison-using-Matlab/issues) &nbsp;·&nbsp; [Request a Feature](https://github.com/n00rtahsin/media-comparison-using-Matlab/issues)

</div>
