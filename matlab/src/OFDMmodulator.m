function [Y, numOfDataSym]  = OFDMmodulator(data)
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



H = OFDMModulator(...
    'CyclicPrefixLength',   CyclicPrefixLength,...
    'FFTLength' ,           FFTLength,...
    'NumGuardBandCarriers', NumGuardBandCarriers,...
    'NumSymbols',           numOfDataSym,...
    'PilotInputPort',       true,...
    'PilotCarrierIndices',  PilotCarrierIndices,...
    'InsertDCNull',         true);

% Create Pilots
% hPN = comm.PNSequence(...
%     'Polynomial',[1 0 0 0 1 0 0 1],...
%     'SamplesPerFrame',numOfDataSym,...
%     'InitialConditions',[1 1 1 1 1 1 1]);
% 
% pilot = step(hPN); % Create pilot
% pilots = repmat(pilot, 1, 4 ); % Expand to all pilot tones
% pilots = 2*double(pilots.'<1)-1; % Bipolar to unipolar
% pilots(4,:) = -1*pilots(4,:); % Invert last pilot

n = (0:numOfDataSym-1).'; % Indices of symbols within the field
pilotSeq = [1 1 1 -1].'; % IEEE Std 802.11-2012 Eqn 18-24
polaritySeq = wlan.internal.pilotPolaritySequence(n+1).'; % IEEE Std 802.11-2012 Eqn 18-25 
pilots = bsxfun(@times,polaritySeq,pilotSeq);


Y = step(H,yPar,pilots);

H.release();
%hPN.release();



% Y = cell(numOfChannelSymbols,1);
% numOfSym = zeros(numOfChannelSymbols,1);
% for iChannSymb = 1 : numOfChannelSymbols
%     dataInd = (iChannSymb-1)*numOfSubCar + 1 : min((iChannSymb-1)*numOfSubCar + numOfSubCar,length(data));
%     vecLen = max(cellfun(@(x) numel(x),data(dataInd)));
%     
%     H.NumSymbols = ceil(vecLen/2);
%     hPN.SamplesPerFrame = H.NumSymbols;
%     
%     
%     
%     dataMat = zeros(numOfSubCar,H.NumSymbols);
%     dataTmp = data(dataInd);
%     
%     for iSubCar =  1 : length(dataInd)
%         vecTmp = dataTmp{iSubCar};
%         %add zero if not even
%         if bitget(length(vecTmp),1)
%             vecTmp = [vecTmp; 0];
%         end
%         dataMat(iSubCar,1:ceil(length(vecTmp)/2)) = vecTmp(1:end/2) + 1i*vecTmp(end/2+1:end);
%     end
%     
%     Y{iChannSymb} = step(H,dataMat,pilots);
%     numOfSym(iChannSymb) = length(Y{iChannSymb});
%     H.release();
%     hPN.release();
% end


end

