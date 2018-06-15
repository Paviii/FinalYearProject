function eqDataSym = ofdmDataRecover( ...
    rxNonHTData, chanEst, noiseVarEst, cfgNonHT, varargin)

narginchk(4,5);
nargoutchk(0,3);

% Calculate CPE if requested
if nargout>2
    calculateCPE = true;
else
    calculateCPE = false;
end

% Optional recovery configuration input validation
if nargin == 5
    validateattributes(varargin{1}, {'wlanRecoveryConfig'}, {'scalar'}, mfilename, 'recovery configuration object');

    symOffset = varargin{1}.OFDMSymbolOffset;
    eqMethod  = varargin{1}.EqualizationMethod; 
    pilotPhaseTracking = varargin{1}.PilotPhaseTracking;
else % use defaults
    symOffset = 0.75;
    eqMethod  = 'MMSE'; 
    pilotPhaseTracking = 'PreEQ';
end



 numOFDMSym = cfgNonHT.PSDULength;


% Get OFDM configuration
[cfgOFDM,dataInd,pilotInd] = wlan.internal.wlanGetOFDMConfig(cfgNonHT.ChannelBandwidth, 'Long', 'Legacy');


% Extract data and pilot subcarriers from channel estimate
chanEstData = chanEst(dataInd,:,:);
chanEstPilots = chanEst(pilotInd,:,:);

% Cross-validation between inputs
minInputLen = numOFDMSym*(cfgOFDM.FFTLength+cfgOFDM.CyclicPrefixLength);

% Processing 
% OFDM Demodulation 
cfgOFDM.NormalizationFactor = 1;
[ofdmDemodData, ofdmDemodPilots] = wlan.internal.wlanOFDMDemodulate(rxNonHTData(1:minInputLen, :), cfgOFDM, symOffset);

% Pilot phase tracking
if calculateCPE==true || strcmp(pilotPhaseTracking, 'PreEQ')
    % Get reference pilots, from IEEE Std 802.11-2012, Eqn 18-22
    z =0; % Offset by 1 to account for L-SIG pilot symbol
    refPilots = wlan.internal.nonHTPilots(numOFDMSym, z);
    
    % Estimate CPE and phase correct symbols
    cpe = wlan.internal.commonPhaseErrorEstimate(ofdmDemodPilots, chanEstPilots, refPilots);
    if strcmp(pilotPhaseTracking, 'PreEQ')
        ofdmDemodData = wlan.internal.commonPhaseErrorCorrect(ofdmDemodData, cpe);
    end
    if calculateCPE==true
        varargout{1} = cpe.'; % Permute to Nsym-by-1
    end
end

% Equalization method
[eqDataSym, csiData] = wlan.internal.wlanEqualize(ofdmDemodData, chanEstData, eqMethod, noiseVarEst);

eqDataSym = reshape(eqDataSym.',numel(eqDataSym), []);



end