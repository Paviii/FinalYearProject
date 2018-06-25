function [eqSym, noiseVar, frameNumber] = RxWrapper(paylaodLength,numOfPackets,dataLength,Radio)


%config
SymbolLength = 80;

% Radio = comm.SDRuReceiver(...
%             'Platform' , 'N200/N210/USRP2', ...
%             'IPAddress','192.168.0.4', ...
%             'CenterFrequency',      2.3e9, ...
%             'Gain',                 30, ...
%             'DecimationFactor',     4, ...
%             'SamplesPerFrame',      SymbolLength, ...
%             'EnableBurstMode',      true,...
%             'NumFramesInBurst',     1,...
%             'TransportDataType',    'int8', ...
%             'LocalOscillatorOffset', 0,...
%             'OutputDataType',       'double');
% Instantiate and configure all objects and structures for packet
% synchronization and decoding
EnableScopes = 0;

% Set up decoder parameters
cfgRec = wlanRecoveryConfig('EqualizationMethod', 'MMSE');
% Set up Front-End Packet Synchronizer
WLANFrontEnd = customOFDMSync('ChannelBandwidth', 'CBW20','numOfDataSymbols',paylaodLength);
%WLANFrontEnd.numOfDataSymbols = dataLength;
% rateConverter = dsp.FIRRateConverter('InterpolationFactor', 4,...
%     'DecimationFactor', 5);

% Set up Scopes
if EnableScopes
    positions =  ...
        [20   655   676   177; ...
        736   655   676   177; ...
        20   358   676   177; ...
        736   358   676   177; ...
        20    61   676   177; ...
        736    61   676   177];
    SampleRate = 20e6;
    [PostEq,InputSpectrum,ArrayEqTaps] = ...
        SetupScopes(positions,SampleRate);
end

%% Collect symbols and search for packets
% Collect data from the radio one symbol at a time, constructing the packet
% out of these symbols.  Once a valid packet is captured, try to decode it.
%for frame = 1:FramesToCollect
eqSym = complex(zeros(48,numOfPackets*paylaodLength),0);
noiseVar = 0;
valid = false;
packetSeq = 1:numOfPackets;
detPack = [];

while ~all(ismember(packetSeq, detPack))
    
    % Get data from radio
    data = GetUSRPFrame(Radio,SymbolLength);
    
    if EnableScopes
        step(InputSpectrum,complex(data));
    end
    
    % WLANFrontEnd will internally buffer input symbols in-order to build
    % full packets.  The flag valid will be true when a complete packet is
    % captured.
    
    %for i = 1 : length(data)/80
        
        [valid, cfgSig, payload, chanEst, noiseVar, seqFramNum] = WLANFrontEnd(data);
        
        
        % Decode when we have captured a full packet
        if valid
            
            % Decode payload to bits
            disp(seqFramNum)
            frameNumber = ceil(seqFramNum/10);
            seqNum = rem(seqFramNum,10);
            if seqNum == 0
                continue;
            end
            %use custom decoding
            eqSym(:,(seqNum-1)*paylaodLength+1:seqNum*paylaodLength) = ofdmDataRecover(...
                payload,...
                chanEst,...
                noiseVar,...
                cfgSig,...
                cfgRec);
            
            % View post equalized symbols and equalizer taps
            if EnableScopes
                step(ArrayEqTaps,chanEst);
                % Animate
                %             for symbol = 1:size(eqSym,2)
                %                 step(PostEq,eqSym(:,symbol));
                %             end
                
            end
            
            detPack = [detPack; seqNum];
%             if ~all(ismember(packetSeq, detPack))
%                 break;
%             end
            
        end
        
end

fileID = fopen('src/Metadata/ack.bin','w'); 
fwrite(fileID,1,'uint');

eqSym = reshape(eqSym(:,1:dataLength).',numel(eqSym(:,1:dataLength)), []);
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
