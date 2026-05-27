%% ========================================================================
%  MEDIAVISION COMPARISON SUITE  v2.0
%  Multiple Image & Video Comparison Tool with Interactive GUI
%
%  Author  : MediaVision Suite
%  Toolboxes: Image Processing Toolbox, Computer Vision Toolbox
%
%  DESCRIPTION:
%    Loads a batch of images/videos from a directory, pre-processes them to
%    a uniform grayscale resolution, registers/aligns them, computes an
%    SSIM-based similarity matrix, highlights spatial differences with
%    bounding-box overlays, and performs temporal frame-by-frame analysis
%    for video inputs — all through a polished, dark-themed GUI.
%
%  HOW TO RUN:
%    >> MediaComparisonTool
%
%  The GUI will guide you through folder selection, processing, and viewing
%  all results (heatmap, difference images, video SSIM plots, etc.).
%% ========================================================================

function MediaComparisonTool()
% -------------------------------------------------------------------------
% ENTRY POINT — build and launch the main GUI window.
% -------------------------------------------------------------------------

    %% --- Figure / Window Setup ------------------------------------------
    % Create the main application figure with a dark, professional theme.
    hFig = figure( ...
        'Name',        'MediaVision Comparison Suite  v2.0', ...
        'NumberTitle', 'off', ...
        'MenuBar',     'none', ...
        'ToolBar',     'none', ...
        'Color',       [0.10 0.10 0.13], ...   % near-black background
        'Position',    [80 60 1280 780], ...   % wide, comfortable workspace
        'Resize',      'on', ...
        'CloseRequestFcn', @onClose);

    %% --- Shared Application State (struct stored in figure UserData) -----
    % All data shared across callbacks lives here to avoid global variables.
    app.mediaFiles      = {};          % cell array of loaded file paths
    app.processedData   = {};          % cell array of pre-processed frames
    app.fileNames       = {};          % short display names
    app.simMatrix       = [];          % NxN SSIM similarity matrix (%)
    app.targetSize      = [512 512];   % uniform resize target (pixels)
    app.ssimThreshold   = 0.70;        % SSIM drop threshold for anomalies
    app.diffSensitivity = 0.05;        % binarize threshold for diff masks
    hFig.UserData       = app;

    %% --- Build GUI Layout ------------------------------------------------
    buildHeader(hFig);          % top branding / title bar
    buildControlPanel(hFig);    % left-side controls
    buildDisplayArea(hFig);     % right-side axes / preview area
    buildStatusBar(hFig);       % bottom status strip

    % Make the window visible now that all components are placed.
    hFig.Visible = 'on';
end


%% =========================================================================
%  SECTION 1 — GUI CONSTRUCTION HELPERS
%% =========================================================================

function buildHeader(hFig)
% -------------------------------------------------------------------------
% Draws the top branding banner with gradient-like title text.
% -------------------------------------------------------------------------
    % Thin accent bar across the very top (electric-cyan stripe).
    uipanel('Parent', hFig, ...
        'BackgroundColor', [0.00 0.85 0.85], ...
        'BorderType',      'none', ...
        'Position',        [0 0.965 1 0.005]);

    % Main header panel — dark charcoal.
    hHeader = uipanel('Parent', hFig, ...
        'BackgroundColor', [0.13 0.13 0.17], ...
        'BorderType',      'none', ...
        'Position',        [0 0.90 1 0.065]);

    % App title.
    uicontrol('Parent', hHeader, 'Style', 'text', ...
        'String',              'MEDIAVISION  COMPARISON  SUITE', ...
        'FontName',            'Consolas', ...
        'FontSize',            18, ...
        'FontWeight',          'bold', ...
        'ForegroundColor',     [0.00 0.90 0.90], ...   % cyan accent
        'BackgroundColor',     [0.13 0.13 0.17], ...
        'HorizontalAlignment', 'left', ...
        'Position',            [20 18 600 30]);

    % Version / subtitle tag.
    uicontrol('Parent', hHeader, 'Style', 'text', ...
        'String',              'v2.0  |  Structural Similarity · Spatial Diff · Temporal Analysis', ...
        'FontName',            'Consolas', ...
        'FontSize',            9, ...
        'ForegroundColor',     [0.50 0.55 0.60], ...
        'BackgroundColor',     [0.13 0.13 0.17], ...
        'HorizontalAlignment', 'left', ...
        'Position',            [22 4 700 16]);
end


function buildControlPanel(hFig)
% -------------------------------------------------------------------------
% Left-side panel housing all user controls (buttons, sliders, settings).
% -------------------------------------------------------------------------
    % Outer panel.
    hCtrl = uipanel('Parent', hFig, ...
        'BackgroundColor', [0.12 0.12 0.16], ...
        'BorderType',      'line', ...
        'HighlightColor',  [0.20 0.20 0.28], ...
        'Position',        [0 0.03 0.23 0.87]);

    % Helper: create a section label inside hCtrl.
    function makeSectionLabel(txt, yNorm)
        uicontrol('Parent', hCtrl, 'Style', 'text', ...
            'String',          txt, ...
            'FontName',        'Consolas', ...
            'FontSize',        8, ...
            'FontWeight',      'bold', ...
            'ForegroundColor', [0.00 0.85 0.85], ...
            'BackgroundColor', [0.12 0.12 0.16], ...
            'HorizontalAlignment', 'left', ...
            'Units', 'normalized', ...
            'Position', [0.05 yNorm 0.90 0.030]);
    end

    % Helper: create a styled push button.
    function hBtn = makeButton(txt, yNorm, clr, cbk)
        hBtn = uicontrol('Parent', hCtrl, 'Style', 'pushbutton', ...
            'String',          txt, ...
            'FontName',        'Consolas', ...
            'FontSize',        9, ...
            'FontWeight',      'bold', ...
            'ForegroundColor', [0.95 0.95 0.95], ...
            'BackgroundColor', clr, ...
            'Units',           'normalized', ...
            'Position',        [0.05 yNorm 0.90 0.052], ...
            'Callback',        cbk);
    end

    %% --- I/O Section ---
    makeSectionLabel('INPUT / OUTPUT', 0.935);
    makeButton('  [+]  Select Media Folder', 0.876, [0.15 0.42 0.60], @(s,e) onSelectFolder(hFig));
    makeButton('  [+]  Add Individual Files', 0.816, [0.15 0.38 0.55], @(s,e) onAddFiles(hFig));
    makeButton('  [-]  Clear All Files',      0.756, [0.35 0.18 0.18], @(s,e) onClearFiles(hFig));

    %% --- Pre-Processing Section ---
    makeSectionLabel('PRE-PROCESSING', 0.700);

    % Target resolution selector.
    uicontrol('Parent', hCtrl, 'Style', 'text', ...
        'String', 'Target Resolution:', ...
        'FontName', 'Consolas', 'FontSize', 8, ...
        'ForegroundColor', [0.70 0.75 0.80], ...
        'BackgroundColor', [0.12 0.12 0.16], ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', 'Position', [0.05 0.665 0.55 0.025]);

    hResPop = uicontrol('Parent', hCtrl, 'Style', 'popupmenu', ...
        'String',          {'256×256','512×512','768×768','1024×1024'}, ...
        'Value',           2, ...   % default 512×512
        'FontName',        'Consolas', 'FontSize', 8, ...
        'BackgroundColor', [0.18 0.18 0.24], ...
        'ForegroundColor', [0.90 0.90 0.90], ...
        'Units',           'normalized', ...
        'Position',        [0.05 0.630 0.90 0.035], ...
        'Tag',             'resPop');

    % Expose popup handle for callbacks via hFig UserData.
    setappdata(hFig, 'hResPop', hResPop);

    %% --- Analysis Settings ---
    makeSectionLabel('ANALYSIS SETTINGS', 0.595);

    % SSIM Anomaly Threshold slider.
    uicontrol('Parent', hCtrl, 'Style', 'text', ...
        'String', 'SSIM Anomaly Threshold:', ...
        'FontName', 'Consolas', 'FontSize', 8, ...
        'ForegroundColor', [0.70 0.75 0.80], ...
        'BackgroundColor', [0.12 0.12 0.16], ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', 'Position', [0.05 0.560 0.90 0.025]);

    hSsimSlider = uicontrol('Parent', hCtrl, 'Style', 'slider', ...
        'Min', 0.3, 'Max', 0.95, 'Value', 0.70, ...
        'Units', 'normalized', ...
        'Position', [0.05 0.525 0.75 0.030], ...
        'Tag', 'ssimSlider', ...
        'Callback', @(s,e) onSliderUpdate(hFig, s, 'ssimLbl', 'SSIM: %.2f'));
    hSsimLbl = uicontrol('Parent', hCtrl, 'Style', 'text', ...
        'String', 'SSIM: 0.70', ...
        'FontName', 'Consolas', 'FontSize', 7, ...
        'ForegroundColor', [0.00 0.85 0.85], ...
        'BackgroundColor', [0.12 0.12 0.16], ...
        'Units', 'normalized', 'Position', [0.82 0.525 0.15 0.030], ...
        'Tag', 'ssimLbl');
    setappdata(hFig, 'hSsimSlider', hSsimSlider);
    setappdata(hFig, 'hSsimLbl', hSsimLbl);

    % Diff Sensitivity slider.
    uicontrol('Parent', hCtrl, 'Style', 'text', ...
        'String', 'Diff Sensitivity (Binarize):', ...
        'FontName', 'Consolas', 'FontSize', 8, ...
        'ForegroundColor', [0.70 0.75 0.80], ...
        'BackgroundColor', [0.12 0.12 0.16], ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', 'Position', [0.05 0.485 0.90 0.025]);

    hDiffSlider = uicontrol('Parent', hCtrl, 'Style', 'slider', ...
        'Min', 0.01, 'Max', 0.30, 'Value', 0.05, ...
        'Units', 'normalized', ...
        'Position', [0.05 0.450 0.75 0.030], ...
        'Tag', 'diffSlider', ...
        'Callback', @(s,e) onSliderUpdate(hFig, s, 'diffLbl', 'Sens: %.3f'));
    hDiffLbl = uicontrol('Parent', hCtrl, 'Style', 'text', ...
        'String', 'Sens: 0.050', ...
        'FontName', 'Consolas', 'FontSize', 7, ...
        'ForegroundColor', [0.00 0.85 0.85], ...
        'BackgroundColor', [0.12 0.12 0.16], ...
        'Units', 'normalized', 'Position', [0.82 0.450 0.15 0.030], ...
        'Tag', 'diffLbl');
    setappdata(hFig, 'hDiffSlider', hDiffSlider);
    setappdata(hFig, 'hDiffLbl', hDiffLbl);

    %% --- Run Section ---
    makeSectionLabel('RUN PIPELINE', 0.390);
    makeButton('  [>]  PRE-PROCESS ALL',    0.330, [0.10 0.45 0.25], @(s,e) onPreProcess(hFig));
    makeButton('  [>]  COMPUTE SIMILARITY', 0.268, [0.10 0.40 0.50], @(s,e) onComputeSimilarity(hFig));
    makeButton('  [>]  SHOW DIFFERENCES',   0.206, [0.45 0.25 0.10], @(s,e) onShowDifferences(hFig));
    makeButton('  [>]  ANALYZE VIDEOS',     0.144, [0.35 0.15 0.45], @(s,e) onAnalyzeVideos(hFig));
    makeButton('  [*]  RUN FULL PIPELINE',  0.068, [0.65 0.35 0.00], @(s,e) onRunFull(hFig));

    %% --- File List Box ---
    makeSectionLabel('LOADED FILES', 0.035);
    % Shown at the very bottom of the control panel.
    hList = uicontrol('Parent', hCtrl, 'Style', 'listbox', ...
        'String',          {'(no files loaded)'}, ...
        'FontName',        'Consolas', ...
        'FontSize',        8, ...
        'ForegroundColor', [0.75 0.85 0.75], ...
        'BackgroundColor', [0.08 0.08 0.10], ...
        'Units',           'normalized', ...
        'Position',        [0.00 0.00 1.00 0.030], ... % small strip at base
        'Tag',             'fileList');
    setappdata(hFig, 'hFileList', hList);
end


function buildDisplayArea(hFig)
% -------------------------------------------------------------------------
% Right-side tabbed display: Heatmap | Diff Viewer | Video Analysis | Log
% -------------------------------------------------------------------------
    % Container panel.
    hDisp = uipanel('Parent', hFig, ...
        'BackgroundColor', [0.10 0.10 0.13], ...
        'BorderType',      'none', ...
        'Position',        [0.235 0.03 0.765 0.87]);

    % Tab group.
    hTG = uitabgroup(hDisp, ...
        'Units',    'normalized', ...
        'Position', [0 0 1 1]);

    % ---------- Tab 1: Similarity Heatmap ----------
    hTab1 = uitab(hTG, 'Title', '  Similarity Heatmap  ', ...
        'BackgroundColor', [0.12 0.12 0.16]);
    hAxHeat = axes('Parent', hTab1, ...
        'Color',           [0.08 0.08 0.10], ...
        'XColor',          [0.55 0.60 0.65], ...
        'YColor',          [0.55 0.60 0.65], ...
        'GridColor',       [0.22 0.22 0.28], ...
        'Units',           'normalized', ...
        'Position',        [0.08 0.08 0.88 0.88]);
    title(hAxHeat, 'SSIM Similarity Matrix (%)', ...
        'Color', [0.00 0.85 0.85], 'FontName', 'Consolas', 'FontSize', 12);
    setappdata(hFig, 'hAxHeat', hAxHeat);

    % ---------- Tab 2: Difference Viewer ----------
    hTab2 = uitab(hTG, 'Title', '  Difference Viewer  ', ...
        'BackgroundColor', [0.12 0.12 0.16]);

    % Top sub-panel: pair selector controls.
    hCtlRow = uipanel('Parent', hTab2, ...
        'BackgroundColor', [0.14 0.14 0.18], ...
        'BorderType',      'none', ...
        'Units',           'normalized', ...
        'Position',        [0 0.88 1 0.12]);

    uicontrol('Parent', hCtlRow, 'Style', 'text', ...
        'String', 'File A:', 'FontName', 'Consolas', 'FontSize', 9, ...
        'ForegroundColor', [0.70 0.75 0.80], ...
        'BackgroundColor', [0.14 0.14 0.18], ...
        'Units', 'normalized', 'Position', [0.02 0.40 0.06 0.40]);
    hPopA = uicontrol('Parent', hCtlRow, 'Style', 'popupmenu', ...
        'String', {'(none)'}, 'FontName', 'Consolas', 'FontSize', 8, ...
        'BackgroundColor', [0.18 0.18 0.24], ...
        'ForegroundColor', [0.90 0.90 0.90], ...
        'Units', 'normalized', 'Position', [0.09 0.38 0.28 0.45], ...
        'Tag', 'popA');

    uicontrol('Parent', hCtlRow, 'Style', 'text', ...
        'String', 'File B:', 'FontName', 'Consolas', 'FontSize', 9, ...
        'ForegroundColor', [0.70 0.75 0.80], ...
        'BackgroundColor', [0.14 0.14 0.18], ...
        'Units', 'normalized', 'Position', [0.40 0.40 0.06 0.40]);
    hPopB = uicontrol('Parent', hCtlRow, 'Style', 'popupmenu', ...
        'String', {'(none)'}, 'FontName', 'Consolas', 'FontSize', 8, ...
        'BackgroundColor', [0.18 0.18 0.24], ...
        'ForegroundColor', [0.90 0.90 0.90], ...
        'Units', 'normalized', 'Position', [0.47 0.38 0.28 0.45], ...
        'Tag', 'popB');

    uicontrol('Parent', hCtlRow, 'Style', 'pushbutton', ...
        'String', '  COMPARE PAIR  ', ...
        'FontName', 'Consolas', 'FontSize', 9, 'FontWeight', 'bold', ...
        'ForegroundColor', [0.95 0.95 0.95], ...
        'BackgroundColor', [0.45 0.25 0.10], ...
        'Units', 'normalized', 'Position', [0.78 0.25 0.20 0.55], ...
        'Callback', @(s,e) onComparePair(hFig));

    setappdata(hFig, 'hPopA', hPopA);
    setappdata(hFig, 'hPopB', hPopB);

    % Three axes: original A, original B, difference overlay.
    for k = 1:3
        xpos = 0.02 + (k-1)*0.327;
        hAx = axes('Parent', hTab2, ...
            'Color',    [0.06 0.06 0.08], ...
            'XColor',   [0.30 0.30 0.35], ...
            'YColor',   [0.30 0.30 0.35], ...
            'XTick', [], 'YTick', [], ...
            'Units',    'normalized', ...
            'Position', [xpos 0.03 0.30 0.83]);
        titles = {'Image A (Aligned)', 'Image B (Aligned)', 'Difference Overlay'};
        title(hAx, titles{k}, ...
            'Color', [0.00 0.85 0.85], 'FontName', 'Consolas', 'FontSize', 10);
        setappdata(hFig, sprintf('hAxDiff%d', k), hAx);
    end

    % ---------- Tab 3: Video Analysis ----------
    hTab3 = uitab(hTG, 'Title', '  Video Analysis  ', ...
        'BackgroundColor', [0.12 0.12 0.16]);

    uicontrol('Parent', hTab3, 'Style', 'text', ...
        'String', 'Select Video File:', 'FontName', 'Consolas', 'FontSize', 9, ...
        'ForegroundColor', [0.70 0.75 0.80], ...
        'BackgroundColor', [0.12 0.12 0.16], ...
        'Units', 'normalized', 'Position', [0.02 0.93 0.15 0.04]);
    hPopVid = uicontrol('Parent', hTab3, 'Style', 'popupmenu', ...
        'String', {'(no videos loaded)'}, ...
        'FontName', 'Consolas', 'FontSize', 8, ...
        'BackgroundColor', [0.18 0.18 0.24], ...
        'ForegroundColor', [0.90 0.90 0.90], ...
        'Units', 'normalized', 'Position', [0.18 0.925 0.30 0.048], ...
        'Tag', 'popVid');
    uicontrol('Parent', hTab3, 'Style', 'pushbutton', ...
        'String', '  ANALYZE VIDEO  ', ...
        'FontName', 'Consolas', 'FontSize', 9, 'FontWeight', 'bold', ...
        'ForegroundColor', [0.95 0.95 0.95], ...
        'BackgroundColor', [0.30 0.10 0.45], ...
        'Units', 'normalized', 'Position', [0.51 0.916 0.18 0.058], ...
        'Callback', @(s,e) onAnalyzeSingleVideo(hFig));
    setappdata(hFig, 'hPopVid', hPopVid);

    % SSIM time-series axes.
    hAxVid = axes('Parent', hTab3, ...
        'Color',      [0.06 0.06 0.08], ...
        'XColor',     [0.55 0.60 0.65], ...
        'YColor',     [0.55 0.60 0.65], ...
        'GridColor',  [0.22 0.22 0.28], ...
        'GridAlpha',  0.4, ...
        'XGrid', 'on', 'YGrid', 'on', ...
        'Units',      'normalized', ...
        'Position',   [0.06 0.44 0.90 0.45]);
    title(hAxVid, 'Frame-by-Frame SSIM  (Temporal Analysis)', ...
        'Color', [0.00 0.85 0.85], 'FontName', 'Consolas', 'FontSize', 11);
    xlabel(hAxVid, 'Frame Number', 'Color', [0.65 0.70 0.75], 'FontName', 'Consolas');
    ylabel(hAxVid, 'SSIM Score', 'Color', [0.65 0.70 0.75], 'FontName', 'Consolas');
    setappdata(hFig, 'hAxVid', hAxVid);

    % Two axes: anomaly frame pair.
    for k = 1:2
        xpos = 0.03 + (k-1)*0.50;
        hAv = axes('Parent', hTab3, ...
            'Color', [0.06 0.06 0.08], ...
            'XTick', [], 'YTick', [], ...
            'Units', 'normalized', ...
            'Position', [xpos 0.01 0.44 0.39]);
        lbls = {'Anomaly Frame (Before)', 'Anomaly Frame (After — diff overlay)'};
        title(hAv, lbls{k}, 'Color', [0.00 0.85 0.85], ...
            'FontName', 'Consolas', 'FontSize', 10);
        setappdata(hFig, sprintf('hAxVidFrame%d', k), hAv);
    end

    % ---------- Tab 4: Log ----------
    hTab4 = uitab(hTG, 'Title', '  Processing Log  ', ...
        'BackgroundColor', [0.12 0.12 0.16]);
    hLog = uicontrol('Parent', hTab4, 'Style', 'listbox', ...
        'String',          {'[MediaVision] Ready.  Select a media folder to begin.'}, ...
        'FontName',        'Consolas', ...
        'FontSize',        9, ...
        'ForegroundColor', [0.65 0.90 0.65], ...
        'BackgroundColor', [0.05 0.07 0.05], ...
        'Units',           'normalized', ...
        'Position',        [0 0 1 1], ...
        'Tag',             'logBox');
    setappdata(hFig, 'hLog', hLog);

    setappdata(hFig, 'hTabGroup', hTG);
end


function buildStatusBar(hFig)
% -------------------------------------------------------------------------
% Thin bar at the very bottom showing live status messages.
% -------------------------------------------------------------------------
    hSB = uipanel('Parent', hFig, ...
        'BackgroundColor', [0.10 0.12 0.10], ...
        'BorderType',      'none', ...
        'Position',        [0 0.00 1 0.03]);
    hStatus = uicontrol('Parent', hSB, 'Style', 'text', ...
        'String',              '  STATUS:  Idle  —  No files loaded.', ...
        'FontName',            'Consolas', ...
        'FontSize',            9, ...
        'ForegroundColor',     [0.45 0.90 0.45], ...
        'BackgroundColor',     [0.10 0.12 0.10], ...
        'HorizontalAlignment', 'left', ...
        'Units',               'normalized', ...
        'Position',            [0 0 0.75 1], ...
        'Tag',                 'statusBar');
    setappdata(hFig, 'hStatus', hStatus);

    % Right side: file count badge.
    hCount = uicontrol('Parent', hSB, 'Style', 'text', ...
        'String',              'FILES: 0', ...
        'FontName',            'Consolas', ...
        'FontSize',            9, ...
        'ForegroundColor',     [0.00 0.85 0.85], ...
        'BackgroundColor',     [0.10 0.12 0.10], ...
        'HorizontalAlignment', 'right', ...
        'Units',               'normalized', ...
        'Position',            [0.75 0 0.24 1], ...
        'Tag',                 'fileCount');
    setappdata(hFig, 'hCount', hCount);
end


%% =========================================================================
%  SECTION 2 — GUI CALLBACK FUNCTIONS
%% =========================================================================

function onSelectFolder(hFig)
% -------------------------------------------------------------------------
% Opens a folder browser; scans for supported image/video extensions.
% -------------------------------------------------------------------------
    logMsg(hFig, 'Opening folder browser...');
    folder = uigetdir(pwd, 'Select Media Folder');
    if isequal(folder, 0)
        logMsg(hFig, 'Folder selection cancelled.');
        return;
    end

    % Supported extensions.
    imgExts = {'*.jpg','*.jpeg','*.png','*.bmp','*.tif','*.tiff'};
    vidExts = {'*.mp4','*.avi','*.mov','*.mkv','*.wmv'};
    allExts = [imgExts, vidExts];

    files = {};
    for k = 1:numel(allExts)
        found = dir(fullfile(folder, allExts{k}));
        for j = 1:numel(found)
            files{end+1} = fullfile(found(j).folder, found(j).name); %#ok<AGROW>
        end
    end

    if isempty(files)
        msgbox('No supported media files found in the selected folder.', ...
            'MediaVision', 'warn');
        return;
    end

    app = hFig.UserData;
    app.mediaFiles = files;
    hFig.UserData  = app;
    refreshFileList(hFig);
    updateStatus(hFig, sprintf('Loaded %d files from: %s', numel(files), folder));
    logMsg(hFig, sprintf('Folder loaded: %s  (%d files)', folder, numel(files)));
end


function onAddFiles(hFig)
% -------------------------------------------------------------------------
% Opens a multi-select file picker to append individual files.
% -------------------------------------------------------------------------
    [fnames, fpath] = uigetfile( ...
        {'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff;*.mp4;*.avi;*.mov;*.mkv', ...
         'Media Files'}, ...
        'Select Files', 'MultiSelect', 'on');

    if isequal(fnames, 0), return; end
    if ischar(fnames), fnames = {fnames}; end   % single file → cell

    app = hFig.UserData;
    for k = 1:numel(fnames)
        app.mediaFiles{end+1} = fullfile(fpath, fnames{k});
    end
    hFig.UserData = app;
    refreshFileList(hFig);
    updateStatus(hFig, sprintf('%d files now loaded.', numel(app.mediaFiles)));
    logMsg(hFig, sprintf('Added %d file(s).', numel(fnames)));
end


function onClearFiles(hFig)
% -------------------------------------------------------------------------
% Resets the entire application state.
% -------------------------------------------------------------------------
    app = hFig.UserData;
    app.mediaFiles    = {};
    app.processedData = {};
    app.fileNames     = {};
    app.simMatrix     = [];
    hFig.UserData     = app;
    refreshFileList(hFig);
    updateStatus(hFig, 'All files cleared.');
    logMsg(hFig, 'State reset.');

    % Clear all axes.
    cla(getappdata(hFig, 'hAxHeat'));
    for k = 1:3, cla(getappdata(hFig, sprintf('hAxDiff%d', k))); end
    cla(getappdata(hFig, 'hAxVid'));
    for k = 1:2, cla(getappdata(hFig, sprintf('hAxVidFrame%d', k))); end
end


function onSliderUpdate(hFig, hSlider, lblTag, fmt)
% -------------------------------------------------------------------------
% Live-update a text label next to a slider and sync value to app state.
% -------------------------------------------------------------------------
    val = hSlider.Value;
    hLbl = findobj(hFig, 'Tag', lblTag);
    hLbl.String = sprintf(fmt, val);

    app = hFig.UserData;
    if strcmp(lblTag, 'ssimLbl')
        app.ssimThreshold = val;
    else
        app.diffSensitivity = val;
    end
    hFig.UserData = app;
end


function onPreProcess(hFig)
% -------------------------------------------------------------------------
% Pre-processes all loaded files (resize, grayscale, registration).
% -------------------------------------------------------------------------
    app = hFig.UserData;
    if isempty(app.mediaFiles)
        warndlg('No files loaded. Please select a folder first.', 'MediaVision');
        return;
    end

    % Read target resolution from popup.
    hResPop = getappdata(hFig, 'hResPop');
    resList = {[256 256],[512 512],[768 768],[1024 1024]};
    app.targetSize = resList{hResPop.Value};

    updateStatus(hFig, 'Pre-processing files...');
    logMsg(hFig, sprintf('Pre-processing %d files at %dx%d ...', ...
        numel(app.mediaFiles), app.targetSize(1), app.targetSize(2)));

    app.processedData = cell(1, numel(app.mediaFiles));
    app.fileNames     = cell(1, numel(app.mediaFiles));

    for k = 1:numel(app.mediaFiles)
        fpath = app.mediaFiles{k};
        [~, fname, ext] = fileparts(fpath);
        app.fileNames{k} = [fname ext];

        if isVideoFile(fpath)
            % For videos: store the pre-processed frame stack.
            app.processedData{k} = loadAndPreProcessVideo(fpath, app.targetSize);
            logMsg(hFig, sprintf('  [VIDEO]  %s  — %d frames', ...
                app.fileNames{k}, size(app.processedData{k}, 3)));
        else
            % For images: store a single pre-processed 2D frame.
            app.processedData{k} = loadAndPreProcessImage(fpath, app.targetSize);
            logMsg(hFig, sprintf('  [IMAGE]  %s', app.fileNames{k}));
        end
        drawnow;  % keep GUI responsive during loop
    end

    hFig.UserData = app;

    % Refresh pair-selector popup lists.
    hPopA = getappdata(hFig, 'hPopA');
    hPopB = getappdata(hFig, 'hPopB');
    hPopA.String = app.fileNames;
    hPopB.String = app.fileNames;
    if numel(app.fileNames) >= 2, hPopB.Value = 2; end

    % Refresh video popup.
    hPopVid = getappdata(hFig, 'hPopVid');
    vidNames = {};
    for k = 1:numel(app.mediaFiles)
        if isVideoFile(app.mediaFiles{k}), vidNames{end+1} = app.fileNames{k}; end %#ok<AGROW>
    end
    hPopVid.String = iif(isempty(vidNames), {'(no videos loaded)'}, vidNames);

    updateStatus(hFig, sprintf('Pre-processing complete. %d items ready.', numel(app.mediaFiles)));
    logMsg(hFig, 'Pre-processing complete.');
end


function onComputeSimilarity(hFig)
% -------------------------------------------------------------------------
% Builds the NxN SSIM similarity matrix and renders it as a heatmap.
% -------------------------------------------------------------------------
    app = hFig.UserData;
    if isempty(app.processedData)
        warndlg('Run Pre-Processing first.', 'MediaVision');
        return;
    end

    N = numel(app.processedData);
    updateStatus(hFig, sprintf('Computing %dx%d similarity matrix...', N, N));
    logMsg(hFig, sprintf('Computing SSIM similarity matrix (%dx%d)...', N, N));

    % simMatrix(i,j) = SSIM-based similarity in percent (0–100).
    simMat = zeros(N, N);

    for i = 1:N
        for j = 1:N
            if i == j
                simMat(i,j) = 100;   % identical to itself
            elseif j > i
                % Extract representative grayscale frames for comparison.
                frameI = getRepresentativeFrame(app.processedData{i});
                frameJ = getRepresentativeFrame(app.processedData{j});

                % Compute SSIM (returns value in [-1, 1]).
                rawSSIM = calculateSimilarity(frameI, frameJ);

                % Convert SSIM to 0–100% scale:
                %   SSIM of +1 → 100%, SSIM of -1 → 0%.
                pct = (rawSSIM + 1) / 2 * 100;
                simMat(i,j) = pct;
                simMat(j,i) = pct;   % matrix is symmetric
            end
            drawnow;
        end
    end

    app.simMatrix = simMat;
    hFig.UserData = app;

    % Render heatmap.
    hAxHeat = getappdata(hFig, 'hAxHeat');
    renderHeatmap(hAxHeat, simMat, app.fileNames);

    updateStatus(hFig, 'Similarity matrix computed. See Heatmap tab.');
    logMsg(hFig, 'Similarity matrix ready.');

    % Switch to heatmap tab automatically.
    hTG = getappdata(hFig, 'hTabGroup');
    hTG.SelectedTab = hTG.Children(1);
end


function onComparePair(hFig)
% -------------------------------------------------------------------------
% Compares the two files chosen in the Difference Viewer dropdowns.
% -------------------------------------------------------------------------
    app  = hFig.UserData;
    if isempty(app.processedData)
        warndlg('Run Pre-Processing first.', 'MediaVision');
        return;
    end

    idxA = getappdata(hFig, 'hPopA').Value;
    idxB = getappdata(hFig, 'hPopB').Value;

    if idxA == idxB
        warndlg('Please select two different files.', 'MediaVision');
        return;
    end

    frameA = getRepresentativeFrame(app.processedData{idxA});
    frameB = getRepresentativeFrame(app.processedData{idxB});

    % Align B to A using phase-correlation registration.
    frameB_aligned = alignImages(frameA, frameB);

    % Build difference overlay (returns a colour RGB image).
    [diffOverlay, ~] = highlightDifferences(frameA, frameB_aligned, app.diffSensitivity);

    % Display in the three axes.
    hAx1 = getappdata(hFig, 'hAxDiff1');
    hAx2 = getappdata(hFig, 'hAxDiff2');
    hAx3 = getappdata(hFig, 'hAxDiff3');

    imshow(frameA, 'Parent', hAx1);
    title(hAx1, sprintf('A: %s', app.fileNames{idxA}), ...
        'Color', [0.00 0.85 0.85], 'FontName', 'Consolas', 'FontSize', 9);

    imshow(frameB_aligned, 'Parent', hAx2);
    title(hAx2, sprintf('B: %s  (registered)', app.fileNames{idxB}), ...
        'Color', [0.00 0.85 0.85], 'FontName', 'Consolas', 'FontSize', 9);

    imshow(diffOverlay, 'Parent', hAx3);
    title(hAx3, sprintf('Differences  (SSIM=%.1f%%)', ...
        (calculateSimilarity(frameA,frameB_aligned)+1)/2*100), ...
        'Color', [1 0.4 0], 'FontName', 'Consolas', 'FontSize', 9);

    ssimPct = (calculateSimilarity(frameA, frameB_aligned) + 1) / 2 * 100;
    updateStatus(hFig, sprintf('Pair comparison complete. Similarity: %.1f%%', ssimPct));
    logMsg(hFig, sprintf('Compared [%s] vs [%s] → %.1f%% similar.', ...
        app.fileNames{idxA}, app.fileNames{idxB}, ssimPct));
end


function onShowDifferences(hFig)
% -------------------------------------------------------------------------
% Loops through all image pairs and shows the most dissimilar pair.
% -------------------------------------------------------------------------
    app = hFig.UserData;
    if isempty(app.simMatrix)
        warndlg('Compute the Similarity Matrix first.', 'MediaVision');
        return;
    end

    N   = size(app.simMatrix, 1);
    mat = app.simMatrix;
    mat(logical(eye(N))) = Inf;          % ignore diagonal (self-compare)
    [~, idx] = min(mat(:));
    [rr, cc] = ind2sub([N N], idx);

    logMsg(hFig, sprintf('Most dissimilar pair: [%s] vs [%s] (%.1f%%)', ...
        app.fileNames{rr}, app.fileNames{cc}, app.simMatrix(rr,cc)));

    % Point the diff viewer dropdowns to this pair and trigger comparison.
    getappdata(hFig, 'hPopA').Value = rr;
    getappdata(hFig, 'hPopB').Value = cc;

    % Switch to Diff Viewer tab.
    hTG = getappdata(hFig, 'hTabGroup');
    hTG.SelectedTab = hTG.Children(2);

    onComparePair(hFig);
end


function onAnalyzeSingleVideo(hFig)
% -------------------------------------------------------------------------
% Runs temporal frame-by-frame SSIM analysis on the selected video.
% -------------------------------------------------------------------------
    app    = hFig.UserData;
    hPopV  = getappdata(hFig, 'hPopVid');

    % Map popup index to file list index.
    vidIdx = findVideoIndex(app, hPopV.Value);
    if vidIdx < 1
        warndlg('No video files loaded.', 'MediaVision');
        return;
    end

    fpath   = app.mediaFiles{vidIdx};
    logMsg(hFig, sprintf('Analyzing video: %s', app.fileNames{vidIdx}));
    updateStatus(hFig, 'Running temporal video analysis...');

    hAxVid   = getappdata(hFig, 'hAxVid');
    hAxVF1   = getappdata(hFig, 'hAxVidFrame1');
    hAxVF2   = getappdata(hFig, 'hAxVidFrame2');

    processVideoFrames(fpath, app.targetSize, app.ssimThreshold, ...
        app.diffSensitivity, hAxVid, hAxVF1, hAxVF2, hFig);

    updateStatus(hFig, 'Video temporal analysis complete.');
end


function onAnalyzeVideos(hFig)
% -------------------------------------------------------------------------
% Batch-analyzes every video found in the loaded file list.
% -------------------------------------------------------------------------
    app = hFig.UserData;
    if isempty(app.mediaFiles)
        warndlg('No files loaded.', 'MediaVision');
        return;
    end
    logMsg(hFig, 'Batch video analysis started...');
    for k = 1:numel(app.mediaFiles)
        if isVideoFile(app.mediaFiles{k})
            hTG = getappdata(hFig, 'hTabGroup');
            hTG.SelectedTab = hTG.Children(3);   % switch to Video tab
            onAnalyzeSingleVideo(hFig);
        end
    end
    logMsg(hFig, 'Batch video analysis complete.');
end


function onRunFull(hFig)
% -------------------------------------------------------------------------
% Convenience: run the entire pipeline in one click.
% -------------------------------------------------------------------------
    logMsg(hFig, '=== FULL PIPELINE STARTED ===');
    onPreProcess(hFig);
    onComputeSimilarity(hFig);
    onShowDifferences(hFig);
    onAnalyzeVideos(hFig);
    logMsg(hFig, '=== FULL PIPELINE COMPLETE ===');
    updateStatus(hFig, 'Full pipeline complete.');
end


function onClose(hFig, ~)
% -------------------------------------------------------------------------
% Graceful close with confirmation dialog.
% -------------------------------------------------------------------------
    choice = questdlg('Exit MediaVision Comparison Suite?', ...
        'Confirm Exit', 'Exit', 'Cancel', 'Cancel');
    if strcmp(choice, 'Exit')
        delete(hFig);
    end
end


%% =========================================================================
%  SECTION 3 — CORE PROCESSING FUNCTIONS (MODULAR HELPERS)
%% =========================================================================

function grayFrame = loadAndPreProcessImage(fpath, targetSize)
% -------------------------------------------------------------------------
% LOAD & PRE-PROCESS a single image file.
%
%  Steps:
%   1. Read the image with imread().
%   2. Convert RGB → grayscale (reduces 3-channel data to luminance channel).
%   3. Resize to targetSize using bicubic interpolation for quality.
%   4. Normalize pixel values to [0,1] for numerically stable SSIM.
%
%  INPUT:
%   fpath      — full path to the image file
%   targetSize — [rows cols] e.g. [512 512]
%
%  OUTPUT:
%   grayFrame  — double grayscale image in [0,1], size targetSize
% -------------------------------------------------------------------------
    img = imread(fpath);

    % Convert to grayscale if the image has colour channels.
    % rgb2gray uses the ITU-R BT.601 luma formula:
    %   Y = 0.2989*R + 0.5870*G + 0.1140*B
    if size(img, 3) == 3
        img = rgb2gray(img);
    end

    % Resize to uniform dimensions.  'bicubic' preserves edge sharpness
    % better than 'bilinear' at the cost of slight computation overhead.
    img = imresize(img, targetSize, 'bicubic');

    % Normalize to double [0,1] — required by ssim() and imabsdiff().
    grayFrame = im2double(img);
end


function frames = loadAndPreProcessVideo(fpath, targetSize)
% -------------------------------------------------------------------------
% LOAD & PRE-PROCESS a video file into a stack of grayscale frames.
%
%  Uses VideoReader to iterate over frames; applies the same pipeline
%  as loadAndPreProcessImage() to each frame.
%
%  To keep memory manageable, only every Nth frame is sampled (max 120).
%
%  OUTPUT:
%   frames — 3D double array [rows × cols × numFrames], values in [0,1]
% -------------------------------------------------------------------------
    vr        = VideoReader(fpath);
    totalFrm  = floor(vr.Duration * vr.FrameRate);

    % Sample up to 120 frames uniformly across the video duration.
    maxFrames = 120;
    step      = max(1, floor(totalFrm / maxFrames));

    frameList = {};
    fIdx      = 0;
    while hasFrame(vr)
        rawFrame = readFrame(vr);
        fIdx     = fIdx + 1;
        if mod(fIdx, step) ~= 0, continue; end

        % Grayscale conversion + resize + normalization.
        if size(rawFrame, 3) == 3
            rawFrame = rgb2gray(rawFrame);
        end
        rawFrame = imresize(rawFrame, targetSize, 'bicubic');
        frameList{end+1} = im2double(rawFrame); %#ok<AGROW>

        if numel(frameList) >= maxFrames, break; end
    end

    % Pack into a 3D array: [rows, cols, nFrames].
    nFrames = numel(frameList);
    frames  = zeros(targetSize(1), targetSize(2), nFrames);
    for k = 1:nFrames
        frames(:,:,k) = frameList{k};
    end
end


function frame = getRepresentativeFrame(data)
% -------------------------------------------------------------------------
% Returns a single 2D grayscale frame from processed data.
%   • For images (2D): returns directly.
%   • For video stacks (3D): returns the first frame.
% -------------------------------------------------------------------------
    if ndims(data) == 3
        frame = data(:,:,1);   % first sampled video frame
    else
        frame = data;
    end
end


function ssimScore = calculateSimilarity(imgA, imgB)
% -------------------------------------------------------------------------
% CALCULATE STRUCTURAL SIMILARITY INDEX (SSIM)
%
%  SSIM measures perceptual image quality across three components:
%   • Luminance  l(A,B) = (2·μA·μB + C1) / (μA² + μB² + C1)
%   • Contrast   c(A,B) = (2·σA·σB + C2) / (σA² + σB² + C2)
%   • Structure  s(A,B) = (σAB + C3)      / (σA·σB + C3)
%
%  SSIM(A,B) = l(A,B) · c(A,B) · s(A,B)     ∈ [-1, +1]
%
%  MATLAB's built-in ssim() computes a weighted local average over a
%  sliding 11×11 Gaussian window — far more robust than pixel-wise MSE.
%
%  INPUTS : imgA, imgB — double grayscale images in [0,1], same size
%  OUTPUT : ssimScore  — scalar in [-1, +1]  (+1 = identical)
% -------------------------------------------------------------------------
    % Ensure images are the same size (safety guard).
    if ~isequal(size(imgA), size(imgB))
        imgB = imresize(imgB, size(imgA));
    end

    % ssim() is from the Image Processing Toolbox.
    ssimScore = ssim(imgA, imgB);
end


function alignedB = alignImages(refImg, movImg)
% -------------------------------------------------------------------------
% IMAGE REGISTRATION using Phase-Correlation (imregcorr).
%
%  Phase-correlation finds the dominant translational offset between two
%  images by computing the cross-power spectrum in the Fourier domain:
%
%      R(u,v) = F{A}(u,v) · conj(F{B}(u,v))
%               ─────────────────────────────
%               |F{A}(u,v) · conj(F{B}(u,v))|
%
%  The inverse FFT of R gives a peak at the shift vector (Δx, Δy).
%  imregcorr returns an affine2d transform; imwarp applies it.
%
%  This corrects for small camera translations between shots (Requirement 2).
%
%  INPUTS : refImg — reference (fixed) grayscale image [0,1]
%           movImg — moving (to be aligned) grayscale image [0,1]
%  OUTPUT : alignedB — movImg warped to match refImg's coordinate frame
% -------------------------------------------------------------------------
    % imregcorr works on uint8 or uint16 for best numerical stability.
    refU  = im2uint8(refImg);
    movU  = im2uint8(movImg);

    % Estimate the geometric transform (translation model is sufficient
    % for small camera shifts; use 'similarity' for rotation+scale).
    tform = imregcorr(movU, refU, 'translation');

    % Apply the recovered transform via bilinear resampling.
    Rfixed   = imref2d(size(refImg));
    alignedU = imwarp(movU, tform, 'OutputView', Rfixed, ...
        'Interp', 'bilinear');

    % Back to double [0,1].
    alignedB = im2double(alignedU);
end


function [overlayRGB, regions] = highlightDifferences(imgA, imgB, threshold)
% -------------------------------------------------------------------------
% HIGHLIGHT SPATIAL DIFFERENCES between two aligned images.
%
%  Pipeline (Requirement 4):
%   1. imabsdiff()   — per-pixel absolute difference map  D(x,y) = |A-B|
%   2. imbinarize()  — threshold D to create a binary mask  M(x,y) ∈ {0,1}
%                      'adaptive' Wiener method handles uneven illumination.
%   3. bwareaopen()  — remove speckle noise (blobs < 50 px).
%   4. regionprops() — extract BoundingBox of each connected region.
%   5. insertShape() — draw red rectangles around detected differences.
%
%  INPUTS:
%   imgA, imgB — double grayscale images [0,1], same size
%   threshold  — sensitivity: higher = less sensitive (0.01–0.30)
%
%  OUTPUTS:
%   overlayRGB — uint8 RGB image with red bounding boxes drawn
%   regions    — struct array from regionprops (contains BoundingBox etc.)
% -------------------------------------------------------------------------
    % Step 1: Absolute difference map.
    % Each pixel stores |A(x,y) - B(x,y)|; range [0,1].
    diffMap = imabsdiff(imgA, imgB);

    % Step 2: Binarize using a fixed threshold.
    % Pixels with |difference| > threshold are marked as "changed".
    binMask = imbinarize(diffMap, threshold);

    % Step 3: Morphological cleanup — remove isolated noise pixels.
    % bwareaopen keeps only connected components with area ≥ 50 pixels.
    binMask = bwareaopen(binMask, 50);

    % Optional dilation to make bounding boxes slightly larger than
    % the exact pixel cluster (improves visual clarity).
    se      = strel('disk', 5);
    binMask = imdilate(binMask, se);

    % Step 4: Label connected regions and extract bounding boxes.
    % regionprops returns a struct with fields: Area, BoundingBox, Centroid.
    regions = regionprops(binMask, 'BoundingBox', 'Area', 'Centroid');

    % Step 5: Compose the output colour image.
    % Convert grayscale A to RGB so we can draw coloured overlays.
    base    = repmat(uint8(imgA * 255), [1 1 3]);   % grey → RGB

    if ~isempty(regions)
        % Build an [Nx4] matrix of bounding boxes [x y w h].
        boxes = vertcat(regions.BoundingBox);

        % insertShape is from the Computer Vision Toolbox.
        % 'Rectangle' draws a hollow rectangle.  Colour is [255 0 0] = red.
        overlayRGB = insertShape(base, 'Rectangle', boxes, ...
            'Color',     [255 0 0], ...
            'LineWidth', 3);
    else
        overlayRGB = base;   % no differences found → return plain image
    end
end


function processVideoFrames(fpath, targetSize, ssimThresh, diffSens, ...
        hAxVid, hAxVF1, hAxVF2, hFig)
% -------------------------------------------------------------------------
% TEMPORAL & SPATIAL VIDEO ANALYSIS  (Requirement 5)
%
%  Algorithm:
%   1. Extract uniformly-sampled frames with VideoReader.
%   2. For consecutive frame pairs (t, t+1):
%        a. Compute SSIM between the two pre-processed frames.
%        b. Record the score in an array for plotting.
%   3. Plot the SSIM time-series on hAxVid with anomaly markers.
%   4. Find the frame-pair with the largest SSIM drop (scene cut /
%      sudden object appearance).
%   5. Pass that pair through highlightDifferences() and display
%      in hAxVF1 / hAxVF2.
%
%  A sudden drop below ssimThresh flags a temporal anomaly (e.g. a new
%  object entering the scene, a scene cut, or a moving vehicle).
% -------------------------------------------------------------------------
    logMsg(hFig, sprintf('  Reading video: %s', fpath));

    % Load frames (uses the pre-processor from Section 3).
    frames   = loadAndPreProcessVideo(fpath, targetSize);
    nFrames  = size(frames, 3);

    if nFrames < 2
        logMsg(hFig, '  Not enough frames for temporal analysis.');
        return;
    end

    % Pre-allocate SSIM score vector.
    % ssimScores(t) = SSIM between frame t and frame t+1.
    ssimScores = zeros(1, nFrames - 1);

    for t = 1 : nFrames - 1
        fA = frames(:,:,t);
        fB = frames(:,:,t+1);
        ssimScores(t) = calculateSimilarity(fA, fB);
        drawnow;
    end

    % --- Plot the SSIM time series ---
    cla(hAxVid);
    hold(hAxVid, 'on');

    % Convert to percentage for readability.
    pctScores = (ssimScores + 1) / 2 * 100;

    % Main line (cyan).
    plot(hAxVid, 1:numel(pctScores), pctScores, ...
        'Color', [0.00 0.85 0.85], 'LineWidth', 1.5);

    % Threshold reference line (dashed orange).
    threshPct = (ssimThresh + 1) / 2 * 100;
    yline(hAxVid, threshPct, '--', ...
        'Color', [1.00 0.55 0.00], ...
        'LineWidth', 1.2, ...
        'Label', sprintf('Anomaly threshold (%.0f%%)', threshPct), ...
        'LabelHorizontalAlignment', 'left', ...
        'FontName', 'Consolas', 'FontSize', 8);

    % Mark anomaly frames (drops below threshold) with red circles.
    anomalyIdx = find(pctScores < threshPct);
    if ~isempty(anomalyIdx)
        scatter(hAxVid, anomalyIdx, pctScores(anomalyIdx), 60, ...
            'o', 'filled', ...
            'MarkerFaceColor', [1 0.2 0.2], ...
            'MarkerEdgeColor', [1 1 1]);
        logMsg(hFig, sprintf('  Anomalies detected at frames: %s', ...
            num2str(anomalyIdx)));
    end

    hold(hAxVid, 'off');
    ylim(hAxVid, [0 105]);
    xlabel(hAxVid, 'Sampled Frame Index', 'Color', [0.65 0.70 0.75], ...
        'FontName', 'Consolas');
    ylabel(hAxVid, 'SSIM Similarity (%)', 'Color', [0.65 0.70 0.75], ...
        'FontName', 'Consolas');
    title(hAxVid, sprintf('Temporal SSIM  —  %s  (%d sampled frames)', ...
        fpath, nFrames), ...
        'Color', [0.00 0.85 0.85], 'FontName', 'Consolas', 'FontSize', 10);

    % --- Find and display the most anomalous frame pair ---
    [~, worstT] = min(pctScores);   % index of largest SSIM drop

    fBefore = frames(:,:, worstT);
    fAfter  = frames(:,:, worstT + 1);

    % Align "after" to "before" to remove any camera motion before diff.
    fAfterAligned = alignImages(fBefore, fAfter);

    % Spatial difference overlay.
    [diffOvl, ~] = highlightDifferences(fBefore, fAfterAligned, diffSens);

    % Display in the two video-frame axes.
    imshow(fBefore, 'Parent', hAxVF1);
    title(hAxVF1, sprintf('Frame %d  (before anomaly)', worstT), ...
        'Color', [0.00 0.85 0.85], 'FontName', 'Consolas', 'FontSize', 9);

    imshow(diffOvl, 'Parent', hAxVF2);
    title(hAxVF2, sprintf('Frame %d  (differences highlighted)', worstT+1), ...
        'Color', [1 0.4 0], 'FontName', 'Consolas', 'FontSize', 9);

    logMsg(hFig, sprintf('  Worst SSIM drop at t=%d: %.1f%%', worstT, pctScores(worstT)));
end


function renderHeatmap(hAx, simMat, names)
% -------------------------------------------------------------------------
% RENDER THE SIMILARITY MATRIX as a styled heatmap.
%
%  Uses imagesc() for the colour grid, then annotates each cell with its
%  percentage value.  The colourmap transitions cyan→yellow→red to make
%  low-similarity pairs visually distinctive.
% -------------------------------------------------------------------------
    cla(hAx);
    N = size(simMat, 1);

    % imagesc scales the matrix values into the full colourmap range.
    imagesc(hAx, simMat, [0 100]);

    % Custom colourmap: high similarity (100%) = bright cyan,
    %                   low  similarity (0%)   = deep red.
    cmapData = interp1([0; 50; 100], ...
        [0.80 0.10 0.10;    % red  — very dissimilar
         0.90 0.80 0.00;    % gold — moderate
         0.00 0.85 0.85], ... % cyan — very similar
        0:1:100, 'linear');
    colormap(hAx, cmapData);

    colorbar(hAx, ...
        'Color', [0.70 0.75 0.80], ...
        'FontName', 'Consolas', 'FontSize', 8);

    % Axis tick labels.
    shortNames = cellfun(@(n) truncate(n, 12), names, 'UniformOutput', false);
    set(hAx, ...
        'XTick',         1:N, ...
        'YTick',         1:N, ...
        'XTickLabel',    shortNames, ...
        'YTickLabel',    shortNames, ...
        'XTickLabelRotation', 40, ...
        'TickLabelInterpreter', 'none', ...
        'FontName',      'Consolas', ...
        'FontSize',       8, ...
        'XColor',        [0.65 0.70 0.75], ...
        'YColor',        [0.65 0.70 0.75]);

    % Annotate each cell with the percentage number.
    for i = 1:N
        for j = 1:N
            % Choose white text on dark cells, dark on bright cells.
            val = simMat(i,j);
            if val < 60
                txtClr = [1.0 1.0 1.0];
            else
                txtClr = [0.05 0.05 0.05];
            end
            text(hAx, j, i, sprintf('%.0f%%', val), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment',   'middle', ...
                'FontName',  'Consolas', ...
                'FontSize',   8, ...
                'FontWeight', 'bold', ...
                'Color',      txtClr);
        end
    end

    title(hAx, 'SSIM Similarity Matrix  (%)', ...
        'Color', [0.00 0.85 0.85], 'FontName', 'Consolas', 'FontSize', 12);
end


%% =========================================================================
%  SECTION 4 — GUI UTILITY HELPERS
%% =========================================================================

function refreshFileList(hFig)
% Updates the file list display and the file-count badge.
    app   = hFig.UserData;
    hList = getappdata(hFig, 'hFileList');
    hCnt  = getappdata(hFig, 'hCount');

    if isempty(app.mediaFiles)
        hList.String = {'(no files loaded)'};
        hCnt.String  = 'FILES: 0';
    else
        shortNames = cellfun(@(f) getFilename(f), app.mediaFiles, ...
            'UniformOutput', false);
        hList.String = shortNames;
        hCnt.String  = sprintf('FILES: %d', numel(app.mediaFiles));
    end
end


function updateStatus(hFig, msg)
% Updates the bottom status bar text.
    hSB = getappdata(hFig, 'hStatus');
    hSB.String = sprintf('  STATUS:  %s', msg);
    drawnow;
end


function logMsg(hFig, msg)
% Appends a timestamped message to the Processing Log tab.
    hLog     = getappdata(hFig, 'hLog');
    ts       = datestr(now, 'HH:MM:SS');
    newLine  = sprintf('[%s]  %s', ts, msg);
    existing = hLog.String;
    if ischar(existing), existing = {existing}; end
    hLog.String = [existing; {newLine}];
    hLog.Value  = numel(hLog.String);   % scroll to bottom
    drawnow;
end


function idx = findVideoIndex(app, popupVal)
% Maps a popup index (counting only videos) back to the full file list index.
    idx    = -1;
    count  = 0;
    for k = 1:numel(app.mediaFiles)
        if isVideoFile(app.mediaFiles{k})
            count = count + 1;
            if count == popupVal
                idx = k;
                return;
            end
        end
    end
end


function tf = isVideoFile(fpath)
% Returns true for known video extensions.
    [~,~,ext] = fileparts(fpath);
    tf = ismember(lower(ext), {'.mp4','.avi','.mov','.mkv','.wmv','.flv'});
end


function name = getFilename(fpath)
% Returns 'name.ext' from a full path.
    [~, n, e] = fileparts(fpath);
    name = [n e];
end


function s = truncate(str, maxLen)
% Truncates a string with '…' if it exceeds maxLen characters.
    if numel(str) > maxLen
        s = [str(1:maxLen-1) '…'];
    else
        s = str;
    end
end


function val = iif(cond, trueVal, falseVal)
% Inline if: returns trueVal when cond is true, else falseVal.
    if cond, val = trueVal; else, val = falseVal; end
end
