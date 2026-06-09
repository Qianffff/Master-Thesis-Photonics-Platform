clc;
clear;
close all;

%% ===================== USER PARAMETERS =====================
videoFile = 'WIN_20260210_11_15_12_Pro.mp4';
pixelSizeX = 0.84;        % μm per pixel in X
pixelSizeY = 0.98;        % μm per pixel in Y
thresholdRatio = 0.6;     % Threshold as fraction of global max intensity
maxSpotAreaPixels = 1000; % Maximum spot area in pixels (adjust if needed)

%% ===================== READ VIDEO =====================
vid = VideoReader(videoFile);

% Read first frame to compute global threshold
frame1 = readFrame(vid);
gray1 = double(rgb2gray(frame1));
[imgH, imgW] = size(gray1);

globalMax = max(gray1(:));
thresholdValue = thresholdRatio * globalMax;

% Initialize cumulative mask
sweepMask = false(imgH, imgW);

%% ===================== PROCESS ALL FRAMES =====================
vid.CurrentTime = 0;
while hasFrame(vid)
    frame = readFrame(vid);
    gray = double(rgb2gray(frame));
    
    % --- Thresholding ---
    binaryMask = gray >= thresholdValue;

    % --- Extract connected components ---
    CC = bwconncomp(binaryMask);
    stats = regionprops(CC, 'Area');
    
    % --- Accumulate spots within area limit ---
    spotMask = false(size(binaryMask));
    for i = 1:CC.NumObjects
        if stats(i).Area <= maxSpotAreaPixels
            spotMask(CC.PixelIdxList{i}) = true;
        end
    end
    
    sweepMask = sweepMask | spotMask;  % accumulate
end

%% ===================== KEEP LARGEST REGION ONLY =====================
CC = bwconncomp(sweepMask);
if CC.NumObjects > 1
    stats = regionprops(CC, 'Area');
    [~, idxMax] = max([stats.Area]);     % index of largest region
    mainMask = false(size(sweepMask));
    mainMask(CC.PixelIdxList{idxMax}) = true;
    sweepMask = mainMask;                % keep only the largest region
end

%% ===================== EXTRACT BOUNDARY =====================
B = bwboundaries(sweepMask);
if isempty(B)
    warning('No boundaries detected!');
    boundary = [];
else
    boundary = B{1};
end

%% ===================== COMPUTE PHYSICAL AREA =====================
sweepArea_pixels = sum(sweepMask(:));
sweepArea_um2 = sweepArea_pixels * pixelSizeX * pixelSizeY;
fprintf('Total sweep area = %.2f μm²\n', sweepArea_um2);

%% ===================== VISUALIZATION =====================
imshow(frame1);      % show original first frame
hold on;
axis image;

% --- Plot boundary only ---
if ~isempty(boundary)
    plot(boundary(:,2), boundary(:,1), 'g-', 'LineWidth', 2);
end

% --- Set physical axis labels ---
xticks_pix = linspace(1, imgW, 5);
yticks_pix = linspace(1, imgH, 5);
xticks_um = linspace(0, imgW * pixelSizeX, 5);
yticks_um = linspace(0, imgH * pixelSizeY, 5);
set(gca, 'XTick', xticks_pix, 'XTickLabel', round(xticks_um,1), ...
         'YTick', yticks_pix, 'YTickLabel', round(yticks_um,1));

xlabel('X (μm)');
ylabel('Y (μm)');
title('Total Spot Sweep Area Over Entire Video');

% --- Display total area ---
text(20, 40, sprintf('Total Sweep Area = %.2f μm^2', sweepArea_um2), ...
    'Color','yellow', 'FontSize',12, 'FontWeight','bold');
