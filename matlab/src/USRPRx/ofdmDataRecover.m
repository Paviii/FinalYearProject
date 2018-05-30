function [bits, eqDataSym,varargout] = ofdmDataRecover( ...
    rxNonHTData, chanEst, noiseVarEst, cfgNonHT, varargin)

narginchk(4,5);
nargoutchk(0,3);

% Calculate CPE if requested
if nargout>2
    calculateCPE = true;
else
    calculateCPE = false;
end

% Non-HT configuration input self-validation
validateattributes(cfgNonHT, {'wlanNonHTConfig'}, {'scalar'}, mfilename, 'format configuration object');
% Only applicable for OFDM and DUP-OFDM modulations
s = validateConfig(cfgNonHT);

% Validate rxNonHTData
validateattributes(rxNonHTData, {'double'}, {'2d','finite'}, 'rxHTData', 'Non-HT OFDM Data field signal'); 
% Validate chanEst
validateattributes(chanEst, {'double'}, {'3d','finite'}, 'chanEst', 'channel estimates'); 
% Validate noiseVarEst
validateattributes(noiseVarEst, {'double'}, {'real','scalar','nonnegative','finite'}, 'noiseVarEst', 'noise variance estimate'); 

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

numRx = size(rxNonHTData, 2);

mcsTable = wlan.internal.getRateTable(cfgNonHT);

 numOFDMSym = cfgNonHT.PSDULength;
%numOFDMSym = s.NumDataSymbols;

% Get OFDM configuration
[cfgOFDM,dataInd,pilotInd] = wlan.internal.wlanGetOFDMConfig(cfgNonHT.ChannelBandwidth, 'Long', 'Legacy');

% Cross validate inputs
numST = numel([dataInd; pilotInd]); % Total number of occupied subcarriers
coder.internal.errorIf(size(chanEst, 1) ~= numST, 'wlan:wlanNonHTDataRecover:InvalidNHTChanEst1D', numST);
coder.internal.errorIf(size(chanEst, 2) ~= 1, 'wlan:wlanNonHTDataRecover:InvalidNHTChanEst2D');
coder.internal.errorIf(size(chanEst, 3) ~= numRx, 'wlan:wlanNonHTDataRecover:InvalidNHTChanEst3D');

% Extract data and pilot subcarriers from channel estimate
chanEstData = chanEst(dataInd,:,:);
chanEstPilots = chanEst(pilotInd,:,:);

% Cross-validation between inputs
minInputLen = numOFDMSym*(cfgOFDM.FFTLength+cfgOFDM.CyclicPrefixLength);
coder.internal.errorIf(size(rxNonHTData, 1) < minInputLen, 'wlan:wlanNonHTDataRecover:ShortNHTDataInput', minInputLen);

% Processing 
% OFDM Demodulation 
[ofdmDemodData, ofdmDemodPilots] = wlan.internal.wlanOFDMDemodulate(rxNonHTData(1:minInputLen, :), cfgOFDM, symOffset);
%Construct demodulator
%
% CyclicPrefixLength = 16;
% FFTLength = 64;
% PilotCarrierIndices = cfgOFDM.PilotIndices;
% hDataDeMod = comm.OFDMDemodulator(...
%     'CyclicPrefixLength',   CyclicPrefixLength,...
%     'FFTLength' ,           FFTLength,...
%     'NumGuardBandCarriers', [6; 5],...
%     'NumSymbols',           numOFDMSym,...    
%     'PilotOutputPort',       true,...
%     'PilotCarrierIndices',  PilotCarrierIndices,...    
%     'RemoveDCCarrier',      true);
% 
% [ofdmDemodData, ofdmDemodPilots] = step(hDataDeMod, rxNonHTData);

% Pilot phase tracking
if calculateCPE==true || strcmp(pilotPhaseTracking, 'PreEQ')
    % Get reference pilots, from IEEE Std 802.11-2012, Eqn 18-22
    z = 1; % Offset by 1 to account for L-SIG pilot symbol
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





%demodulating with BPSK
eqDataSym = reshape(ofdmDemodData,numel(eqDataSym), []);
bpskDemod = comm.BPSKDemodulator; % BPSK
bits = step(bpskDemod,eqDataSym); % output

%release(hDataDeMod);

end