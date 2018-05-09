function payloadCell = OFDMdemodulator(Y,dataLength, numOfVecs ,Aind,edges)

%number of data subcarriers could be variable in next version
%numOfSubCar = 53;

H = comm.OFDMDemodulator;
symbolLength = H.CyclicPrefixLength + H.FFTLength;
H.NumSymbols = length(Y)/symbolLength;
Yiq = step(H,Y);

payload = Yiq(:);
YiqDem = [real(payload(1:dataLength/2)) ; imag(payload(1:dataLength/2))];


payloadCell = cell(numOfVecs,1);
indEnd = 0;
for iVec = 1 : numOfVecs
    indStart = indEnd + 1;
    indEnd = indStart + edges(Aind(iVec)+1) - 1;
    payloadCell{iVec} = YiqDem(indStart:indEnd);
end

end