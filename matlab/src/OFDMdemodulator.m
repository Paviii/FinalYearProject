function payloadCell = OFDMdemodulator(Y,dataLength, numOfVecs ,Aind,edges)

%number of data subcarriers could be variable in next version
numOfSubCar = 53;


H = comm.OFDMDemodulator;
symbolLength = H.CyclicPrefixLength + H.FFTLength;
payloadCell = cell(numOfVecs,1);

for iChannelVec = 1  : length(Y)
    H.NumSymbols = length(Y{iChannelVec})/symbolLength;
    Yiq = step(H,Y{iChannelVec});    
    
    for iSubCarr = 1 : numOfSubCar
        indVec = (iChannelVec-1)*numOfSubCar + iSubCarr;
        if indVec > numOfVecs
            break;
        end
        numOfEl = edges(Aind(indVec)+1);
        vecTmp = [real(Yiq(iSubCarr,1:ceil(numOfEl/2)))'; imag(Yiq(iSubCarr,1:ceil(numOfEl/2)))'];
        payloadCell{indVec} = vecTmp(1:numOfEl);
    end
    H.release();
end

end