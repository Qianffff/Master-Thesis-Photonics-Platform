clear; clc;
instrreset;
addpath(genpath('C:\Users\Public\Documents\control grating coupler setup\sampling_with_pm100_ad3\Digilent-matlab-1.5.0.1'))

%% 1. Parameters Definition
slot = 0; 
start_wavelength = 1548;  % nm
sweep_speed = 0.5;        % nm/s
ts = 8;                   % Total time in seconds
end_wavelength = start_wavelength + ts * sweep_speed; 
target_power = 0.002;     % 1mW

%% 2. Setup DAQ (Digilent AD3)
Fs = 10e3; 
daqlist("digilent")
dq = daq("digilent");
ch_in = addinput(dq, "AD3_0", 'ai0', "Voltage");
ch_in.Name = "AD3_1_in";
dq.Rate = Fs;
dq.ScansAvailableFcnCount = Fs * ts; 
display("DAQ ready and waiting...");
%% 3. Start Laser Sweep (Calling the Function)

fprintf('--- Synchronization Timing Analysis ---\n');
% Start master timer
t_start_sequence = tic;

% Measure how long the laser initialization/start function takes
t_laser_cmd = tic;
% Note: Ensure start_laser_sweep uses 'visa' and correct SCPI commands
laser = AgilentCONT(slot, start_wavelength, end_wavelength, sweep_speed, target_power);
time_laser_overhead = toc(t_laser_cmd);
fprintf('1. Laser function overhead: %.3f seconds\n', time_laser_overhead);

%% 4. Simultaneous Acquisition
display("Starting DAQ Acquisition...");

% Measure the gap between laser command finishing and DAQ starting
t_daq_start = tic;
% read() is a blocking command; it waits for 'ts' seconds
[data, startTime] = read(dq, seconds(ts)); 
time_daq_init = toc(t_daq_start);

% Total time from "Intent to Start" to "Data Received"
total_execution_time = toc(t_start_sequence);

fprintf('2. DAQ start-to-finish time: %.3f seconds\n', time_daq_init);
fprintf('3. Estimated Sync Gap (Latency): %.3f seconds\n', (total_execution_time - ts));

%% 5. Data Processing
data_table = timetable2table(data);
time_seconds = seconds(data_table.Time);

% Map Time to Wavelength: Lambda(t) = Lambda_start + Speed * t
wavelengths = start_wavelength + sweep_speed * time_seconds;

output_table = table(wavelengths, data_table.AD3_1_in, ...
    'VariableNames', {'Wavelength_nm', 'Intensity'});

%% 6. Plotting and Saving
plot(output_table.Wavelength_nm, output_table.Intensity);
xlabel('Wavelength (nm)'); ylabel('Intensity (V)');
title(['Sweep: ' datestr(startTime)]);

% Save Data
directory = 'C:\Users\Public\Documents\control grating coupler setup\sampling_with_pm100_ad3\Data';
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
fileName = ['sp10_320_top_' timestamp '.csv'];
writetable(output_table, fullfile(directory, fileName));

%% 7. Clean Up Laser
% Turn off laser and close connection - Ref: Page 151
fprintf(laser, ['SOUR', num2str(slot), ':POW:STAT OFF']);
fclose(laser); delete(laser); clear laser;
disp('System closed safely.');