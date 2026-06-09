function data = load_file(filepath)
%
% INPUT:
%   filepath : string
%       Path to the measurement file
%
% OUTPUT:
%   data : struct
%       Struct containing filename, time, ch2, ch9

% Extract filename without extension
[~, filename, ~] = fileparts(filepath);

% Read tab-separated data
T = readtable(filepath, 'Delimiter', '\t');

% Rename columns for consistency
T.Properties.VariableNames = { ...
    'time_ps', ...
    'channel2_counts', ...
    'channel9_counts'};

% Store data in struct
data.filename = filename;
data.time = T.time_ps;
data.ch2  = T.channel2_counts;
data.ch9  = T.channel9_counts;

end

function dataset = load_dataset(filepaths)
% LOAD_DATASET Load multiple measurement files
%
% INPUT:
%   filepaths : cell array of strings
%       Paths to measurement files
%
% OUTPUT:
%   dataset : struct array
%       Each element contains data from one file

% Initialize empty struct array
dataset = struct('filename', {}, 'time', {}, 'ch2', {}, 'ch9', {});

for i = 1:length(filepaths)

    filepath = filepaths{i};

    % Call the single-file loader
    dataset(i) = load_file(filepath);

end

end

function data = load_scope_file(filepath)
% LOAD_SCOPE_FILE Read oscilloscope CSV file including metadata
%
% INPUT
%   filepath : string
%       Path to oscilloscope CSV file
%
% OUTPUT
%   data : struct
%       data.params  -> struct of scope parameters
%       data.time    -> time vector
%       data.signal  -> waveform signal

fid = fopen(filepath);

lineNumber = 0;
startLine = -1;

params = struct;

while ~feof(fid)

    line = fgetl(fid);
    lineNumber = lineNumber + 1;

    % Detect first waveform line
    if startsWith(line,',,,')
        startLine = lineNumber;
        break
    end

    % Split line by comma
    parts = strsplit(line,',');

    % Parse parameter lines like:
    % "Record Length",4002,"Points"
    if length(parts) >= 2 && ~isempty(parts{1})

        name = erase(parts{1},'"');
        value = str2double(parts{2});

        % If not numeric, keep as string
        if isnan(value)
            value = erase(parts{2},'"');
        end

        % Convert parameter name into valid MATLAB field
        field = matlab.lang.makeValidName(name);

        params.(field) = value;

    end

end

fclose(fid);

if startLine == -1
    error('Waveform data not found in file.');
end

% Read waveform data
M = readmatrix(filepath,'NumHeaderLines',startLine-1);

data.params = params;
data.time   = M(:,4);
data.signal = M(:,5);

end

function data = load_driver_file(filepath)
% Read photon counting measurement file of driver
%
% INPUT
%   filepath : string
%       Path to measurement file
%
% OUTPUT
%   data : struct
%       Struct containing filename and data table

% Extract filename
[~, filename, ~] = fileparts(filepath);

% Read table starting from the header line
T = readtable(filepath, ...
    'Delimiter','\t', ...
    'VariableNamingRule','preserve');

% Store results
data.filename = filename;
data.table = T;

end
%% 
% plot
% plot Channel 2 signal

files = {
    "10nm_500pm_s(1)_2026-03-11_121318.txt"
    "10nm_500pm_s(2)_2026-03-11_121547.txt"
    "10nm_500pm_s(3)_2026-03-11_121547.txt"
};

% Load dataset into a struct array
dataset = load_dataset(files);

% Access the first dataset for plotting
df = dataset(1);  % using index instead of field names

figure
plot(df.time, df.ch2)

xlabel("Time (ps)")
ylabel("Counts per bin")
title("Channel 2 signal")
grid on

%% oscilloscope wavefront for the SNSPD connected to ch5 on the PCB

% Load the oscilloscope file
data = load_scope_file("C4--ch3-cryo36-bias7ua--00000.csv");

% Create figure with white background
figure('Color', 'white');
plot(data.time, data.signal, 'b-', 'LineWidth', 2);  % Blue line with default thickness
grid on;
xlabel('Time (s)', 'FontWeight', 'bold', 'Color', 'black', 'FontSize', 12);
ylabel('Signal (V)', 'FontWeight', 'bold', 'Color', 'black', 'FontSize', 12);
xlim([min(data.time), max(data.time)]); % 注意中间的方括号
title('Oscilloscope Waveform', 'FontWeight', 'bold', 'Color', 'black', 'FontSize', 14);
% Set axes properties: white background, black borders and text
set(gca, 'Color', 'white', ...
         'XColor', 'black', 'YColor', 'black', ...  % Axis lines and ticks in black
         'LineWidth', 1.5, ...                        % Thicker axis border
         'FontWeight', 'bold', ...                     % Tick labels bold
         'GridColor', [0.5 0.5 0.5]);                  % Grid in gray (softer than black)

%% Time tagger laserSweep data with txt
% 1. 配置与加载数据
filename = 'Time_Tagger_measurement.csv';
opts = detectImportOptions(filename, 'FileType', 'text', 'Delimiter', '\t');
opts.VariableNamingRule = 'preserve';
T = readtable(filename);

% 提取数据
time_ps = T{:, 1};           
count_rate_kcps = T{:, 2};    
time_s_full = time_ps / 1e12;            
count_rate_mcps_full = count_rate_kcps / 1e3;
% 
% % --- 新增：筛选 20s 到 80s 的数据 ---
% roi_mask = (time_s_full >= 20) & (time_s_full <= 80);
% time_s = time_s_full(roi_mask);
% count_rate_mcps = count_rate_mcps_full(roi_mask);
% ---------------------------------

% 2. 绘图设置：白底、加粗、黑轴
figure('Color', 'w', 'Position', [150, 150, 900, 600], 'Name', 'Time Tagger Stability Trace');
hold on;

% 绘制计数率曲线（加粗蓝色线）
plot(time_s_full, count_rate_mcps_full, 'Color', [0 0.447 0.741], 'LineWidth', 2.5, 'DisplayName', 'Count Rate');

% 添加半透明填充
area(time_s_full, count_rate_mcps_full, 'FaceColor', [0 0.447 0.741], 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');


% 4. 坐标轴与字体加粗美化
set(gca, 'Box', 'on', 'Color', 'w', ...
    'XColor', 'k', 'YColor', 'k', ...
    'LineWidth', 2, ... 
    'FontWeight', 'bold', ...
    'FontSize', 14, ...
    'GridColor', [0.2 0.2 0.2], 'GridAlpha', 0.2);

xlabel('Time (s)', 'FontSize', 16, 'FontWeight', 'bold');
ylabel('Count Rate (Mcps)', 'FontSize', 16, 'FontWeight', 'bold');

% 5. 激活图例
lgd = legend('Location', 'northeast', 'Color', 'w');
lgd.FontSize = 12;
lgd.FontWeight = 'bold';
lgd.TextColor = 'k';
lgd.EdgeColor = 'k'; 
lgd.LineWidth = 1.5;

% 细节微调
grid on;
xlim([min(time_s_full) max(time_s_full)]);
% 为顶部文字框留出一点纵向空间
% 取 99.5% 分位数作为参考，再给一点裕量
y_limit = quantile(count_rate_mcps_full, 0.995) * 1.2;
ylim([0, y_limit]);


%% Filter of noises in laserSweep
%  1. 加载数据
filename = 'Counter_time_trace.txt'; 
opts = detectImportOptions(filename, 'FileType', 'text', 'Delimiter', '\t');
opts.VariableNamingRule = 'preserve';
T = readtable(filename, opts);

time_ps = T{:, 1};           
count_rate_raw = T{:, 2} / 1e6; % Mcps
time_s = time_ps / 1e12;        

dt = time_s(2) - time_s(1);
Fs = 1 / dt;

% 2. 选取 quiet 区域
quiet_mask = time_s <= 5;
quiet_signal = count_rate_raw(quiet_mask);

% 3. 自动寻找主频（FFT）
Nq = length(quiet_signal);
Y = fft(quiet_signal - mean(quiet_signal));
f = (0:Nq-1) * Fs / Nq;

% 只看正频率
half = 1:floor(Nq/2);
[~, idx] = max(abs(Y(half)));
f0 = f(half(idx));

fprintf('Detected oscillation frequency: %.2f Hz\n', f0);

% 4. 计算周期长度（点数）
T0 = 1 / f0;
samples_per_period = round(T0 / dt);

fprintf('Samples per period: %d\n', samples_per_period);

% 5. 构造"平均周期模板"
num_periods = floor(length(quiet_signal) / samples_per_period);

pattern_matrix = reshape(quiet_signal(1:num_periods * samples_per_period), ...
                         samples_per_period, num_periods);

pattern_template = mean(pattern_matrix, 2);

% 6. 将模板扩展到全信号
num_total_periods = ceil(length(count_rate_raw) / samples_per_period);

pattern_full = repmat(pattern_template, num_total_periods, 1);
pattern_full = pattern_full(1:length(count_rate_raw));

% 7. 去除 pattern（关键步骤）
final_rate = count_rate_raw - pattern_full + mean(pattern_template);

% 8. baseline 对齐（保证 0–5s 不偏）
initial_baseline = mean(count_rate_raw(quiet_mask));
processed_baseline = mean(final_rate(quiet_mask));
final_rate = final_rate + (initial_baseline - processed_baseline);

% 9. 绘图
figure('Color', 'w');

subplot(2,1,1);
plot(time_s, count_rate_raw, 'Color', [0.8 0.8 0.8]); hold on;
plot(time_s, final_rate, 'r', 'LineWidth', 1.5);
xlim([0 5]);
title('Quiet Region (0-5s)');
legend('Raw','Filtered');
grid on;

subplot(2,1,2);
plot(time_s, count_rate_raw, 'Color', [0.8 0.8 0.8]); hold on;
plot(time_s, final_rate, 'r');
title('Full Trace');
xlabel('Time (s)');
ylabel('Rate (Mcps)');
legend('Raw','Filtered');
grid on;

%% Coupling efficiency - normalized
% ===================== 1. 文件列表 =====================
fileNames = {
    'Ch3_780_highest_0.04mW_2026-04-14--12-10-53.txt', ...
    'Ch3_780_lowest_0.04mW_2026-04-14--12-26-53.txt', ...
    'Ch3_940_highest_17mA_2026-04-14--15-04-31.txt', ...
    'Ch3_940_lowest_17mA_2026-04-14--15-06-51.txt', ...
    'Ch3_1550_highest_1.1mW_2026-04-14--13-51-58.txt', ...
    'Ch3_1550_lowest_1.1mW_2026-04-14--13-53-56.txt'
};

dataSummary = struct('wavelength', {}, 'status', {}, 'meanCPS', {}, 'stdCPS', {});

% ===================== 2. 数据读取 =====================
for i = 1:length(fileNames)
    fname = fileNames{i};
    fprintf('Processing: %s...\n', fname);
    
    % 解析文件名
    parts = split(fname, '_');
    wavelength = parts{2};
    
    if contains(parts{3}, 'highest')
        status = 'Coupled';
    else
        status = 'Uncoupled';
    end
    
    % 定位表头
    fid = fopen(fname, 'r');
    headerLine = 0;
    while ~feof(fid)
        line = fgetl(fid);
        headerLine = headerLine + 1;
        if contains(line, 'C1') && contains(line, 'C3')
            break;
        end
    end
    fclose(fid);
    
    % 自动读取
    opts = detectImportOptions(fname, 'FileType', 'text', 'Delimiter', '\t');
    opts.DataLines = headerLine + 1;
    opts.VariableNamingRule = 'preserve';
    
    T = readtable(fname, opts);
    
    % 提取数据
    counts = T.C3;
    it_ms  = T.IT;
    
    % 计算 CPS
    validIdx = it_ms > 0;
    cps_raw = counts(validIdx) ./ (it_ms(validIdx) / 1000);
    
    % 统计
    dataSummary(i).wavelength = wavelength;
    dataSummary(i).status = status;
    dataSummary(i).meanCPS = mean(cps_raw);
    dataSummary(i).stdCPS  = std(cps_raw);
end

% ===================== 3. 整理数据 =====================
wl_list = {'780', '940', '1550'};

coupled_means = zeros(1,3);
uncoupled_means = zeros(1,3);
coupled_stds = zeros(1,3);
uncoupled_stds = zeros(1,3);

for j = 1:3
    wl = wl_list{j};
    
    idx_c = strcmp({dataSummary.wavelength}, wl) & strcmp({dataSummary.status}, 'Coupled');
    idx_u = strcmp({dataSummary.wavelength}, wl) & strcmp({dataSummary.status}, 'Uncoupled');
    
    coupled_means(j)   = dataSummary(idx_c).meanCPS;
    coupled_stds(j)    = dataSummary(idx_c).stdCPS;
    uncoupled_means(j)= dataSummary(idx_u).meanCPS;
    uncoupled_stds(j) = dataSummary(idx_u).stdCPS;
end

% ===================== 4. 归一化（关键步骤） =====================
for j = 1:3
    ref = uncoupled_means(j);
    
    % 防止除0
    if ref < 1e-12
        ref = 1e-12;
    end
    
    coupled_means(j) = coupled_means(j) / ref;
    coupled_stds(j)  = coupled_stds(j) / ref;
    
    uncoupled_stds(j) = uncoupled_stds(j) / ref;
    uncoupled_means(j) = 1; % 基准
end

% ===================== 5. 绘图 =====================
figure('Color', 'w', 'Position', [200 200 850 500]);

y_data = [coupled_means; uncoupled_means]';
err_data = [coupled_stds; uncoupled_stds]';

b = bar(y_data, 'grouped', 'EdgeColor', 'k', 'LineWidth', 1);
hold on;

% 颜色
b(1).FaceColor = [0.2 0.4 0.8];   % Coupled
b(2).FaceColor = [0.85 0.3 0.3];  % Uncoupled

% 误差棒
for k = 1:2
    xP = b(k).XEndPoints;
    errorbar(xP, y_data(:,k), err_data(:,k), ...
        'k', 'LineStyle', 'none', 'LineWidth', 1.2);
end

% 坐标轴设置
ax = gca;
ax.Color = 'w';
ax.XColor = 'k';
ax.YColor = 'k';
ax.LineWidth = 1.2;
ax.FontSize = 12;
box off;

set(gca, 'XTickLabel', strcat(wl_list, ' nm'));

xlabel('Wavelength');
ylabel('Enhancement Factor (Coupled / Uncoupled)');

% 标题
t = title('Coupling Efficiency vs Wavelength');
t.Color = 'k';
t.BackgroundColor = 'w';
t.EdgeColor = 'none';

% 图例
lgd = legend({'Coupled (Signal)', 'Uncoupled (Reference)'}, ...
    'Location', 'northwest');
lgd.TextColor = 'k';
lgd.Color = 'w';
lgd.EdgeColor = 'k';

% 网格
grid on;
ax.GridColor = [0.85 0.85 0.85];
ax.GridAlpha = 0.5;
grid minor;


%%  Coupling Efficiency - unnormalized
%  ===================== 1. 文件列表 =====================
fileNames = {
    'Ch3_780_highest_0.04mW_2026-04-14--12-10-53.txt', ...
    'Ch3_780_lowest_0.04mW_2026-04-14--12-26-53.txt', ...
    'Ch3_940_highest_17mA_2026-04-14--15-04-31.txt', ...
    'Ch3_940_lowest_17mA_2026-04-14--15-06-51.txt', ...
    'Ch3_1550_highest_1.1mW_2026-04-14--13-51-58.txt', ...
    'Ch3_1550_lowest_1.1mW_2026-04-14--13-53-56.txt'
};

dataSummary = struct('wavelength', {}, 'status', {}, 'meanCPS', {}, 'stdCPS', {});

% ===================== 2. 数据读取 =====================
for i = 1:length(fileNames)
    fname = fileNames{i};
    fprintf('Processing: %s...\n', fname);
    
    % 解析文件名
    parts = split(fname, '_');
    wavelength = parts{2};
    
    if contains(parts{3}, 'highest')
        status = 'Coupled';
    else
        status = 'Uncoupled';
    end
    
    % --- 定位表头 ---
    fid = fopen(fname, 'r');
    headerLine = 0;
    while ~feof(fid)
        line = fgetl(fid);
        headerLine = headerLine + 1;
        if contains(line, 'C1') && contains(line, 'C3')
            break;
        end
    end
    fclose(fid);
    
    % --- 自动读取 ---
    opts = detectImportOptions(fname, 'FileType', 'text', 'Delimiter', '\t');
    opts.DataLines = headerLine + 1;
    opts.VariableNamingRule = 'preserve';
    
    T = readtable(fname, opts);
    
    % --- 提取数据 ---
    counts = T.C3;
    it_ms  = T.IT;
    
    % --- 计算 CPS ---
    validIdx = it_ms > 0;
    cps_raw = counts(validIdx) ./ (it_ms(validIdx) / 1000);
    
    % --- 存储 ---
    dataSummary(i).wavelength = wavelength;
    dataSummary(i).status = status;
    dataSummary(i).meanCPS = mean(cps_raw);
    dataSummary(i).stdCPS  = std(cps_raw);
end

% ===================== 3. 整理数据 =====================
wl_list = {'780', '940', '1550'};

coupled_means = zeros(1,3);
uncoupled_means = zeros(1,3);
coupled_stds = zeros(1,3);
uncoupled_stds = zeros(1,3);

for j = 1:3
    wl = wl_list{j};
    
    idx_c = strcmp({dataSummary.wavelength}, wl) & strcmp({dataSummary.status}, 'Coupled');
    idx_u = strcmp({dataSummary.wavelength}, wl) & strcmp({dataSummary.status}, 'Uncoupled');
    
    coupled_means(j)   = dataSummary(idx_c).meanCPS;
    coupled_stds(j)    = dataSummary(idx_c).stdCPS;
    uncoupled_means(j)= dataSummary(idx_u).meanCPS;
    uncoupled_stds(j) = dataSummary(idx_u).stdCPS;
end

% ===================== 4. 绘图（原始 CPS） =====================
figure('Color', 'w', 'Position', [200 200 850 500]);

y_data = [coupled_means; uncoupled_means]';
err_data = [coupled_stds; uncoupled_stds]';

b = bar(y_data, 'grouped', 'EdgeColor', 'k', 'LineWidth', 1);
hold on;

% 颜色（论文风格）
b(1).FaceColor = [0.2 0.4 0.8];   % Coupled
b(2).FaceColor = [0.85 0.3 0.3];  % Uncoupled

% 误差棒
for k = 1:2
    xP = b(k).XEndPoints;
    errorbar(xP, y_data(:,k), err_data(:,k), ...
        'k', 'LineStyle', 'none', 'LineWidth', 1.2);
end

% 坐标轴
ax = gca;
ax.Color = 'w';
ax.XColor = 'k';
ax.YColor = 'k';
ax.LineWidth = 1.2;
ax.FontSize = 12;

set(gca, 'XTickLabel', strcat(wl_list, ' nm'));

xlabel('Wavelength');
ylabel('Count Rate (CPS)');

% log 轴（原始数据建议保留）
set(gca, 'YScale', 'log');

% 标题（白底黑字）
t = title('Integrated SNSPD Coupling Test');
t.Color = 'k';
t.BackgroundColor = 'w';
t.EdgeColor = 'none';

% 图例（白底黑字）
lgd = legend({'Coupled (Signal)', 'Uncoupled (Background)'}, ...
    'Location', 'northwest');
lgd.TextColor = 'k';
lgd.Color = 'w';
lgd.EdgeColor = 'k';

% 网格（浅灰）
grid on;
ax.GridColor = [0.85 0.85 0.85];
ax.GridAlpha = 0.5;
grid minor;
