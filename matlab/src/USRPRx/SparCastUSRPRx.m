%% Rx
useCodegen = 1;
%metadata for Rx
load('src/Metadata/metadata.mat','metadata');
A = metadata.A;
edges = metadata.edges;
chunkSizeRx = metadata.chunkSize;
numOfChunksRx = prod(metadata.picSize./chunkSizeRx);
numOfVecsRx = prod(chunkSizeRx);
dataLength = metadata.dataLength;
%figure;

if useCodegen 
    codegen RxWrapper -args {dataLength}
end

while 1

%capture packet
if useCodegen
    [yNoise, noisVar] = RxWrapper_mex(dataLength);
else
    [yNoise, noisVar] = RxWrapper(dataLength);
end

%OFDM demodulator
compSenVecRx = OFDMdemodulator(yNoise,dataLength, numOfVecsRx ,metadata.Aind,edges,1);


%power allocation decoding
Prx = 1000;
n = 0.01*ones(1,numOfVecsRx);
gamma = (sum(metadata.varMat.*n)/(Prx + sum(n)))^2;
gRx = zeros(numOfVecsRx,1);
for i = 1 : numOfVecsRx
    lambda = metadata.varMat(i);
    gRx(i) = abs(sqrt((sqrt(lambda*n(i)/gamma) - n(i))/lambda));
    %gRx(i) = 1;
end


RxOpt = [6];
for iRx = 1 : length(RxOpt)
    
    switch RxOpt(iRx)
        case 1
            %AMP estimator
            %estX = AMPReconstruction(y,A,metadata.Aind,numOfVecsRx,metadata.varMat);
            estX = AMPReconstruction2(compSenVecRx,A,metadata.Aind,numOfVecsRx);
            
        case 2
            %basis pursuit estimator
            estX = basisPursuitReconstruction(compSenVecRx,A,metadata.Aind,numOfVecsRx );
            
        case 3
            %subspace pursuit estimator
            estX = SubspacePursuitReconstruction(compSenVecRx,A,metadata.Aind,numOfVecsRx);
            
        case 4
            % OMP estimator
            estX = OMPReconstruction(compSenVecRx,A,metadata.Aind,numOfVecsRx);
            
        case 5
            %CoSamp reconstruction
            estX = CoSampReconstruction(compSenVecRx,A,metadata.Aind,numOfVecsRx);
            
            
        otherwise
            %extimate X using MMSE
            [sparsityPatternRx, estXAmp] =  gbAMP(compSenVecRx,gRx,A,metadata.Aind,metadata.varMat,metadata.sparsity,numOfVecsRx,noisVar);
            estX = estXAmp;
            %sparsityPatternRx = metadata.sparsityPattern;
            
            %estX =  MMSEReconstruction(compSenVecRx,gRx,A,metadata.Aind,metadata.varMat,numOfVecsRx,noisVar,sparsityPatternRx);
            
            
    end
    
    %add mean
    estXMean = zeros(size(estX));
    indTmp = 1 : numOfChunksRx;
    for  i = 1 : numOfVecsRx
        nnzInd = find(~ismember(indTmp,sparsityPatternRx{i}));
        estXMean(nnzInd,i) = estX(nnzInd,i) + metadata.meanMat(i) ;
    end
    
    rxBlock = zeros(chunkSizeRx(1),chunkSizeRx(2),numOfChunksRx);
    for iChunk = 1 : numOfChunksRx
        rxBlock(:,:,iChunk) = idct2(reshape(estXMean(iChunk,:),[chunkSizeRx(1) chunkSizeRx(2)])');
    end
    
    rxPic = zeros(metadata.picSize);
    dimOfChunk = metadata.picSize./chunkSizeRx;
    for iChunk = 1 : dimOfChunk(1)
        for jChunk = 1 : dimOfChunk(2)
            rxPic((iChunk-1)*chunkSizeRx(1) + 1 : (iChunk-1)*chunkSizeRx(1)+chunkSizeRx(1), ...
                (jChunk-1)*chunkSizeRx(2)+1:(jChunk-1)*chunkSizeRx(2)+chunkSizeRx(2))= ...
                rxBlock(:,:,(iChunk-1)*dimOfChunk(2) + jChunk);
        end
    end
          
    imshow(rxPic);
    

end

end