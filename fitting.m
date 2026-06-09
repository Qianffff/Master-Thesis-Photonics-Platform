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

function saveDataCallback(BC, net_CR, custom_col_name, save_filename, hFig)
    % 1. Append Column Data to File
    col_to_save = char(custom_col_name); 
    if exist(save_filename, 'file')
        T_total = readtable(save_filename, 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
        BC_base = T_total.BC_uA; 
        
        if length(net_CR) ~= length(BC_base)
            fprintf('Data length mismatch detected. Applying automated linear interpolation alignment...\n');
            eff_aligned = interp1(BC, net_CR, BC_base, 'linear', 'extrap');
            T_total.(col_to_save) = eff_aligned;
        else
            T_total.(col_to_save) = net_CR;
        end
        fprintf('Successfully appended/updated column "%s" in file %s.\n', col_to_save, save_filename);
    else
        varNames = {'BC_uA', col_to_save}; 
        T_total = table(BC, net_CR, 'VariableNames', varNames);
        fprintf('Created new file and stored column data: %s\n', col_to_save);
    end
    writetable(T_total, save_filename, 'Delimiter', '\t');
    
    % 2. Export High-Resolution Image File
    folderName = fullfile(pwd, 'results');
    if ~exist(folderName, 'dir')
        mkdir(folderName);
    end
    img_filename = sprintf('%s.png', custom_col_name);
    fullImagePath = fullfile(folderName, img_filename);
    
    % Temporarily hide button to ensure clean canvas export
    btn = findobj(hFig, 'Style', 'pushbutton');
    set(btn, 'Visible', 'off');
    saveas(hFig, fullImagePath);
    set(btn, 'Visible', 'on'); 
    
    fprintf('Saved image to: %s\n', fullImagePath);
end

%% Load SNSPD data from driver

filepath = "DCR_LNOI_ICP_PE_2026-05-22--12-22-32.txt";
data = load_driver_file(filepath);

BC = data.table.BC; % Bias Current

% --- Select channels ---
selected_channels = [1,2,3,5,6,7]; 
% -----------------------

colors = lines(length(selected_channels));

figure('Color', 'w', 'Name', 'IV + Counts');

% ===== 左图：IV Curve =====
subplot(1,2,1);
hold on;

for k = 1:length(selected_channels)
    i = selected_channels(k);
    colName = ['BV', num2str(i)];
    
    if ismember(colName, data.table.Properties.VariableNames)
        plot(BC, data.table.(colName), ...
            'Color', colors(k,:), ...
            'LineWidth', 2, ...
            'DisplayName', ['Ch ', num2str(i)]);
    end
end

xlabel('Bias Current (\muA)');
ylabel('Bias Voltage (V)');
title('IV Curves');
legend('show');
grid on;
box on;


% ===== 右图：Counts =====
subplot(1,2,2);
hold on;

IT = data.table.IT; % ms

for k = 1:length(selected_channels)
    i = selected_channels(k);
    colName = ['C', num2str(i)];
    
    if ismember(colName, data.table.Properties.VariableNames)
        
        % 👉 推荐用 count rate（更标准）
        count_rate = data.table.(colName) ./ (IT / 1000);
        
        plot(BC, count_rate, ...
            'Color', colors(k,:), ...
            'LineWidth', 2, ...
            'DisplayName', ['Ch ', num2str(i)]);
    end
end

xlabel('Bias Current (\muA)');
ylabel('Count Rate (Hz)');
title('Counts vs Bias Current');
legend('show');
grid on;
box on;



%% ===== SNSPD Saturation & DCR Visualizer (Dual-Panel) =====
filepath = "CR.txt";
dark_filepath = "DCR.txt";
save_filename = "Processed_Efficiency_Results.txt"; 
custom_col_name = 'LNOI_10';

% Load Data
data = load_driver_file(filepath);
dark_data = load_driver_file(dark_filepath);

% ===== Align and Crop Data =====
target_channel = 'C2'; Ic = 9.8;
BC_light = data.table.BC;
BC_dark  = dark_data.table.BC;
CR_raw  = data.table.(target_channel);
DCR_raw = dark_data.table.(target_channel);

% --- Align DCR Data ---
bias_offset = 0.3;
BC_shifted = BC_light - bias_offset;
idx_valid = (BC_shifted >= min(BC_dark)) & (BC_shifted <= max(BC_dark));

BC = BC_light(idx_valid);
CR_raw = CR_raw(idx_valid);
BC_shifted = BC_shifted(idx_valid);
DCR_aligned = interp1(BC_dark, DCR_raw, BC - bias_offset, 'linear'); 

% --- Calculate Net Count Rate ---
net_CR = CR_raw - DCR_aligned;

fprintf('CR max: %.2f\n', max(CR_raw));
fprintf('DCR max: %.2f\n', max(DCR_aligned));
fprintf('net_CR max: %.2f\n', max(net_CR));

% --- Sigmoid Curve Fitting ---
myfittype = fittype('a/(1+exp(-c*(x-b)))', 'coefficients', {'a','b','c'});
options = fitoptions('Method','NonlinearLeastSquares', ...
                     'StartPoint', [max(net_CR), Ic*0.6, 1], ...
                     'Lower', [0, 0, 0]); 
idx_fit = BC < 0.9 * Ic;
cfun = fit(BC(idx_fit), net_CR(idx_fit), myfittype, options);
A_sat = cfun.a; 

% ===== Visualization: Side-by-Side Dual Subplots =====
% 设定精美的 1400x700 比例窗口
hFig = figure('Color', 'w', 'Position', [50, 100, 1500, 700], 'Name', 'Data Preview');

% --------------------------------------------------------
% LEFT PANEL: Absolute Net Count Rate Analysis
% --------------------------------------------------------
subplot(1, 2, 1);
p1 = plot(BC, net_CR, 'bo-', 'LineWidth', 2.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', 'b', 'DisplayName', 'Net Count Rate (Signal)');
hold on;

x_fit = linspace(min(BC), max(BC), 500);
y_fit = cfun(x_fit);
p2 = plot(x_fit, y_fit, 'r-', 'LineWidth', 3.5, 'DisplayName', 'Sigmoid Fit');

p3 = plot(BC, DCR_aligned, 'ks--', 'LineWidth', 1.8, 'MarkerSize', 5, ...
    'MarkerFaceColor', 'k', 'DisplayName', 'Dark Count Rate (DCR)');

p4 = xline(Ic, '--g', 'LineWidth', 2.5, 'DisplayName', 'I_c Limit');

% 全局加粗加黑坐标轴环境
set(gca, 'Box', 'on', 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'LineWidth', 2, ... 
    'FontWeight', 'bold', 'FontSize', 13, 'GridColor', [0.1 0.1 0.1], 'GridAlpha', 0.15);
xlabel('Bias Current (\muA)', 'FontSize', 15, 'FontWeight', 'bold', 'Color', [0 0 0]);
ylabel('Count Rate (cps)', 'FontSize', 15, 'FontWeight', 'bold', 'Color', [0 0 0]);

% 【参数框强化】不仅整合到上方，还加粗加黑了文本字体
title_text = {['\bf\color[rgb]{0,0,0}SNSPD Count Rate'], ...
              sprintf('\\bf\\fontsize{11}\\color[rgb]{0,0,0}Saturated CR = %.1f kcps  |  I_{50%%} = %.2f \\muA  |  I_{c} = %.1f \\muA', A_sat/1000, cfun.b, Ic)};
title(title_text, 'FontSize', 14);

% 禁用左图的 Y 轴科学计数法，加黑刻度标签
ax1 = gca;
ax1.YAxis.Exponent = 0;
ax1.YAxis.TickLabelFormat = '%.0f';

% 【图例优化】水平放置于左图正下方外侧，加粗加黑、框线明显
lgd1 = legend([p1, p2, p3, p4], 'Location', 'southoutside', 'Orientation', 'horizontal', 'Color', 'w');
lgd1.FontSize = 11; lgd1.FontWeight = 'bold'; lgd1.EdgeColor = [0 0 0]; lgd1.LineWidth = 1.2;

ylim([0, A_sat * 1.15]); 
xlim([Ic*0.2, Ic*1.1]);
grid on;

% --------------------------------------------------------
% RIGHT PANEL: Full DCR Profile View (Linear Scale)
% --------------------------------------------------------
subplot(1, 2, 2);
p5 = plot(BC, DCR_aligned, 'ks--', 'LineWidth', 1.8, 'MarkerSize', 5, ...
    'MarkerFaceColor', 'k', 'DisplayName', 'Raw DCR Profile');
hold on;

p6 = xline(Ic, '--g', 'LineWidth', 2.5, 'DisplayName', 'I_c Limit');

% 全局加粗加黑坐标轴环境
set(gca, 'Box', 'on', 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'LineWidth', 2, ... 
    'FontWeight', 'bold', 'FontSize', 13, 'GridColor', [0.1 0.1 0.1], 'GridAlpha', 0.15);
xlabel('Bias Current (\muA)', 'FontSize', 15, 'FontWeight', 'bold', 'Color', [0 0 0]);
ylabel('Dark Count Rate (cps)', 'FontSize', 15, 'FontWeight', 'bold', 'Color', [0 0 0]);

% 右图标题加黑
title_text_right = {['\bf\color[rgb]{0,0,0}Complete Dark Count Rate (DCR) Sweep'], ''}; % 增加空行平衡双图高度
title(title_text_right, 'FontSize', 14);

% 禁用右图的 Y 轴科学计数法，加黑刻度标签
ax2 = gca;
ax2.YAxis.Exponent = 0;
ax2.YAxis.TickLabelFormat = '%.0f';

% 【图例优化】同样水平放置于右图正下方外侧，确保两图左右宽度完美的 1:1 对称
lgd2 = legend([p5, p6], 'Location', 'southoutside', 'Orientation', 'horizontal', 'Color', 'w');
lgd2.FontSize = 11; lgd2.FontWeight = 'bold'; lgd2.EdgeColor = [0 0 0]; lgd2.LineWidth = 1.2;

xlim([Ic*0.2, Ic*1.1]);
ylim([0, max(DCR_raw)*1.15]);
grid on;

% ===== UI Interactive Control =====
% 按钮下移，防止影响底部的美化图例
uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Save Data/Image', ...
    'Units', 'normalized', 'Position', [0.42, 0.01, 0.16, 0.04], ...
    'FontSize', 11, 'FontWeight', 'bold', 'ForegroundColor', 'w', ...
    'BackgroundColor', [0.1, 0.5, 0.2], ...
    'Callback', @(src, event) saveDataCallback(BC, net_CR, custom_col_name, save_filename, hFig));

disp('▲ Preview figure generated. Verify curves and click "Confirm & Save Data/Image" to export data.');

%% LaserSweep data with csv (developed gui) (stiching version)
% 1. 配置与加载数据
filename = 'Time_Tagger_measurement.csv';

opts = detectImportOptions(filename, 'FileType', 'text', 'Delimiter', '\t');
opts.VariableNamingRule = 'preserve';
T = readtable(filename);

% 提取数据
wavelength_full = T{:, 1};           
count_rate_kcps = T{:, 2};               
count_rate_mcps_full = count_rate_kcps / 1e3;

% 2. 绘图设置
figure('Color', 'w', 'Position', [150, 150, 900, 600], ...
       'Name', 'Laser Sweep Trace');
hold on;

% 3. Nature 风格配色
nature_colors = [
    0.121, 0.466, 0.705;  % blue
    1.000, 0.498, 0.054;  % orange
    0.172, 0.627, 0.172;  % green
    0.839, 0.152, 0.156;  % red
    0.580, 0.404, 0.741;  % purple
];

% 4. 按 10 nm 分段填充阴影
wl_min = floor(min(wavelength_full)/10)*10;
wl_max = ceil(max(wavelength_full)/10)*10;
segment_edges = wl_min:10:wl_max;

for i = 1:length(segment_edges)-1
    mask = (wavelength_full >= segment_edges(i)) & ...
           (wavelength_full < segment_edges(i+1));
       
    if any(mask)
        color_idx = mod(i-1, size(nature_colors,1)) + 1;
        
        area(wavelength_full(mask), ...
             count_rate_mcps_full(mask), ...
             'FaceColor', nature_colors(color_idx,:), ...
             'FaceAlpha', 0.15, ...
             'EdgeColor', 'none', ...
             'HandleVisibility', 'off');
    end
end

% 5. 主曲线（加粗）
plot(wavelength_full, count_rate_mcps_full, ...
     'Color', [0 0.447 0.741], ...
     'LineWidth', 2.5, ...
     'DisplayName', 'Count Rate');

% 6. 坐标轴美化
set(gca, 'Box', 'on', 'Color', 'w', ...
    'XColor', 'k', 'YColor', 'k', ...
    'LineWidth', 1.8, ... 
    'FontWeight', 'bold', ...
    'FontSize', 14, ...
    'GridColor', [0.2 0.2 0.2], ...
    'GridAlpha', 0.2);

xlabel('Wavelength (nm)', 'FontSize', 16, 'FontWeight', 'bold');
ylabel('Count Rate (Mcps)', 'FontSize', 16, 'FontWeight', 'bold');

% 7. 图例
lgd = legend('Location', 'northeast');
lgd.FontSize = 12;
lgd.FontWeight = 'bold';
lgd.TextColor = 'k';
lgd.EdgeColor = 'k'; 
lgd.LineWidth = 1.2;

% 8. 网格与范围（关键修改在这里）
grid on;

% ✔ x 轴完整范围
xlim([min(wavelength_full) max(wavelength_full)]);

% ✔ y 轴完整显示（不再裁剪）
ylim([0, max(count_rate_mcps_full)*1.05]);

%% LaserSweep data with csv (developed GUI)
% 1. Configuration and Load Data
filename = 'Time_Tagger_measurement';
% Detect import options and set delimiter to tab as per the file structure
opts = detectImportOptions(filename, 'FileType', 'text', 'Delimiter', '\t');
opts.VariableNamingRule = 'preserve'; % Keep original headers including underscores
% Read the table using the specified options
T = readtable(filename);

% ===================== 【新增：目标显示范围参数】 =====================
x_start_plot = 1550;  % 你想截取的起始波长 (nm)
x_end_plot   = 1552.5;  % 你想截取的终止波长 (nm)
% ===================================================================

% Extract data from columns
x_raw = T{:, 1};           
y_raw = T{:, 2}; % This corresponds to the 'Intensity_V' column

% ===================== 【关键修改：过滤并裁剪数据】 =====================
% 找到所有落在目标范围内的点（布尔索引）
roi_idx = (x_raw >= x_start_plot) & (x_raw <= x_end_plot);

% 仅提取该范围内的 X 和 Y 轴数据
x = x_raw(roi_idx);
y = y_raw(roi_idx);

% 容错处理：万一输入范围在数据里找不到任何点，则回退使用原始数据
if isempty(x)
    warning('指定范围没有对应数据，将显示完整曲线！');
    x = x_raw;
    y = y_raw;
end
% ===================================================================

% 2. Plotting Setup: White background, Bold, Black axes
figure('Color', 'w', 'Position', [150, 150, 900, 600], 'Name', 'Laser Sweep Trace');
hold on;

% Plot the trace with a thick blue line
plot(x, y, 'Color', [0 0.447 0.741], 'LineWidth', 2.5, 'DisplayName', 'Trace');

% 3. Axis and Font Customization
set(gca, 'Box', 'on', 'Color', 'w', ...
    'XColor', 'k', 'YColor', 'k', ...
    'LineWidth', 2, ... 
    'FontWeight', 'bold', ...
    'FontSize', 14, ...
    'GridColor', [0.2 0.2 0.2], 'GridAlpha', 0.2);

% Set labels using the first row names from the table
% 'Interpreter', 'none' prevents underscores from becoming subscripts
xlabel(T.Properties.VariableNames{1}, 'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');
ylabel(T.Properties.VariableNames{2}, 'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');

% 4. Legend Settings
lgd = legend('Location', 'northeast', 'Color', 'w');
lgd.FontSize = 12;
lgd.FontWeight = 'bold';
lgd.TextColor = 'k';
lgd.EdgeColor = 'k'; 
lgd.LineWidth = 1.5;

% 5. Details Fine-tuning
grid on;

% 这里的 xlim 此时会自动精确卡在 [1540, 1560]
xlim([min(x) max(x)]);

% Adjust Y-axis limits
% 关键点：这里的 y_max_limit 和 y_min_limit 此时也只会根据你截取的 1540-1560 之间的数据计算，
% 保证了在答辩 PPT 或论文里，这截核心环形谐振器（Ring Resonator）的光谱波形具有最佳的垂直放大视觉效果。
y_max_limit = quantile(y, 0.995) * 1.1; 
y_min_limit = min(y) * 0.95;
ylim([y_min_limit, y_max_limit]);

hold off;

%% Fitting and Selective Saving (Interactive Mode)
% ==== Configuration ====
filename = 'DAC';
output_file = 'fitting_results_table.txt';
output_dir = 'Fitted_Peaks_DAC';

% Load data
data = readmatrix(filename, 'NumHeaderLines', 2);
wavelength = data(:,1);
power = data(:,2);

% Nature Style Colors
nature_pink = [0.95 0.62 0.68];
nature_blue = [0.00 0.34 0.73];

% Potential peaks to process
lambda_mids_all = [1531.78, 1532.93, 1534.09, 1537.56, 1538.72, 1541.05, 1542.22, 1543.39, 1544.56, 1545.73, 1546.90, 1548.08, 1549.26, 1550.44,...
    1551.63, 1552.81, 1554.00, 1555.19, 1556.38, 1557.57, 1558.76, 1559.97, 1561.17, 1562.37, 1563.57, 1564.78, 1565.99, 1567.20, 1568.41, 1569.63, 1570.85, 1572.07, 1573.29, 1574.51, 1575.74,...
    1576.97, 1578.19, 1579.43, 1580.67]; 
all_results = cell(length(lambda_mids_all), 1); % Store results for selective logging

if ~exist(output_dir, 'dir'), mkdir(output_dir); end

% ==== 1. Step One: Fit, Plot, and Save ALL Peaks ====
fprintf('--- Step 1: Processing all peaks (Plotting & Saving Images) ---\n');

for i = 1:length(lambda_mids_all)
    mid = lambda_mids_all(i);
    idx = wavelength > (mid - 0.05) & wavelength < (mid + 0.05);
    if ~any(idx), continue; end
    
    l_fit = wavelength(idx);
    t_fit = power(idx) ./ max(power(idx));
    
    % Fitting
    [~, mIdx] = min(t_fit);
    p0 = [0.99, 0, 1-min(t_fit), l_fit(mIdx), 2e-3];
    res = fit_lorentzian_dip(l_fit, t_fit, p0, [0.7 -5 0 mid-0.05 0.5e-3], [1.3 5 1 mid+0.05 10e-3]);
    % Store the result structure for later data logging
    all_results{i} = res;
    
    % Create Figure (Visible for inspection)
    fig = figure('Color', 'w', 'Name', sprintf('Peak %.3f nm', res.center)); 
    hold on;
    scatter(l_fit, t_fit, 60, nature_blue, 'filled', 'MarkerFaceAlpha', 0.2);
    plot(l_fit, res.yfit, 'Color', nature_pink, 'LineWidth', 2);
    title(['Fitted: ' num2str(res.center, '%.3f') ' nm']);
    xlabel('Wavelength (nm)'); ylabel('Normalized Transmission');
    grid on; hold off;
    
    % Save Image immediately
    img_name = sprintf('Peak_%.3f_nm.png', res.center);
    exportgraphics(fig, fullfile(output_dir, img_name), 'Resolution', 300);
    fprintf('Image saved: %s\n', img_name);
end

% ==== 2. Step Two: User Selection for Data Logging ====
fprintf('\n--- Action Required ---\n');
fprintf('All images are saved in "%s".\n', output_dir);
target_input = input('Enter the wavelengths to LOG into the TXT file [w1, w2, ...] (Enter for none): ');

if isempty(target_input)
    fprintf('No data logged. Program finished.\n');
    return;
end

% ==== 3. Step Three: Log Selected Data to File ====
file_exists = exist(output_file, 'file');
fid = fopen(output_file, 'a'); 
if ~file_exists || dir(output_file).bytes == 0
    fprintf(fid, 'Center_WL(nm)\tFWHM(pm)\tTmin\tQ_loaded\tQ_intrinsic\tRMS\tSource_File\n');
end

logged_count = 0;
for i = 1:length(all_results)
    res = all_results{i};
    if isempty(res), continue; end
    
    % Check if this result's center wavelength is near any target_input
    % We use a small tolerance (e.g., 0.01nm) to match the input
    if any(abs(target_input - res.center) < 0.01)
        fprintf('Logging data for: %.3f nm\n', res.center);
        fprintf(fid, '%-18.6f %-12.6f %-10.6f %-12.1f %-12.1f %-10.4f %-s\n', ...
            res.center, res.FWHM*1e3, res.Tmin, res.Qloaded, res.Qintrin, res.RMS, filename);
        logged_count = logged_count + 1;
    end
end

fclose(fid);
fprintf('\nSuccess! %d peaks logged to %s.\n', logged_count, output_file);

%% FWHM plotting
% 1. 读取数据
filename = 'fitting_results_table.txt';
% 使用 detectImportOptions 来确保正确识别格式
opts = detectImportOptions(filename);
% 强制要求 table 保持原始表头字符，不进行转换（有些版本有效）
opts.VariableNamingRule = 'preserve'; 
data = readtable(filename, opts);

% 2. 自动定位列名（解决报错的核心逻辑）
% 打印所有列名，方便你检查
disp('识别到的表变量名称有：');
disp(data.Properties.VariableNames);

% 方案 A：使用模糊匹配寻找包含 'Center' 和 'FWHM' 的列
all_names = data.Properties.VariableNames;
wl_col = all_names(contains(all_names, 'Center', 'IgnoreCase', true));
fwhm_col = all_names(contains(all_names, 'FWHM', 'IgnoreCase', true));

if ~isempty(wl_col) && ~isempty(fwhm_col)
    wavelengths = data.(wl_col{1});
    fwhm_pm = data.(fwhm_col{1});
else
    % 方案 B：如果匹配不到，直接用列索引（根据你提供的表头，第1列是波长，第2列是FWHM）
    wavelengths = data{:, 1}; 
    fwhm_pm = data{:, 2};
end

% 3. 排序（防止连线乱跳）
[wavelengths, idx] = sort(wavelengths);
fwhm_pm = fwhm_pm(idx);

% 4. 绘图
figure('Color', 'w');
plot(wavelengths, fwhm_pm, 'o', ...
    'MarkerSize', 10, ...          % 点的大小
    'MarkerFaceColor', 'b', ...    % 点的填充颜色
    'MarkerEdgeColor', 'b', ... % 点的边缘颜色（黑色）
    'LineWidth', 1.2);             % 边缘线条粗细
grid on;
ylim([0, 25]);
xlabel('Center Wavelength (nm)');
ylabel('FWHM (pm)');
title('FWHM Variation with Wavelength');

%% FSR plotting
% Load the data from the text file
filename = 'fitting_results_table.txt';
opts = detectImportOptions(filename);
data = readtable(filename, opts);

% Access wavelength data by column index
all_wl = data{:, 1}; 

% Sort all wavelengths to maintain sequence
sorted_wl = sort(all_wl);

% Calculate the FSR (difference between adjacent peaks)
diff_wl = diff(sorted_wl); 

% Calculate the midpoint wavelength for the X-axis
mid_wl = sorted_wl(1:end-1) + diff_wl/2;

% Filter valid FSR values (ignore gaps > 1.4nm or < 1.0nm)
valid_idx = (diff_wl > 1.0) & (diff_wl < 1.23);
fsr_clean = diff_wl(valid_idx);
wl_clean = mid_wl(valid_idx);

% Create the visualization
figure('Color', 'w', 'Position', [100, 100, 800, 500]);
% Use 'box on' to add top and right border lines
plot(wl_clean, fsr_clean, 'o',  ...
     'MarkerSize', 10, 'MarkerFaceColor', '#D95319', 'Color', '#D95319');

% Styling the axes
grid on;
box on; % This adds the top and right boundaries
set(gca, 'LineWidth', 1); % Optional: adjust border thickness

% Set plot annotations
title('FSR Variation with Wavelength', 'FontSize', 14);
xlabel('Center Wavelength (nm)', 'FontSize', 12);
ylabel('Free Spectral Range (nm)', 'FontSize', 12);

%% FSR fitting
% 1. 数据加载与预处理
filename = 'fitting_results_table2.txt';
opts = detectImportOptions(filename);
data = readtable(filename, opts);

all_wl = data{:, 1}; 
sorted_wl = sort(all_wl);
diff_wl = diff(sorted_wl); 
mid_wl = sorted_wl(1:end-1) + diff_wl/2;

% 2. 整数倍还原逻辑 (处理缺失峰)
% 设定一个参考 FSR 基准（例如 1.2nm 左右）
fsr_ref = 1.2; 

% 计算每个间隔是基准的几倍并取整
m_multiples = round(diff_wl ./ fsr_ref);
% 确保倍数至少为 1
m_multiples(m_multiples < 1) = 1;

% 将原始间隔除以倍数，还原为单倍 FSR
fsr_normalized = diff_wl ./ m_multiples;

% 进行最终过滤，剔除偏离合理的单倍 FSR 范围（1.0 - 1.4nm）以外的异常噪声点
valid_idx = (fsr_normalized > 1.0) & (fsr_normalized < 1.23);
fsr_clean = fsr_normalized(valid_idx);
wl_clean = mid_wl(valid_idx);

% 3. 物理公式拟合 (将 ng 视为常数)
% 定义腔长 L_total (单位: nm, 2*pi*120 micron -> nm)
L_total_nm = (2*pi*120) * 1e3; 

% 定义拟合模型: FSR = (lambda^2) / (ng * L)
ft = fittype('(x.^2) / (ng * L)', 'problem', 'L', 'options', fitoptions('Method', 'NonlinearLeastSquares'));

% 执行拟合，设定 ng 初始猜测值为 4.0
[fit_result, ~] = fit(wl_clean, fsr_clean, ft, 'problem', L_total_nm, 'StartPoint', 4.0);

% 提取拟合出的 ng 值
ng_fitted = fit_result.ng;

% 4. 绘图与标注
figure('Color', 'w', 'Position', [100, 100, 850, 600]); % 稍微加宽加高了一点画布，防止字体变大后拥挤
hold on; box on; grid on;

% 绘制经过还原和清理后的测量点
hData = plot(wl_clean, fsr_clean, 'o', 'MarkerSize', 8, ...
             'MarkerFaceColor', '#D95319', 'Color', '#D95319', 'DisplayName', 'Normalized FSR');

% 绘制基于常数 ng 的物理拟合曲线
wl_plot = linspace(min(wl_clean), max(wl_clean), 100);
fsr_plot = (wl_plot.^2) / (ng_fitted * L_total_nm);
hFit = plot(wl_plot, fsr_plot, 'k-', 'LineWidth', 2, 'DisplayName', 'Physical Fit');

% ==================== 【字体放大核心设置区域】 ====================
% 1. 设置坐标轴刻度字体大小为 14（原 11）
set(gca, 'LineWidth', 1.5, 'FontSize', 14); 

% 2. 显式设置标题、标签字体（标题 18，标签 16）
title('FSR Variation and n_g Extraction', 'FontSize', 18, 'FontWeight', 'bold');
xlabel('Center Wavelength (nm)', 'FontSize', 16);
ylabel('Free Spectral Range (nm)', 'FontSize', 16);

% 3. 设置图例字体为 14
lgd = legend('show', 'Location', 'southeast'); % 移到了右下角，防止挡住左上角放大的文本框
set(lgd, 'FontSize', 14);

% 4. 设置左上角拟合结果文本框字体为 15（原 13）
ylim([min(fsr_clean)*0.98, max(fsr_clean)*1.02]);
xl = xlim; yl = ylim;
text_x = xl(1) + (xl(2)-xl(1))*0.05;
text_y = yl(2) - (yl(2)-yl(1))*0.12; % 稍微向下微调了一点，避免贴顶
str = {'\bfFitted Constant:', ['\itn_g \rm = ', num2str(ng_fitted, '%.4f')]};
text(text_x, text_y, str, 'FontSize', 25, 'BackgroundColor', [1 1 1 0.8], 'EdgeColor', 'k');
% ==================================================================


%% ===== Dual-SNSPD Efficiency & DCR Visualizer =====
filepath = "CR.txt";
dark_filepath = "DCR.txt";
save_filename = "Processed_Efficiency_Results.txt"; 

% ========================================================
%  【自定义配置区】 在这里直接修改设备名称、通道和临界电流
% ========================================================
dev1_name = 'LCPCVD';  % 设备 1 自定义名字
ch1 = 'C2'; Ic1 = 9.8; bias_offset1 = 0.3;

dev2_name = 'PECVD';   % 设备 2 自定义名字
ch2 = 'C6'; Ic2 = 10.2; bias_offset2 = 0; 

% ========================================================
%  数据加载与对齐
% ========================================================
data = load_driver_file(filepath);
dark_data = load_driver_file(dark_filepath);

BC_light = data.table.BC;
BC_dark  = dark_data.table.BC;

% --- 处理 Device 1 ---
CR_raw1 = data.table.(ch1); DCR_raw1 = dark_data.table.(ch1);
BC_shifted1 = BC_light - bias_offset1;
idx_valid1 = (BC_shifted1 >= min(BC_dark)) & (BC_shifted1 <= max(BC_dark));
BC1 = BC_light(idx_valid1);
CR_raw1 = CR_raw1(idx_valid1);
DCR_aligned1 = interp1(BC_dark, DCR_raw1, BC1 - bias_offset1, 'linear'); 
net_CR1 = CR_raw1 - DCR_aligned1;

myfittype = fittype('a/(1+exp(-c*(x-b)))', 'coefficients', {'a','b','c'});
options1 = fitoptions('Method','NonlinearLeastSquares', 'StartPoint', [max(net_CR1), Ic1*0.6, 1], 'Lower', [0, 0, 0]); 
cfun1 = fit(BC1(BC1 < 0.9*Ic1), net_CR1(BC1 < 0.9*Ic1), myfittype, options1);
efficiency1 = net_CR1 / cfun1.a;

% --- 处理 Device 2 ---
CR_raw2 = data.table.(ch2); DCR_raw2 = dark_data.table.(ch2);
BC_shifted2 = BC_light - bias_offset2;
idx_valid2 = (BC_shifted2 >= min(BC_dark)) & (BC_shifted2 <= max(BC_dark));
BC2 = BC_light(idx_valid2);
CR_raw2 = CR_raw2(idx_valid2);
DCR_aligned2 = interp1(BC_dark, DCR_raw2, BC2 - bias_offset2, 'linear'); 
net_CR2 = CR_raw2 - DCR_aligned2;

options2 = fitoptions('Method','NonlinearLeastSquares', 'StartPoint', [max(net_CR2), Ic2*0.6, 1], 'Lower', [0, 0, 0]); 
cfun2 = fit(BC2(BC2 < 0.9*Ic2), net_CR2(BC2 < 0.9*Ic2), myfittype, options2);
efficiency2 = net_CR2 / cfun2.a;

% 计算 X 轴的最大限制值（较大 Ic 的 1.2 倍）
x_max_limit = max(Ic1, Ic2) * 1.2;

% ========================================================
%  VISUALIZATION: Dual Plot Clean Layout
% ========================================================
hFig = figure('Color', 'w', 'Position', [50, 100, 1500, 750], 'Name', 'Dual Device Characterization');

% --------------------------------------------------------
% LEFT PANEL: Normalized Detection Efficiency (带连线的散点图)
% --------------------------------------------------------
subplot(1, 2, 1);
% Device 1: 蓝色圆圈带实线
p1 = plot(BC1, efficiency1, 'bo-', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'b', 'DisplayName', dev1_name); hold on;
% Device 2: 红色圆圈带实线
p2 = plot(BC2, efficiency2, 'ro-', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'r', 'DisplayName', dev2_name);
axis square;
% Style & Labels
set(gca, 'Box', 'on', 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'LineWidth', 2, 'FontWeight', 'bold', 'FontSize', 12, 'GridAlpha', 0.15);
xlabel('Bias Current (\muA)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Internal Detection Efficiency', 'FontSize', 14, 'FontWeight', 'bold');
title('\bf\color[rgb]{0,0,0}SNSPD Quantum Efficiency Saturation', 'FontSize', 14);

% Layout Configurations
lgd1 = legend([p1, p2], 'Location', 'southoutside', 'Orientation', 'horizontal');
lgd1.FontWeight = 'bold'; lgd1.EdgeColor = [0 0 0];
ylim([0, 1.1]); xlim([0, x_max_limit]); grid on;

% --------------------------------------------------------
% RIGHT PANEL: Full DCR Profile View (带连线的散点图)
% --------------------------------------------------------
subplot(1, 2, 2);
% Device 1 DCR: 黑色圆圈带虚线 (或者实线 'ko-')
p3 = plot(BC1, DCR_aligned1, 'ko--', 'LineWidth', 1.8, 'MarkerSize', 6, 'MarkerFaceColor', 'k', 'DisplayName', [dev1_name ' DCR']); hold on;
% Device 2 DCR: 洋红色圆圈带虚线
p4 = plot(BC2, DCR_aligned2, 'mo--', 'LineWidth', 1.8, 'MarkerSize', 6, 'MarkerFaceColor', 'm', 'DisplayName', [dev2_name ' DCR']);
axis square;
% Style & Labels
set(gca, 'Box', 'on', 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'LineWidth', 2, 'FontWeight', 'bold', 'FontSize', 12, 'GridAlpha', 0.15);
xlabel('Bias Current (\muA)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Dark Count Rate (cps)', 'FontSize', 14, 'FontWeight', 'bold');
title('\bf\color[rgb]{0,0,0}Complete Dark Count Rate (DCR) Comparison', 'FontSize', 14);

% Layout Configurations
ax2 = gca; ax2.YAxis.Exponent = 0; ax2.YAxis.TickLabelFormat = '%.0f';
lgd2 = legend([p3, p4], 'Location', 'southoutside', 'Orientation', 'horizontal');
lgd2.FontWeight = 'bold'; lgd2.EdgeColor = [0 0 0];
ylim([0, max([DCR_aligned1; DCR_aligned2]) * 1.15]); xlim([0, x_max_limit]); grid on;

%% ===== Dual-SNSPD Count Rate & DCR Visualizer =====
filepath = "CR.txt";
dark_filepath = "DCR.txt";
save_filename = "Processed_Results.txt"; 

% ========================================================
%  【自定义配置区】 在这里直接修改设备名称、通道和临界电流
% ========================================================
dev1_name = 'LNOI Device A';  % 设备 1 自定义名字
ch1 = 'C2'; Ic1 = 9.8; bias_offset1 = 0.3;

dev2_name = 'ICP Device B';   % 设备 2 自定义名字
ch2 = 'C6'; Ic2 = 10.2; bias_offset2 = 0; 

% ========================================================
%  数据加载与对齐
% ========================================================
data = load_driver_file(filepath);
dark_data = load_driver_file(dark_filepath);

BC_light = data.table.BC;
BC_dark  = dark_data.table.BC;

% --- 处理 Device 1 ---
CR_raw1 = data.table.(ch1); DCR_raw1 = dark_data.table.(ch1);
BC_shifted1 = BC_light - bias_offset1;
idx_valid1 = (BC_shifted1 >= min(BC_dark)) & (BC_shifted1 <= max(BC_dark));
BC1 = BC_light(idx_valid1);
CR_raw1 = CR_raw1(idx_valid1);
DCR_aligned1 = interp1(BC_dark, DCR_raw1, BC1 - bias_offset1, 'linear'); 
net_CR1 = CR_raw1 - DCR_aligned1;

% --- 处理 Device 2 ---
CR_raw2 = data.table.(ch2); DCR_raw2 = dark_data.table.(ch2);
BC_shifted2 = BC_light - bias_offset2;
idx_valid2 = (BC_shifted2 >= min(BC_dark)) & (BC_shifted2 <= max(BC_dark));
BC2 = BC_light(idx_valid2);
CR_raw2 = CR_raw2(idx_valid2);
DCR_aligned2 = interp1(BC_dark, DCR_raw2, BC2 - bias_offset2, 'linear'); 
net_CR2 = CR_raw2 - DCR_aligned2;

% 计算 X 轴的最大限制值（较大 Ic 的 1.2 倍）
x_max_limit = max(Ic1, Ic2) * 1.2;

% ========================================================
%  VISUALIZATION: Dual Plot Clean Layout
% ========================================================
hFig = figure('Color', 'w', 'Position', [50, 100, 1500, 750], 'Name', 'Dual Device Characterization');

% --------------------------------------------------------
% LEFT PANEL: Absolute Net Count Rate (带连线的散点图，不归一化)
% --------------------------------------------------------
subplot(1, 2, 1);
% Device 1: 蓝色圆圈带实线
p1 = plot(BC1, net_CR1, 'bo-', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'b', 'DisplayName', dev1_name); hold on;
% Device 2: 红色圆圈带实线
p2 = plot(BC2, net_CR2, 'ro-', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'r', 'DisplayName', dev2_name);

% Style & Labels
set(gca, 'Box', 'on', 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'LineWidth', 2, 'FontWeight', 'bold', 'FontSize', 12, 'GridAlpha', 0.15);
xlabel('Bias Current (\muA)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Net Count Rate (cps)', 'FontSize', 14, 'FontWeight', 'bold');
title('\bf\color[rgb]{0,0,0}SNSPD Photon Count Rate (PCR) Comparison', 'FontSize', 14);

% 禁用科学计数法，方便阅读绝对计数
ax1 = gca; ax1.YAxis.Exponent = 0; ax1.YAxis.TickLabelFormat = '%.0f';
lgd1 = legend([p1, p2], 'Location', 'southoutside', 'Orientation', 'horizontal');
lgd1.FontWeight = 'bold'; lgd1.EdgeColor = [0 0 0];
ylim([0, max([net_CR1; net_CR2]) * 1.15]); xlim([0, x_max_limit]); grid on;

% --------------------------------------------------------
% RIGHT PANEL: Full DCR Profile View (带连线的散点图)
% --------------------------------------------------------
subplot(1, 2, 2);
% Device 1 DCR: 黑色圆圈带虚线
p3 = plot(BC1, DCR_aligned1, 'ko--', 'LineWidth', 1.8, 'MarkerSize', 6, 'MarkerFaceColor', 'k', 'DisplayName', [dev1_name ' DCR']); hold on;
% Device 2 DCR: 洋红色圆圈带虚线
p4 = plot(BC2, DCR_aligned2, 'mo--', 'LineWidth', 1.8, 'MarkerSize', 6, 'MarkerFaceColor', 'm', 'DisplayName', [dev2_name ' DCR']);

% Style & Labels
set(gca, 'Box', 'on', 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], 'LineWidth', 2, 'FontWeight', 'bold', 'FontSize', 12, 'GridAlpha', 0.15);
xlabel('Bias Current (\muA)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Dark Count Rate (cps)', 'FontSize', 14, 'FontWeight', 'bold');
title('\bf\color[rgb]{0,0,0}Complete Dark Count Rate (DCR) Comparison', 'FontSize', 14);

% Layout Configurations
ax2 = gca; ax2.YAxis.Exponent = 0; ax2.YAxis.TickLabelFormat = '%.0f';
lgd2 = legend([p3, p4], 'Location', 'southoutside', 'Orientation', 'horizontal');
lgd2.FontWeight = 'bold'; lgd2.EdgeColor = [0 0 0];
ylim([0, max([DCR_aligned1; DCR_aligned2]) * 1.15]); xlim([0, x_max_limit]); grid on;
