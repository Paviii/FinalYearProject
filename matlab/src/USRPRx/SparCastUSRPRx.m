%% Rx
useCodegen = 0;
%metadata for Rx

load('src/Metadata/matrix.mat','A');
load('src/Metadata/edges.mat','edges');
load('src/Metadata/metadataBase.mat','metadataBase');

chunkSizeRx = metadataBase.chunkSize;
numOfChunksRx = prod(metadataBase.picSize./chunkSizeRx);
numOfVecsRx = prod(chunkSizeRx);

payloadLength = metadataBase.payloadLength;
numOfFrames = metadataBase.numOfFrames;
numOfCompFrames = metadataBase.numOfCompFrames;

%figure;

if useCodegen
    codegen RxWrapper -args {dataLength, numOfPackets}
end

% Set up system
% System info
SampleRate = 40e6; % Hz
SymbolLength = 80; % Samples in 20MHz OFDM Symbol (FFT+CP)
FramesToCollect = 1;    
DecimationFactor = 2;


% Setup USRP

Radio = comm.SDRuReceiver(...
            'Platform',             'B200', ...
            'SerialNum',            '30A3E9F',...'30A3E93', ...
            'MasterClockRate',      SampleRate, ...
            'CenterFrequency',      2.3e9, ...
            'Gain',                 30, ...
            'DecimationFactor',     DecimationFactor, ...
            'SamplesPerFrame',      SymbolLength, ...
            'EnableBurstMode',      true,...
            'NumFramesInBurst',     FramesToCollect,...
            'TransportDataType',    'int16', ...
            'LocalOscillatorOffset', 0,...
            'OutputDataType',       'double');

%initiliaze

numOfFrames = 2;

videoLength = numOfFrames*numOfCompFrames;
refFrames = cell(numOfFrames,1);
motionVects = cell(videoLength - numOfFrames,1);

frameSeq = 1 : numOfFrames;
detFrame = [];
while 1
%while ~all(ismember(frameSeq, detFrame))
%for iFrame = 1 :  numOfFrames
    
%     load(sprintf('src/Metadata/metadata%d.mat',iFrame),'metadata');
    load('src/Metadata/metadata1.mat','metadata');
    dataLength = metadata.dataLength;
    numOfPackets = ceil(dataLength/payloadLength);
    
    %capture packet
    if useCodegen
        [yNoise, noisVar,frameNumber] = RxWrapper_mex(payloadLength,numOfPackets,dataLength);
    else
        [yNoise, noisVar,frameNumber] = RxWrapper(payloadLength,numOfPackets,dataLength,Radio);
    end
    
    %OFDM demodulator
    compSenVecRx = OFDMdemodulator(yNoise, dataLength, numOfVecsRx ,metadata.Aind,edges,1);
    
    
    %power allocation decoding
    Prx = 100;
    n = 0.01*ones(1,numOfVecsRx);
    gamma = (sum(metadata.varMat.*n)/(Prx + sum(n)))^2;
    gRx = zeros(numOfVecsRx,1);
    for i = 1 : numOfVecsRx
        lambda = metadata.varMat(i);
        gRx(i) = sqrt(abs(sqrt(lambda*n(i)/gamma) - n(i))/lambda);
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
        
        rxPic = zeros(metadataBase.picSize);
        dimOfChunk = metadataBase.picSize./chunkSizeRx;
        for iChunk = 1 : dimOfChunk(1)
            for jChunk = 1 : dimOfChunk(2)
                rxPic((iChunk-1)*chunkSizeRx(1) + 1 : (iChunk-1)*chunkSizeRx(1)+chunkSizeRx(1), ...
                    (jChunk-1)*chunkSizeRx(2)+1:(jChunk-1)*chunkSizeRx(2)+chunkSizeRx(2))= ...
                    rxBlock(:,:,(iChunk-1)*dimOfChunk(2) + jChunk);
            end
        end
        
        imshow(rxPic);
        refFrames{frameNumber} = rxPic;
        detFrame = [detFrame; frameNumber]; %note the frame number
        %motionVects((frameNumber-1)*(numOfCompFrames-1) + 1 : frameNumber*(numOfCompFrames-1)) = metadata.motionVectsGroup((frameNumber-1)*(numOfCompFrames-1) + 1 : frameNumber*(numOfCompFrames-1));
    end
    
end


%reconstruct video

% vid = reconstructVideo(refFrames,motionVects,[metadataBase.picSize(1) metadataBase.picSize(2) videoLength],numOfCompFrames);
% 
% implay(vid)

