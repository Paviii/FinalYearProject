function   runUSRPRx()

%config

% Set up system
% Instantiate and configure all objects and structures for packet
% synchronization and decoding
EnableScopes = 1;
% System info
SampleRate = 20e6; % Hz
SymbolLength = 80; % Samples in 20MHz OFDM Symbol (FFT+CP)
FramesToCollect = 100000;
    %floor(SampleRate*Config.SimInfo.CaptureDuration/SymbolLength);
DecimationFactor = 1;


 shortPreambleOFDM = [ 0 0  1+1i 0 0 0  -1-1i 0 0 0 ... % [-27:-17]
 1+1i 0 0 0  -1-1i 0 0 0 -1-1i 0 0 0   1+1i 0 0 0 ... % [-16:-1]
 0    0 0 0  -1-1i 0 0 0 -1-1i 0 0 0   1+1i 0 0 0 ... % [0:15]
 1+1i 0 0 0   1+1i 0 0 0  1+1i 0 0 ].';               % [16:27]

% Set up USRP
Radio = comm.SDRuReceiver(...
            'Platform',             'B200', ...
            'SerialNum',            '30A3E93', ...
            'MasterClockRate',      20e6, ...
            'CenterFrequency',      2.3e9, ...
            'Gain',                 40, ...
            'DecimationFactor',     DecimationFactor, ...
            'SamplesPerFrame',      SymbolLength, ...
            'EnableBurstMode',      true,...
            'NumFramesInBurst',     1,...
            'TransportDataType',    'int8', ...
            'OutputDataType',       'double');

% Set up Front-End Packet Synchronizer
WLANFrontEnd = customOFDMSync('ChannelBandwidth', 'CBW20');  

% Gain control
hAGC = comm.AGC('AveragingLength', SymbolLength);

% Set up decoder parameters
cfgRec = wlanRecoveryConfig('EqualizationMethod', 'ZF');

% Set up Scopes
if EnableScopes
    positions =  ...
        [20   655   676   177; ...
        736   655   676   177; ...
        20   358   676   177; ...
        736   358   676   177; ...
        20    61   676   177; ...
        736    61   676   177];
    [PostEq,InputSpectrum,ArrayEqTaps] = ...
        SetupScopes(positions,SampleRate);
end

%% Collect symbols and search for packets
% Collect data from the radio one symbol at a time, constructing the packet
% out of these symbols.  Once a valid packet is captured, try to decode it.
framCnt = 0; 
for frame = 1:FramesToCollect
    
    % Get data from radio
    
    data = GetUSRPFrame(Radio,SymbolLength);
    %data = step(hAGC,data);
    %pktOffset = locateOFDMFrame_sdr( 64, shortPreambleOFDM, data);   
    
    if EnableScopes
        step(InputSpectrum,complex(data));
    end
        
    % WLANFrontEnd will internally buffer input symbols in-order to build
    % full packets.  The flag valid will be true when a complete packet is
    % captured.
    [valid, cfgSig, payload, chanEst, noiseVar] = WLANFrontEnd(data,numOfSym);
    
    % Decode when we have captured a full packet
    if valid     
        
        % Decode payload to bits
        %use custom decoding
        [bits,eqSym] = ofdmDataRecover(...
            payload,...
            chanEst,...
            noiseVar,...
            cfgSig,...
            cfgRec);
        
        % View post equalized symbols and equalizer taps
        if EnableScopes
            step(ArrayEqTaps,chanEst);
            % Animate
            for symbol = 1:size(eqSym,2)
                step(PostEq,eqSym(:,symbol));
            end
        end
        
        % Extract single frame from input buffer
        %rFrame = buffer(estimate.delay + 1 : estimate.delay + tx.frameLength);
               
        % Correct frequency offset
        %[ rFreqShifted, estimate ] = coarseOFDMFreqEst_sdr( rFrame, tx, estimate);                 
        % Equalize
        %[ RPostEqualizer, RPreEqualizer, estimate] = equalizeOFDM( rFreqShifted, tx, estimate, hPreambleDemod, hDataDemod );
        
        % Demod subcarriers
        %[ frameBER, estimate, RHard ] = demodOFDMSubcarriers_sdr( RPostEqualizer, tx, estimate );
        
        %print message        
        message = char(OFDMbits2letters(msg > 0).');
        disp(message)
        
        
        
    end
end

% Cleanup objects
release(Radio); release(WLANFrontEnd);

end


%% Blocking USRP Function
function data = GetUSRPFrame(Radio,SymbolLength)
    % Keep accessing the SDRu System object output until it is valid
    len = uint32(0);
    data = coder.nullcopy(complex(zeros(SymbolLength,1)));
    while len <= 0
        [data,len] = step(Radio);
        if all(data == 0)
            len = uint32(0);
        end
    end
end

function [PostEq,InputSpectrum,ArrayEqTaps] = SetupScopes(FigurePositions,SamplesRate)

coder.extrinsic('comm.ConstellationDiagram',...
    'dsp.SpectrumAnalyzer',...
    'dsp.ArrayPlot');

PostEq = comm.ConstellationDiagram('Name','Post Equalized Symbols',...
    'ReferenceConstellation',[-1,1],...
    'Position',FigurePositions(1,:));
InputSpectrum = dsp.SpectrumAnalyzer('Title','Input PSD',...
    'SampleRate',SamplesRate,...
    'YLimits', [-90 10],...
    'Position',FigurePositions(2,:));
ArrayEqTaps = dsp.ArrayPlot('Title','Equalizer Taps',...
    'XLabel', 'Filter Tap', ...
    'YLabel', 'Filter Weight',...
    'ShowLegend', true,...
    'Position',FigurePositions(3,:));

end
