clc; clear;

%% ===== Initialize Webcam with Safety Check =====
try
    cam = webcam;
    camConnected = true;
    disp('Webcam connected successfully.');
catch
    cam = [];
    camConnected = false;
    warning('No webcam detected! Switching to blank black screen mode.');
end

% Default parameters
contrastGain = 1.0;
brightnessLevel = 0.0;
isRecording = false;
videoObj = [];
photoCount = 0;

%% ===== Create UI =====
hFig = uifigure('Name','Webcam Controller','Position',[100 100 1000 600]);

% 将核心共享变量存储在 App 的 UserData 中，避免使用 evalin/assignin
appData.cam = cam;
appData.camConnected = camConnected;
appData.photoCount = photoCount;
hFig.UserData = appData;

% Axes for video preview
ax = uiaxes(hFig,'Position',[25 150 640 420]);
axis(ax,'off')

%% ===== Control Panel =====
controlPanel = uipanel(hFig,'Title','Image Controls',...
    'Position',[700 350 260 220]);

% Contrast slider
uilabel(controlPanel,'Text','Contrast','Position',[20 150 100 22]);
contrastSlider = uislider(controlPanel,...
    'Limits',[0 5],'Value',1,...
    'Position',[20 140 200 3]);

% Brightness slider
uilabel(controlPanel,'Text','Brightness','Position',[20 90 100 22]);
brightnessSlider = uislider(controlPanel,...
    'Limits',[-0.5 0.5],'Value',0,...
    'Position',[20 80 200 3]);

%% ===== Photo Panel =====
photoPanel = uipanel(hFig,'Title','Photo','Position',[700 220 260 110]);
captureBtn = uibutton(photoPanel,'Text','Capture Photo',...
    'Position',[40 40 180 40],...
    'ButtonPushedFcn',@capturePhoto);

%% ===== Video Panel =====
videoPanel = uipanel(hFig,'Title','Video Recording',...
    'Position',[700 90 260 110]);
recordBtn = uibutton(videoPanel,'Text','Start Recording',...
    'Position',[40 40 180 40],...
    'ButtonPushedFcn',@toggleRecording);

%% ===== Main Loop =====
while isvalid(hFig)
    % 检查相机状态：若未连接，则生成全黑图像 (480x640x3 RGB 全零矩阵)
    if camConnected
        try
            frame = snapshot(cam);
            img = im2double(frame);
        catch
            % 运行中如果相机被拔掉，触发此保护
            img = zeros(480, 640, 3);
        end
    else
        img = zeros(480, 640, 3); 
    end
    
    % Get slider values
    contrastGain = contrastSlider.Value;
    brightnessLevel = brightnessSlider.Value;
    
    % Apply adjustments
    adjusted = contrastGain * img + brightnessLevel;
    adjusted = max(min(adjusted,1),0);
    imshow(adjusted,'Parent',ax);
    
    % 从基础工作区读取最新的录制状态（供回调函数控制）
    isRecording = evalin('base','isRecording');
    if isRecording
        videoObj = evalin('base','videoObj');
        writeVideo(videoObj, adjusted);
    end
    
    drawnow limitrate
end

%% ===== Cleanup =====
isRecording = evalin('base','isRecording');
if isRecording
    videoObj = evalin('base','videoObj');
    close(videoObj);
end
if ~isempty(cam)
    clear cam
end

%% ===== Local Functions =====
function capturePhoto(btn,~)
    % 从 uifigure 的 UserData 中安全获取数据
    hFig = ancestor(btn, 'figure');
    appData = hFig.UserData;
    
    appData.photoCount = appData.photoCount + 1;
    hFig.UserData = appData; % 写回计数
    
    contrastGain = evalin('base','contrastGain');
    brightnessLevel = evalin('base','brightnessLevel');
    
    % 根据是否连接相机决定截取真图还是纯黑图
    if appData.camConnected
        try
            frame = snapshot(appData.cam);
            img = im2double(frame);
        catch
            img = zeros(480, 640, 3);
        end
    else
        img = zeros(480, 640, 3);
    end
    
    adjusted = contrastGain * img + brightnessLevel;
    adjusted = max(min(adjusted,1),0);
    
    currentTime = clock; 
    timeStamp = sprintf('%02d%02d%02d%02d%02d', ...
        currentTime(2), currentTime(3), currentTime(4), currentTime(5), round(currentTime(6)));
    
    folderName = fullfile(pwd, 'results');
    filename = sprintf('photo_%s_C%.2f_B%.2f.png', timeStamp, contrastGain, brightnessLevel);
    fullPath = fullfile(folderName, filename);
    
    % 如果路径不存在则自动创建，防止保存失败报错
    if ~exist(folderName, 'dir')
        mkdir(folderName);
    end
    
    imwrite(adjusted, fullPath);
    disp(['Saved ', fullPath]);
end

function toggleRecording(btn,~)
    isRecording = evalin('base','isRecording');
    contrastGain = evalin('base','contrastGain');
    brightnessLevel = evalin('base','brightnessLevel');
    
    if ~isRecording
        % Start recording
        filename = sprintf('video_C%.2f_B%.2f.avi', contrastGain, brightnessLevel);
        videoObj = VideoWriter(filename);
        open(videoObj);
        assignin('base','videoObj',videoObj);
        assignin('base','isRecording',true); % 兼容改写
        assignin('base','isRecording',true);
        btn.Text = 'Stop Recording';
        disp(['Recording started: ', filename])
    else
        % Stop recording
        videoObj = evalin('base','videoObj');
        close(videoObj);
        assignin('base','isRecording',false);
        btn.Text = 'Start Recording';
        disp('Recording stopped.')
    end
end
