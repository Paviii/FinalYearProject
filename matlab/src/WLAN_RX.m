function rxPSDU = WLAN_RX(cfgVHT,rxWaveform)


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
% numErr = biterr(txPSDU,rxPSDU);