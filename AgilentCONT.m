function laserObj = AgilentCONT(slot, startWav, stopWav, sweepSpeed, targetPower)
    % Initialize VISA connection
    % Ref: Legacy VISA for maximum compatibility
    laserObj = visa('AGILENT', 'GPIB1::20::INSTR'); 
    
    try
        fopen(laserObj);
    catch ME
        error('Could not open connection. Check GPIB cable and Address.');
    end

    % Identify device
    fprintf(laserObj, '*IDN?');
    deviceInfo = fscanf(laserObj);
    disp(['Connected to: ', deviceInfo]);
    
    fprintf(laserObj, ['SOUR', num2str(slot), ':WAV:SWE:STAT STOP']);
    % 1. Configure Power and Units - Ref: Page 151 & 148
    fprintf(laserObj, ['SOUR', num2str(slot), ':POW:UNIT W']);
    fprintf(laserObj, ['SOUR', num2str(slot), ':POW ', num2str(targetPower)]);

    % 2. Configure Sweep Parameters - Ref: Page 171, 175, 176, 174
    fprintf(laserObj, ['SOUR', num2str(slot), ':WAV:SWE:MODE CONT']);

    % fprintf(laserObj, 'SOUR%d:WAV:SWE:STAR 1530NM', slot);
    fprintf(laserObj, sprintf(':SOUR%d:WAV:SWE:STAR %.4fNM', slot, startWav));
    fprintf(laserObj, sprintf(':SOUR%d:WAV:SWE:STOP %.4fNM', slot, stopWav));
    %fprintf(laserObj, 'SOUR0:wav:swe:spe 10nm/s');
    fprintf(laserObj, sprintf('SOUR%d:WAV:SWE:SPE %.4fNM/S', slot, sweepSpeed));   

    % Return the set parameters
    fprintf('Current Power: %s W\n', query(laserObj, [':SOUR', num2str(slot), ':POW?']));
    fprintf('Sweep Start: %.2f nm\n', str2double(query(laserObj, sprintf(':SOUR%d:WAV:SWE:STAR?', slot))) * 1e9);
    fprintf('Sweep Stop: %.2f nm\n', str2double(query(laserObj, sprintf(':SOUR%d:WAV:SWE:STOP?', slot))) * 1e9);
    fprintf('Sweep Speed: %.2f nm/s\n', str2double(query(laserObj, sprintf(':SOUR%d:WAV:SWE:SPE?', slot))) * 1e9);

    % 3. Parameter Consistency Check - Ref: Page 165
    fprintf(laserObj, ['SOUR', num2str(slot), ':WAV:SWE:CHEC?']);

    % 4. Enable Output and Stabilize - Ref: Page 151
    fprintf(laserObj, ['SOUR', num2str(slot), ':POW:STAT 1']); % on
    disp('Laser output enabled. Stabilizing for 2s...');
    pause(2); 

    % 5. Start the Sweep - Ref: Page 176
    fprintf(laserObj, ['SOUR', num2str(slot), ':WAV:SWE STARt']);
    disp('Laser sweep initiated.');
end


% laserObj = visa('AGILENT', 'GPIB1::20::INSTR'); 
% fopen(laserObj);