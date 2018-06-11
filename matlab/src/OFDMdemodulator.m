function payloadCell = OFDMdemodulator(Y,dataLength, numOfVecs ,Aind,edges, USRPuse)

%if USRP used no OFDM demodulation as it does it 
if ~USRPuse
%number of data subcarriers could be variable in next version
CyclicPrefixLength = 16;
FFTLength = 64;
NumGuardBandCarriers = [6 ; 5];
PilotCarrierIndices = [12;26;40;54];
hDataDeMod = comm.OFDMDemodulator(...
    'CyclicPrefixLength',   CyclicPrefixLength,...
    'FFTLength' ,           FFTLength,...
    'NumGuardBandCarriers', NumGuardBandCarriers,...
    'NumSymbols',           dataLength,...    
    'PilotOutputPort',       true,...
    'PilotCarrierIndices',  PilotCarrierIndices,...    
    'RemoveDCCarrier',      true);

[ofdmDemodData, ofdmDemodPilots] = step(hDataDeMod, Y);
release(hDataDeMod);
else
    ofdmDemodData = Y;
end

%vectorize data 
ofdmDemodDataTr = ofdmDemodData.';
ofdmDemodDataVec = [real(ofdmDemodDataTr(:)) imag(ofdmDemodDataTr(:))].';
ofdmDemodDataVec = ofdmDemodDataVec(:);

%assign vectors to cell
payloadCell = cell(numOfVecs,1);
iStart = 1;
for iVec = 1  : numOfVecs
    numOfEl = edges(Aind(iVec)+1);
    payloadCell{iVec} = ofdmDemodDataVec(iStart:iStart+numOfEl-1);
    iStart = iStart + numOfEl;
end


end