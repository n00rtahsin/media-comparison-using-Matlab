%% ========================================================================
%  MEDIAVISION — STANDALONE HELPER FUNCTIONS  (MediaVisionHelpers.m)
%
%  These functions can be called independently of the GUI for scripting,
%  batch processing, or integration into other workflows.
%
%  Usage example:
%    >> run MediaVisionDemo.m
%
%  Requires: Image Processing Toolbox, Computer Vision Toolbox
%% ========================================================================


function ssimPct = compareTwoImages(pathA, pathB, targetSize)
% =========================================================================
% COMPARE TWO IMAGES — returns similarity percentage (0–100).
%
%  Convenience wrapper for the full pipeline:
%   load → preprocess → align → SSIM → convert to %
%
%  EXAMPLE:
%   pct = compareTwoImages('photo1.jpg', 'photo2.jpg', [512 512]);
%   fprintf('Similarity: %.1f%%\n', pct);
% =========================================================================
    if nargin < 3, targetSize = [512 512]; end

    imgA = loadAndPreProcessImage_standalone(pathA, targetSize);
    imgB = loadAndPreProcessImage_standalone(pathB, targetSize);

    % Phase-correlation alignment (corrects minor camera shifts).
    imgB = alignImages_standalone(imgA, imgB);

    % SSIM score in [-1,+1] → convert to [0,100]%.
    rawSSIM = ssim(imgA, imgB);
    ssimPct = (rawSSIM + 1) / 2 * 100;
end


function runBatchComparison(folderPath, targetSize, outputFolder)
% =========================================================================
% BATCH COMPARISON — no GUI required.
%
%  Loads all images from folderPath, computes the full NxN similarity
%  matrix, saves a heatmap figure, and exports a CSV of scores.
%
%  EXAMPLE:
%   runBatchComparison('C:/myImages', [512 512], 'C:/results');
% =========================================================================
    if nargin < 2, targetSize   = [512 512]; end
    if nargin < 3, outputFolder = fullfile(folderPath, 'MediaVision_Output'); end

    if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end

    fprintf('[MediaVision] Scanning folder: %s\n', folderPath);

    % Gather image files only (videos handled separately).
    exts  = {'*.jpg','*.jpeg','*.png','*.bmp','*.tif'};
    files = {};
    for k = 1:numel(exts)
        found = dir(fullfile(folderPath, exts{k}));
        for j = 1:numel(found)
            files{end+1} = fullfile(found(j).folder, found(j).name); %#ok<AGROW>
        end
    end

    N = numel(files);
    if N < 2
        error('Need at least 2 images in the folder.');
    end
    fprintf('[MediaVision] Found %d images. Pre-processing...\n', N);

    % Pre-process all images.
    processed = cell(1, N);
    names     = cell(1, N);
    for k = 1:N
        processed{k} = loadAndPreProcessImage_standalone(files{k}, targetSize);
        [~, nm, ex]  = fileparts(files{k});
        names{k}     = [nm ex];
        fprintf('  Processed: %s\n', names{k});
    end

    % Compute similarity matrix.
    fprintf('[MediaVision] Computing %dx%d similarity matrix...\n', N, N);
    simMat = zeros(N, N);
    for i = 1:N
        for j = 1:N
            if i == j
                simMat(i,j) = 100;
            elseif j > i
                fA = processed{i};
                fB = alignImages_standalone(fA, processed{j});
                raw = ssim(fA, fB);
                pct = (raw + 1) / 2 * 100;
                simMat(i,j) = pct;
                simMat(j,i) = pct;
            end
        end
        fprintf('  Row %d/%d done.\n', i, N);
    end

    % Save similarity matrix as CSV.
    csvPath = fullfile(outputFolder, 'similarity_matrix.csv');
    T = array2table(simMat, 'VariableNames', ...
        matlab.lang.makeValidName(names), 'RowNames', names);
    writetable(T, csvPath, 'WriteRowNames', true);
    fprintf('[MediaVision] CSV saved: %s\n', csvPath);

    % Save heatmap figure.
    fig  = figure('Visible', 'off', 'Color', [0.10 0.10 0.13], ...
        'Position', [100 100 900 700]);
    hAx  = axes('Parent', fig);
    renderHeatmap_standalone(hAx, simMat, names);
    heatPath = fullfile(outputFolder, 'similarity_heatmap.png');
    exportgraphics(fig, heatPath, 'Resolution', 150);
    close(fig);
    fprintf('[MediaVision] Heatmap saved: %s\n', heatPath);

    % Identify and save the most dissimilar pair.
    mat2 = simMat;
    mat2(logical(eye(N))) = Inf;
    [~, idx] = min(mat2(:));
    [rr, cc] = ind2sub([N N], idx);
    fprintf('[MediaVision] Most dissimilar pair: %s vs %s (%.1f%%)\n', ...
        names{rr}, names{cc}, simMat(rr,cc));

    fA = processed{rr};
    fB = alignImages_standalone(fA, processed{cc});
    [diffOvl, ~] = highlightDifferences_standalone(fA, fB, 0.05);
    diffPath = fullfile(outputFolder, 'most_dissimilar_pair_diff.png');
    imwrite(diffOvl, diffPath);
    fprintf('[MediaVision] Difference overlay saved: %s\n', diffPath);

    fprintf('[MediaVision] Batch complete. Results in: %s\n', outputFolder);
end


%% -------------------------------------------------------------------------
%  INTERNAL STANDALONE HELPERS  (mirror the GUI app's Section 3 functions
%  but without any figure/handle dependencies)
%% -------------------------------------------------------------------------

function grayFrame = loadAndPreProcessImage_standalone(fpath, targetSize)
% Loads an image, converts to grayscale, resizes, normalises to [0,1].
    img = imread(fpath);
    if size(img, 3) == 3
        img = rgb2gray(img);   % ITU-R BT.601 luma conversion
    end
    img       = imresize(img, targetSize, 'bicubic');
    grayFrame = im2double(img);   % uint8 → double [0,1]
end


function alignedB = alignImages_standalone(refImg, movImg)
% Phase-correlation registration: finds and corrects translational shift.
    refU      = im2uint8(refImg);
    movU      = im2uint8(movImg);
    tform     = imregcorr(movU, refU, 'translation');
    Rfixed    = imref2d(size(refImg));
    alignedU  = imwarp(movU, tform, 'OutputView', Rfixed, 'Interp', 'bilinear');
    alignedB  = im2double(alignedU);
end


function [overlayRGB, regions] = highlightDifferences_standalone(imgA, imgB, threshold)
% Absolute-difference → binarize → regionprops → insertShape bounding boxes.
    if nargin < 3, threshold = 0.05; end

    diffMap  = imabsdiff(imgA, imgB);           % |A - B| per pixel
    binMask  = imbinarize(diffMap, threshold);  % changed pixels → 1
    binMask  = bwareaopen(binMask, 50);         % remove tiny noise blobs
    se       = strel('disk', 5);
    binMask  = imdilate(binMask, se);           % slight expansion

    regions  = regionprops(binMask, 'BoundingBox', 'Area');
    base     = repmat(uint8(imgA * 255), [1 1 3]);

    if ~isempty(regions)
        boxes      = vertcat(regions.BoundingBox);
        overlayRGB = insertShape(base, 'Rectangle', boxes, ...
            'Color', [255 0 0], 'LineWidth', 3);
    else
        overlayRGB = base;
    end
end


function renderHeatmap_standalone(hAx, simMat, names)
% Renders the similarity heatmap (headless / no dark theme needed).
    N = size(simMat, 1);
    imagesc(hAx, simMat, [0 100]);

    cmapData = interp1([0;50;100], ...
        [0.80 0.10 0.10; 0.90 0.80 0.00; 0.00 0.85 0.85], ...
        0:1:100, 'linear');
    colormap(hAx, cmapData);
    colorbar(hAx);

    shortNames = cellfun(@(n) n(1:min(12,end)), names, 'UniformOutput',false);
    set(hAx, 'XTick', 1:N, 'YTick', 1:N, ...
        'XTickLabel', shortNames, 'YTickLabel', shortNames, ...
        'XTickLabelRotation', 40, 'TickLabelInterpreter', 'none', ...
        'FontName', 'Consolas', 'FontSize', 8);

    for i = 1:N
        for j = 1:N
            val    = simMat(i,j);
            clr    = [1 1 1];
            if val >= 60, clr = [0.05 0.05 0.05]; end
            text(hAx, j, i, sprintf('%.0f%%', val), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment',   'middle', ...
                'FontName', 'Consolas', 'FontSize', 8, ...
                'FontWeight', 'bold', 'Color', clr);
        end
    end
    title(hAx, 'SSIM Similarity Matrix (%)', 'FontName', 'Consolas');
end


%% =========================================================================
%  DEMO SCRIPT  (runs without any real media files using synthetic data)
%% =========================================================================
% To execute the demo, uncomment the block below and run this file, OR
% call: runSyntheticDemo()

%  runSyntheticDemo();

function runSyntheticDemo()
% -------------------------------------------------------------------------
% SYNTHETIC DEMO — creates fake images in memory and runs the full
% pipeline so you can verify everything works before adding real files.
% -------------------------------------------------------------------------
    fprintf('\n========================================\n');
    fprintf('  MediaVision Comparison Suite — DEMO\n');
    fprintf('========================================\n\n');

    sz  = [256 256];
    rng(42);   % reproducible random seed

    % Generate 4 synthetic grayscale images with controlled differences.
    imgs = cell(1, 4);
    imgs{1} = im2double(uint8(rand(sz)*200 + 30));      % noisy mid-grey
    imgs{2} = imgs{1} + 0.05*randn(sz);                 % slight noise variant
    imgs{3} = imrotate(imgs{1}, 2, 'bilinear', 'crop'); % small rotation
    imgs{4} = 1 - imgs{1};                              % inverted — very different

    names = {'Img_A','Img_B','Img_C','Img_D'};
    N     = numel(imgs);

    % --- Similarity Matrix ---
    fprintf('[DEMO] Computing similarity matrix...\n');
    simMat = zeros(N,N);
    for i = 1:N
        for j = 1:N
            if i == j
                simMat(i,j) = 100;
            elseif j > i
                fA = imgs{i};
                fB = alignImages_standalone(fA, imgs{j});
                raw = ssim(fA, fB);
                pct = (raw + 1) / 2 * 100;
                simMat(i,j) = pct;
                simMat(j,i) = pct;
                fprintf('  %s vs %s: %.1f%%\n', names{i}, names{j}, pct);
            end
        end
    end

    % --- Heatmap ---
    fig1 = figure('Name', 'MediaVision Demo — Similarity Heatmap', ...
        'Color', [0.10 0.10 0.13]);
    hAx = axes('Parent', fig1, 'Color', [0.06 0.06 0.08], ...
        'XColor', [0.6 0.65 0.7], 'YColor', [0.6 0.65 0.7]);
    renderHeatmap_standalone(hAx, simMat, names);
    fprintf('[DEMO] Heatmap shown.\n');

    % --- Difference overlay (most dissimilar pair) ---
    mat2 = simMat; mat2(logical(eye(N))) = Inf;
    [~, idx] = min(mat2(:));
    [rr, cc] = ind2sub([N N], idx);
    fA  = imgs{rr};
    fB  = alignImages_standalone(fA, imgs{cc});
    [ovl, ~] = highlightDifferences_standalone(fA, fB, 0.05);

    fig2 = figure('Name', 'MediaVision Demo — Difference Overlay', ...
        'Color', [0.10 0.10 0.13]);
    subplot(1,3,1); imshow(fA); title('Image A','Color',[0 .85 .85],'FontName','Consolas');
    subplot(1,3,2); imshow(fB); title('Image B (aligned)','Color',[0 .85 .85],'FontName','Consolas');
    subplot(1,3,3); imshow(ovl); title('Differences','Color',[1 .4 0],'FontName','Consolas');
    set(fig2, 'Color', [0.10 0.10 0.13]);
    fprintf('[DEMO] Difference viewer shown (most dissimilar: %s vs %s).\n', ...
        names{rr}, names{cc});

    % --- Synthetic Video Temporal Analysis ---
    fprintf('[DEMO] Generating synthetic video frames...\n');
    nFrm    = 30;
    frames  = zeros(sz(1), sz(2), nFrm);
    for t = 1:nFrm
        base = im2double(uint8(rand(sz)*200 + 30));
        if t > 20    % inject a "scene change" at frame 21
            base = 1 - base;
        end
        frames(:,:,t) = base;
    end

    ssimScores = zeros(1, nFrm-1);
    for t = 1:nFrm-1
        ssimScores(t) = ssim(frames(:,:,t), frames(:,:,t+1));
    end
    pctScores = (ssimScores + 1) / 2 * 100;

    fig3 = figure('Name', 'MediaVision Demo — Temporal Analysis', ...
        'Color', [0.10 0.10 0.13]);
    ax = axes('Parent', fig3, 'Color', [0.06 0.06 0.08], ...
        'XColor',[0.6 0.65 0.7],'YColor',[0.6 0.65 0.7], ...
        'XGrid','on','YGrid','on','GridColor',[0.2 0.2 0.28]);
    plot(ax, pctScores, 'Color', [0.00 0.85 0.85], 'LineWidth', 1.5);
    hold(ax,'on');
    yline(ax, 70, '--', 'Color', [1 0.55 0], 'LineWidth', 1.2, ...
        'Label', 'Threshold', 'FontName', 'Consolas');
    anomIdx = find(pctScores < 70);
    if ~isempty(anomIdx)
        scatter(ax, anomIdx, pctScores(anomIdx), 60, 'o', 'filled', ...
            'MarkerFaceColor', [1 0.2 0.2]);
    end
    hold(ax,'off');
    ylim(ax,[0 105]);
    title(ax,'Synthetic Video — Temporal SSIM', ...
        'Color',[0 .85 .85],'FontName','Consolas','FontSize',11);
    xlabel(ax,'Frame','Color',[0.65 0.7 0.75],'FontName','Consolas');
    ylabel(ax,'Similarity (%)','Color',[0.65 0.7 0.75],'FontName','Consolas');

    fprintf('[DEMO] Demo complete. Three figure windows should be open.\n');
    fprintf('  Launch the full GUI with:  MediaComparisonTool\n\n');
end
