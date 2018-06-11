function [STF, LTF] = generatePreamble()

%% System Parameters
samplingFreq = 20e6;    % Sampling frequency (Hz)
FFTLength = 64;         % OFDM modulator FFT size

%% Create Short Preamble
shortPreamble = [ 0 0  1+1i 0 0 0  -1-1i 0 0 0 ... % [-27:-17]
 1+1i 0 0 0  -1-1i 0 0 0 -1-1i 0 0 0   1+1i 0 0 0 ... % [-16:-1]
 0    0 0 0  -1-1i 0 0 0 -1-1i 0 0 0   1+1i 0 0 0 ... % [0:15]
 1+1i 0 0 0   1+1i 0 0 0  1+1i 0 0 ].';               % [16:27]

% Create modulator
hPreambleMod = OFDMModulator(...
    'NumGuardBandCarriers', [6; 5],...
    'CyclicPrefixLength',   0,...
    'FFTLength' ,           64,...
    'NumSymbols',           1); 

% Modulate and scale
shortPreambleOFDM = sqrt(13/6)*step(hPreambleMod, shortPreamble);

% Form 10 Short Preambles
completeShortPreambleOFDM = [shortPreambleOFDM; shortPreambleOFDM; shortPreambleOFDM(1:32)];

%% Create Long Preamble
longPreamble = [1,  1, -1, -1,  1,  1, -1,  1, -1,  1,  1,  1,...
                   1,  1,  1, -1, -1,  1,  1, -1,  1, -1,  1,  1,  1,  1, 0,...
                   1, -1, -1,  1,  1, -1,  1, -1,  1, -1, -1, -1, -1, -1,...
                   1,  1, -1, -1,  1, -1,  1, -1,  1,  1,  1,  1].';
 
% Modulate
longPreambleOFDM = step(hPreambleMod, longPreamble);

% Form 2 Long Preambles
completeLongPreambleOFDM =[longPreambleOFDM(33:64); longPreambleOFDM; longPreambleOFDM];

STF = completeShortPreambleOFDM;
LTF = completeLongPreambleOFDM;

end