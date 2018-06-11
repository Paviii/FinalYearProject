%% Rx

%metadata for Rx
load('src/Metadata/metadata.mat','metadata');
A = metadata.A;
edges = metadata.edges;
chunkSizeRx = metadata.chunkSize;
numOfChunksRx = prod(metadata.picSize./chunkSizeRx);
numOfVecsRx = prod(chunkSizeRx);
%figure;


% System info
SampleRate = 20e6; % Hz
SymbolLength = 1600; % Samples in 20MHz OFDM Symbol (FFT+CP)
FramesToCollect = 1;
    %floor(SampleRate*Config.SimInfo.CaptureDuration/SymbolLength);
DecimationFactor = 1;


% Setup USRP
Radio = comm.SDRuReceiver(...
            'Platform',             'B200', ...
            'SerialNum',            '30A3E93', ...
            'MasterClockRate',      SampleRate, ...
            'CenterFrequency',      2.3e9, ...
            'Gain',                 50, ...
            'DecimationFactor',     DecimationFactor, ...
            'SamplesPerFrame',      SymbolLength, ...
            'EnableBurstMode',      true,...
            'NumFramesInBurst',     1,...
            'TransportDataType',    'int8', ...
            'OutputDataType',       'double');

% Set up Front-End Packet Synchronizer
WLANFrontEnd = customOFDMSync('ChannelBandwidth', 'CBW20');  
WLANFrontEnd.numOfDataSymbols = metadata.dataLength;



while 1

%capture packet
[yNoise, noisVar] = RxWrapper(Radio,WLANFrontEnd,SymbolLength);


%OFDM demodulator
compSenVecRx = OFDMdemodulator(yNoise,metadata.dataLength, numOfVecsRx ,metadata.Aind,edges,1);


%power allocation decoding
Prx = 1;
n = noisVar*ones(1,numOfVecsRx);
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
            %sparsityPatternRx = sparsityPattern;
            
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