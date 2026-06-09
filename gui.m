function gui
    % Add driver paths
    addpath(genpath('C:\Users\Public\Documents\control grating coupler setup\sampling_with_pm100_ad3\Digilent-matlab-1.5.0.1'));
    
    saveDir = 'C:\Users\Public\Documents\control grating coupler setup\Data';
    
    %% ===== FIGURE SETUP =====
    fig = figure('Name', 'Time Tagger Scan Control', ...
                 'Position', [100, 100, 1200, 750], ...
                 'NumberTitle', 'off', ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none', ...
                 'Color', [1 1 1]); 
             
    %% ===== PANELS =====
    leftPanel = uipanel('Parent', fig, ...
                        'Position', [0.02, 0.02, 0.26, 0.96], ...
                        'Title', 'Scan Parameters', ...
                        'FontSize', 14, ...                         
                        'ForegroundColor', [0 0 0], ...
                        'BackgroundColor', [1 1 1]);
                    
    rightPanel = uipanel('Parent', fig, ...
                         'Position', [0.30, 0.02, 0.68, 0.96], ...
                         'Title', 'Scan Results', ...
                         'FontSize', 14, ...                          
                         'ForegroundColor', [0 0 0], ...
                         'BackgroundColor', [1 1 1]);
                     
    %% ===== AXIS SETUP =====
    ax = axes('Parent', rightPanel, ...
              'Position', [0.12, 0.12, 0.82, 0.82], ...
              'FontSize', 12, ...               
              'XColor', [0 0 0], ...
              'YColor', [0 0 0], ...
              'Box', 'on');
    xlabel(ax, 'Wavelength (nm)', 'FontSize', 14, 'FontWeight', 'bold');
    ylabel(ax, 'Count rate (cps)', 'FontSize', 14, 'FontWeight', 'bold');
    grid(ax, 'on');

    %% ===== UI ELEMENTS =====
    y = 0.90; dy = 0.050; % 稍微缩小间距以容纳新项
    create_label(leftPanel, y, '--- Laser Settings ---', true);
    startWavelengthEdit = create_input(leftPanel, y-1*dy, 'Start WL (nm):', '1545', @updateCalculations);
    endWavelengthEdit   = create_input(leftPanel, y-2*dy, 'End WL (nm):', '1565', @updateCalculations);
    scanRateEdit        = create_input(leftPanel, y-3*dy, 'Scan Rate (nm/s):', '5', @updateCalculations);
    powerEdit           = create_input(leftPanel, y-4*dy, 'Power (W):', '0.005', @updateCalculations);
    attenuationEdit     = create_input(leftPanel, y-5*dy, 'Attenuation (dB):', '0', []);
    
    create_label(leftPanel, y-6.5*dy, '--- Time Tagger ---', true);
    ttChannelEdit    = create_input(leftPanel, y-7.5*dy, 'TT Channel:', '1', []);
    triggerLevelEdit = create_input(leftPanel, y-8.5*dy, 'Trigger (V):', '-0.05', []);
    binWidthEdit     = create_input(leftPanel, y-9.5*dy, 'Bin Width (ms):', '1', @updateCalculations);
    deadTimeEdit     = create_input(leftPanel, y-10.5*dy, 'Dead Time (ns):', '2', []); 
    
    % 新增 Variable Name 输入框
    varNameEdit      = create_input(leftPanel, y-12*dy, 'Var Name:', 'Sample', []); 
    
    paramLabel = uicontrol(leftPanel, 'Style', 'text', ...
        'Units','normalized','Position',[0.1,0.22,0.8,0.06], ...
        'FontSize',11,'ForegroundColor',[0 0 0], 'BackgroundColor', [1 1 1]);
    
    startBtn = uicontrol(leftPanel, 'Style','pushbutton', ...
        'Units','normalized','Position',[0.15,0.14,0.7,0.07], ...
        'String','START','FontSize',16,'FontWeight','bold', ...
        'BackgroundColor',[0.2 0.6 1], 'ForegroundColor',[1 1 1], ...
        'Callback',@startScan);
    
    messageLabel = uicontrol(leftPanel, 'Style','text', ...
        'Units','normalized','Position',[0.1,0.02,0.8,0.10], ...
        'FontSize',11,'FontWeight','bold','ForegroundColor',[0 0 0], 'BackgroundColor', [1 1 1]);

    %% ===== STORE HANDLES =====
    handles = struct('startWavelengthEdit',startWavelengthEdit, ...
                     'endWavelengthEdit',endWavelengthEdit, ...
                     'scanRateEdit',scanRateEdit, ...
                     'powerEdit',powerEdit, ...
                     'attenuationEdit',attenuationEdit, ...
                     'ttChannelEdit',ttChannelEdit, ...
                     'triggerLevelEdit',triggerLevelEdit, ...
                     'binWidthEdit',binWidthEdit, ...
                     'deadTimeEdit',deadTimeEdit, ...
                     'varNameEdit', varNameEdit, ... % 存储新句柄
                     'ax',ax, ...
                     'messageLabel',messageLabel, ...
                     'paramLabel',paramLabel, ...
                     'startBtn',startBtn, ...
                     'saveDir',saveDir);
    guidata(fig, handles);
    updateCalculations();

    %% ===== CALLBACKS =====
    function updateCalculations(~,~)
        d = guidata(fig);
        s = str2double(get(d.startWavelengthEdit,'String'));
        e = str2double(get(d.endWavelengthEdit,'String'));
        r = str2double(get(d.scanRateEdit,'String'));
        b = str2double(get(d.binWidthEdit,'String'));
        if ~any(isnan([s,e,r,b])) && e>s
            duration = (e-s)/r;
            res = r*(b/1000); 
            set(d.paramLabel,'String',sprintf('Duration: %.2f s\nResolution: %.2f pm',duration,res*1000));
        else
            set(d.paramLabel,'String','Duration: --\nResolution: --');
        end
    end

    function startScan(~,~)
        d = guidata(fig);
        s_wl = str2double(get(d.startWavelengthEdit,'String'));
        e_wl = str2double(get(d.endWavelengthEdit,'String'));
        rate = str2double(get(d.scanRateEdit,'String'));
        pwr  = str2double(get(d.powerEdit,'String'));
        att  = str2double(get(d.attenuationEdit,'String'));
        bin  = str2double(get(d.binWidthEdit,'String'));
        ch   = str2double(get(d.ttChannelEdit,'String'));
        trig = str2double(get(d.triggerLevelEdit,'String'));
        dt   = str2double(get(d.deadTimeEdit,'String')); 
        v_name = get(d.varNameEdit, 'String'); % 获取 Variable Name
        
        if any(isnan([s_wl,e_wl,rate,pwr,att,bin,ch,trig,dt])) || e_wl<=s_wl
            set(d.messageLabel,'String','Invalid parameters','ForegroundColor','r');
            return;
        end
        
        set(d.startBtn,'Enable','off','String','SCANNING','BackgroundColor',[0.5 0.5 0.5]);
        set(d.messageLabel,'String','Scanning...','ForegroundColor',[0 0 0]);
        drawnow;
        
        try
            % 传递 v_name 到 performScan
            [~, data_scan] = performScan(s_wl, e_wl, rate, d.saveDir, ch, trig, bin, pwr, dt, att, v_name);
            
            wl = data_scan.wavelength_axis;
            cps = data_scan.counts / (bin/1000); 
            
            cla(d.ax);
            plot(d.ax, wl, cps, 'k-', 'LineWidth', 1.5);
            xlim(d.ax, [s_wl e_wl]); 
            if ~isempty(cps)
                ylim(d.ax, [0 max(cps)*1.1 + 1]); 
            end
            
            set(d.messageLabel,'String','Scan Complete','ForegroundColor',[0 0.5 0]);
        catch ME
            set(d.messageLabel,'String',['Error: ' ME.message],'ForegroundColor','r');
        end
        set(d.startBtn,'Enable','on','String','START','BackgroundColor',[0.2 0.6 1]);
    end

    %% ===== HELPERS =====
    function create_label(parent,y,txt,bold)
        fw='normal'; if bold, fw='bold'; end
        uicontrol(parent,'Style','text','Units','normalized',...
            'Position',[0.05 y 0.9 0.04],'String',txt,...
            'FontWeight',fw,'FontSize',12,...
            'ForegroundColor',[0 0 0], 'BackgroundColor',[1 1 1]);
    end
    
    function edit = create_input(parent,y,label,val,cb)
        uicontrol(parent,'Style','text','Units','normalized',...
            'Position',[0.05 y 0.5 0.03],'String',label,...
            'HorizontalAlignment','right', 'FontWeight','bold',...
            'ForegroundColor',[0 0 0], 'BackgroundColor',[1 1 1]);
        edit = uicontrol(parent,'Style','edit','Units','normalized',...
            'Position',[0.6 y 0.3 0.04],'String',val,...
            'BackgroundColor',[1 1 1], 'ForegroundColor',[0 0 0],...
            'FontWeight','bold', 'Callback',cb);
    end
end