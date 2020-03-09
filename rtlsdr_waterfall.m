function rtlsdr_waterfall( Fc_Hz, Fs_sps, RFGain_dB, Tspan_sec, Nfbins )
% Creates a spectrum/waterfall plot using received signal samples from an
% RTL-SDR.
%
% Any argument can be omitted using [] to use default values.  Can call
% rtlsdr_waterfall() with no arguments for default values.
%
% Fc_Hz = RTL-SDR Receiver center frequency (Hz) 
%   Rafael Micro R820T 24 - 1766 MHz
% Fs_sps = Sample rate (samples/sec)
%   225,001 - 300,001 and 900,001 - 3,200,000 samples/sec
% RFGain_dB = Tuner gain of RTL-SDR (dB).  Valid values:
%   0.0 0.9 1.4 2.7 3.7 7.7 8.7 12.5 14.4 15.7 16.6 19.7 20.7 22.9 25.4
%   28.0 29.7 32.8 33.8 36.4 37.2 38.6 40.2 42.1 43.4 43.9 44.5 48.0 49.6
% Tspan_sec = Time span of time axis (sec)
% Nfbins = Number of frequency bins of frequency axis
% 
% Keypress when figure window active
%   q = Quit
%   z = Reset autozoom of spectrum
%
% Requires the MATLAB Communications Toolbox, DSP System Toolbox, 
% Signal Processing Toolbox, and the RTL-SDR support package.
% https://www.mathworks.com/hardware-support/rtl-sdr.html
% https://www.mathworks.com/help/supportpkg/rtlsdrradio/installation-and-setup.html?s_tid=CRUX_lftnav
%
% To check if RTL-SDR is installed and active:
%   rx = comm.SDRRTLReceiver
%   hwinfo = sdrinfo('0')

% W. Newhall KB2BRD

global keypressed;      % Key detected
keypressed = [];        % Null to clear keypress triggering

% Default arguments
if nargin < 5 || isempty(Nfbins)
    Nfbins = 256;
end
if nargin < 4 || isempty(Tspan_sec)
    Tspan_sec = 20e-3;
end
if nargin < 3  || isempty(RFGain_dB)
    RFGain_dB = 32.8;
end
if nargin < 2 || isempty(Fs_sps)
    Fs_sps = 2.8e6;
end
if nargin < 1 || isempty(Fc_Hz)
    Fc_Hz = 96.9e6;
end 

Ts_s = 1/Fs_sps;                        % Sample period (s)
Ts_slow_sec = Ts_s * Nfbins;            % Slow-time sample period (s)
Ntbins = ceil(Tspan_sec/Ts_slow_sec);   % Number of time bins

Ns = Nfbins * Ntbins;   % Total number of samples needed for waterfall
Ns_frame = 8192;        % Number of samples per frame requested from SDR
Nframes = ceil(Ns/Ns_frame);    % Number of frames to capture continously

sdrrx = comm.SDRRTLReceiver('0', ...    % Instantiate the RTL-SDR object
    'CenterFrequency',Fc_Hz, ...
    'SampleRate',Fs_sps, ...
    'SamplesPerFrame',Ns_frame, ...
    'EnableTunerAGC',false, ...
    'TunerGain', RFGain_dB, ...
    'OutputDataType','double');

lost = zeros(1,Nframes);    % Allocate the lost array
late = zeros(1,Nframes);    % Allocate the late array

t_slow_ms = (0:Ntbins-1) * Ts_slow_sec * 1000;  % Slow time axis (ms)
f_MHz = ( (0:Nfbins-1)/Nfbins * Fs_sps - ...    % Frequency axis (MHz)
    Fs_sps/2 + Fc_Hz) / 1e6;

% hfig = figure( 1 );                   
hfig = gcf;                             % Use current figure
set(hfig, 'MenuBar', 'None');           % No menu bar on figure
set(hfig,'KeyPressFcn',@keypressfcn);   % Keypress callback function
    
first_loop = 1;         % Flag to do things on the first loop

while 1     % Loop forever until stopped (type q) by user
    s = zeros(1, Ns_frame*Nframes);     % Allocate s array
    for n = 1 : Nframes     % Acquire samples in frames
        [s( (n-1)*Ns_frame+1 : n*Ns_frame ), len, lost(n), late(n)] = ...
            sdrrx();
    end

    s = s(1:Ns);    % Truncate number of samples for waterfall plot calcs
    
    s = reshape(s, Nfbins, Ntbins); % Put signal in columns
    S = fftshift( fft(s), 1 );      % Calculate the spectrum
    S_dB = 20*log10( abs(S) );      % Convert to dB

    
    if( strcmp(keypressed, "p") )   % Pause if p pressed
        keypressed = [];                % Clear the keypress
        while(~strcmp(keypressed,"p"))  % Wait until p pressed again
            pause(0.1);                 % Pause to capture new keypresses
        end
        keypressed = [];                % Clear the "p" keypress
    end

    % Create spectrum plot
    sfh1 = subplot(2,1,1);  % Get handle to subplot
    S_avg_dB = 20*log10( sum(abs(S),2)/Ntbins);
    plot(f_MHz, S_avg_dB)
    title('Frequency Spectrum and Waterfall')
    xlabel('Frequency (MHz)')
    ylabel('Rel Pwr (dB)')
    grid on
    xlim([min(f_MHz),max(f_MHz)])
    S_avg_dB_max = max(S_avg_dB);
    plotylim = ylim;
    if( first_loop == 1 || ...  % Handle auto zoom
            S_avg_dB_max > plotylimset(2) ||... % Zoom out if signal high
            strcmp(keypressed, "z") )           % Handle "z" keypress
        plotylimset = [S_avg_dB_max-40, S_avg_dB_max+5];  % New y limits
        keypressed = [];                        % clear out keypress
    end
    ylim(plotylimset)   % Set y limits of plot
    
    % Create waterfall plot
    sfh2 = subplot(2,1,2);
    surf( t_slow_ms, f_MHz, S_dB, 'EdgeColor', 'none' )
    view([90,90])
    xlabel('Time (ms)')
    ylabel('Frequency (MHz)')
    xlim([min(t_slow_ms),max(t_slow_ms)])
    ylim([min(f_MHz),max(f_MHz)])
    
    % Scale useful area of both plots
    sfh1.Position = sfh1.Position + [-0.05 0.22 0.1 -0.20];
    sfh2.Position = sfh2.Position + [-0.05 0.0 0.1 0.27];
    
    drawnow             % Force to show on the figure
    first_loop = 0;     % Clear the first-loop flag
    
    if( strcmp(keypressed, "q") )   % Quit if q pressed
        break
    end
end

release(sdrrx);     % Release the RTL-SDR hardware upon quit
end

% Handler for keypresses
function keypressfcn(src, event)
    global keypressed;
    keypressed = event.Key;
end
