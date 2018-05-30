%configure parameters
useCodegen = 1;
compileIt = 0;

bw = 20e6; %20MHz
numFrames = 1;
payloadMessage = 'Andreeeeeeei!!!! is the greatest businessman on the planet';
numOfPackets = 10000;
InterpolationFactor = 4;
%generate waveform
[txWaveform, txConfig ] = generateOFDM80211a(numFrames,payloadMessage);

%interpolate
rateConverter = dsp.FIRRateConverter('InterpolationFactor', 5,... 
                                         'DecimationFactor', 4); 
txConv = step(rateConverter,txWaveform);
txConfig.samplingFreq = bw;% Set desired frequeny
txConfig.FreqBin = txConfig.samplingFreq/txConfig.FFTLength;% Set frequency bin width
txConfig.frameLength = txConfig.frameLength*25/20; %resample for N210 transmission. 

% Setup transmitter
if compileIt
    disp('Generating code for transmitter');
    codegen USRPTransmit -args { InterpolationFactor, txConv, numOfPackets }
end

%transmit 
% Run transmitter
if useCodegen
    USRPTransmit_mex(InterpolationFactor, txConv,numOfPackets)
else    
    USRPTransmit(InterpolationFactor, txConv,numOfPackets);
end


