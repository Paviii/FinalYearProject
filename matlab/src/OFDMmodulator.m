function Y  = OFDMmodulator(data)
%input data in cell array

%number of data subcarriers 
numOfSubCar = 53;
numOfChannelSymbols = ceil(length(data)/numOfSubCar);

H = comm.OFDMModulator;

Y = {};
for iChannSymb = 1 : numOfChannelSymbols
    dataInd = (iChannSymb-1)*numOfSubCar + 1 : min((iChannSymb-1)*numOfSubCar + 53,length(data));
    vecLen = max(cellfun(@(x) numel(x),data(dataInd)));
    
    H.NumSymbols = ceil(vecLen/2);
    
    dataMat = zeros(numOfSubCar,H.NumSymbols);
    dataTmp = data(dataInd);
    
    for iSubCar =  1 : length(dataInd)
        vecTmp = dataTmp{iSubCar};
        %add zero if not even
        if bitget(length(vecTmp),1)
            vecTmp = [vecTmp; 0];
        end
        dataMat(iSubCar,1:ceil(length(vecTmp)/2)) = vecTmp(1:end/2) + 1i*vecTmp(end/2+1:end);
    end
    
    Y{iChannSymb} = step(H,dataMat);
    H.release();
end


end

