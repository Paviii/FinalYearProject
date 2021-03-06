function [numErr, rxPSDU] = WLANTxRx(mcs,txPSDU,snr)

% Create a format configuration object for a SISO VHT transmission
cfgVHT = wlanVHTConfig;
cfgVHT.NumTransmitAntennas = 1;    % Transmit antennas
cfgVHT.NumSpaceTimeStreams = 1;    % Space-time streams
cfgVHT.APEPLength = 4096;          % APEP length in bytes
cfgVHT.MCS = mcs;                    % Single spatial stream, 64-QAM
cfgVHT.ChannelBandwidth = 'CBW20'; % Transmitted signal bandwidth
Rs = wlanSampleRate(cfgVHT);       % Sampling rate

%generate waveform
%legacy part
lstf = wlanLSTF(cfgVHT);
lltf = wlanLLTF(cfgVHT);
lsig = wlanLSIG(cfgVHT);
nonHTfield = [lstf;lltf;lsig]; % Combine the non-HT preamble fields
%vht part
vhtsiga = wlanVHTSIGA(cfgVHT);
vhtstf = wlanVHTSTF(cfgVHT);
vhtltf = wlanVHTLTF(cfgVHT);
vhtsigb = wlanVHTSIGB(cfgVHT);
preamble = [lstf;lltf;lsig;vhtsiga;vhtstf;vhtltf;vhtsigb];

%transmitter
rng(0) % Initialize the random number generator
%txPSDU = randi([0 1],cfgVHT.PSDULength*8,1); % Generate PSDU data in bits
data = wlanVHTData(txPSDU,cfgVHT);

% A VHT waveform is constructed by prepending the non-HT and VHT
% preamble fields with data
txWaveform = [preamble;data]; % Transmit VHT PPDU



% Parameterize the channel
tgacChannel = wlanTGacChannel;
tgacChannel.DelayProfile = 'Model-D';
tgacChannel.NumTransmitAntennas = cfgVHT.NumTransmitAntennas;
tgacChannel.NumReceiveAntennas = 1;
tgacChannel.LargeScaleFadingEffect = 'None';
tgacChannel.ChannelBandwidth = 'CBW20';
tgacChannel.TransmitReceiveDistance = 5;
tgacChannel.SampleRate = Rs;
tgacChannel.RandomStream = 'mt19937ar with seed';
tgacChannel.Seed = 10;

% Pass signal through the channel. Append zeroes to compensate for channel
% filter delay
txWaveform = [txWaveform;zeros(10,1)];
chanOut = tgacChannel(txWaveform);

%snr = 19; % In dBs
%rxWaveform = awgn(chanOut,snr,0);
noisVar = 10^(-snr/10);
rxWaveform = txWaveform + sqrt(noisVar/2)*(randn(size(chanOut)) + 1i*randn(size(chanOut)));

% Display the spectrum of the transmitted and received signals. The
% received signal spectrum is affected by the channel
% spectrumAnalyzer  = dsp.SpectrumAnalyzer('SampleRate',Rs, ...
%             'ShowLegend',true, ...
%             'Window', 'Rectangular', ...
%             'SpectralAverages',10, ...
%             'YLimits',[-30 10], ...
%             'ChannelNames',{'Transmitted waveform','Received waveform'});
% spectrumAnalyzer([txWaveform rxWaveform]);




indField = wlanFieldIndices(cfgVHT);
indLLTF = indField.LLTF(1):indField.LLTF(2);
demodLLTF = wlanLLTFDemodulate(rxWaveform(indLLTF),cfgVHT);
% Estimate noise power in VHT fields
nVar = helperNoiseEstimate(demodLLTF,cfgVHT.ChannelBandwidth, ...
    cfgVHT.NumSpaceTimeStreams);

indVHTLTF = indField.VHTLTF(1):indField.VHTLTF(2);
demodVHTLTF = wlanVHTLTFDemodulate(rxWaveform(indVHTLTF,:),cfgVHT);
chanEstVHTLTF = wlanVHTLTFChannelEstimate(demodVHTLTF,cfgVHT);
indData = indField.VHTData(1):indField.VHTData(2);
% Recover the bits and equalized symbols in the VHT Data field using the
% channel estimates from VHT-LTF

[rxPSDU,~,eqSym] = wlanVHTDataRecover(rxWaveform(indData,:), ...
    chanEstVHTLTF,nVar,cfgVHT);

% Compare transmit and receive PSDU bits
numErr = biterr(txPSDU,rxPSDU);