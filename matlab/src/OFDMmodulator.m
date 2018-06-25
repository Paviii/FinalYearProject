function [txSig, numOfDataSym]  = OFDMmodulator(data,payloadLength,frameNum)
%input data in cell array

%number of data subcarriers
numOfSubCar = 48;
CyclicPrefixLength = 16;
FFTLength = 64;
NumGuardBandCarriers = [6 ; 5];
PilotCarrierIndices = [12;26;40;54];

%prepare data

%vectorize data and make them complex
yVec = vertcat(data{:});
dataLen = length(yVec);
if mod(dataLen,2)~=0
    yVec = [yVec; 0]; %add zero if not even
    dataLen = dataLen + 1; 
end

yVecCompl = reshape(yVec,[2 dataLen/2]).';
yVecCompl = yVecCompl(:,1) + 1i*yVecCompl(:,2);

numOfDataSym = ceil(length(yVecCompl)/numOfSubCar);
%pad zeros
yVecCompl= [yVecCompl; zeros(numOfSubCar - rem(length(yVecCompl),numOfSubCar),1)];
yPar = reshape(yVecCompl,[numOfDataSym, numOfSubCar]).';
%pad zeros for packet segments
yPar = [yPar zeros(numOfSubCar,payloadLength - rem(numOfDataSym,payloadLength))];

%%%%%
save('src/Metadata/damp1','yVecCompl');
save('src/Metadata/damp2','yPar');
%%%%%
H = comm.OFDMModulator(...
    'CyclicPrefixLength',   CyclicPrefixLength,...
    'FFTLength' ,           FFTLength,...
    'NumGuardBandCarriers', NumGuardBandCarriers,...
    'NumSymbols',           payloadLength,...
    'PilotInputPort',       true,...
    'PilotCarrierIndices',  PilotCarrierIndices,...
    'InsertDCNull',         true);


numOfOPackets = ceil(numOfDataSym/payloadLength);

config = wlanNonHTConfig('ChannelBandwidth','CBW20');
sigPow = var(yVecCompl);
STF = wlanLSTF(config);
STF = STF/max(abs(STF));
LTF = wlanLLTF(config);
LTF = LTF/max(abs(LTF));
z =1; % Offset by 1 to account for L-SIG pilot symbol
pilots = wlan.internal.nonHTPilots(payloadLength, z);


%interpolate
rateConverter = dsp.FIRRateConverter('InterpolationFactor', 5,...
    'DecimationFactor', 4);

%create waveform
txSig = [];
for iPacket = 1 : numOfOPackets
    %disp(iPacket + frameNum*10)
    config.PSDULength = iPacket;% + frameNum*10; %maximum of 10 packets per frame
    SIG = sqrt(sigPow)*wlanLSIG(config);
    SIG = SIG/max(abs(SIG));    
    PPDU = step(H,yPar(:,(iPacket-1)*payloadLength+1:iPacket*payloadLength),pilots);
   
    txSig = [txSig; STF; LTF; SIG; PPDU];
end


H.release();


end

