function Y  = OFDMmodulator(data)
%input data in cell array

%number of data subcarriers 
numOfSubCar = 53;

%create vector of data
dataVec = vertcat(data{:});
dataVecCompl = [dataVec(1:end/2) + 1i*dataVec(end/2+1:end)];

H = comm.OFDMModulator;
H.NumSymbols = ceil(length(dataVecCompl)/numOfSubCar);
%append zeros
dataVecExt = reshape([dataVecCompl; zeros(H.NumSymbols*numOfSubCar-length(dataVecCompl),1)],[numOfSubCar H.NumSymbols]) ;

Y = step(H,dataVecExt);

end

