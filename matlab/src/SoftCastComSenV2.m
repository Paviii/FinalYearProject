%% TX

chunkSize = [25 25];
thresh = 0.01;


%image
picture = imread('test_data/image.jpg');
pictureGrayScale = im2double(rgb2gray(picture));
% figure; subplot(1,4,1); title('original');
% imshow(pictureGrayScale);


%do chunks before DFT
imageChunks = createChunksV2(pictureGrayScale,chunkSize);

%dct and subtract mean
dctpicture = zeros(size(imageChunks));
numOfChunks = size(imageChunks,3);
numOfVecs = prod(chunkSize);
for iDCT = 1 : numOfChunks
    dctpicture(:,:,iDCT) =  dct2(imageChunks(:,:,iDCT));
end


%vectorize dct components 
dctVec = zeros(numOfChunks,prod(chunkSize));
for iVec = 1 : chunkSize(1)
    for jVec = 1 : chunkSize(2)
        vecTmp = dctpicture(iVec,jVec,:);                
        dctVec(:,(iVec-1)*chunkSize(2) + jVec) = vecTmp;
    end
end


%remove near-zero coefficients
dctVecSpar = dctVec;
dctVecSpar(abs(dctVec) < thresh) = 0;

% subtract mean and find variance
meanMat = zeros(1,numOfVecs);
varMat = zeros(1,numOfVecs);
sparsityPattern = cell(numOfVecs,1);
for i = 1 : numOfVecs
    meanMat(i) = mean(nonzeros(dctVecSpar(:,i))); %mean of non-zero terms
    varMat(i) = var(nonzeros(dctVecSpar(:,i))); %variance of non-zero terms
    nnzInd = dctVecSpar(:,i) ~= 0;
    sparsityPattern{i} = find(dctVecSpar(:,i) == 0 );
    dctVecSpar(nnzInd,i) = dctVecSpar(nnzInd,i) - meanMat(i);    
end

%multiple by random matrix

%generate Random matrix, known for tx and rx
A  = {};
edges = round([1 numOfChunks*0.2 numOfChunks*0.5 numOfChunks*0.7 numOfChunks]);
% 20%
A{1} = (1/sqrt(edges(2)))*randn(edges(2),numOfChunks);
% 50%
A{2} = (1/sqrt(edges(3)))*randn(edges(3),numOfChunks);
% 70%
A{3} = (1/sqrt(edges(4)))*randn(edges(4),numOfChunks);
% 100%
A{4} = (1/sqrt(edges(5)))*randn(edges(5),numOfChunks);

compSenVec = cell(numOfVecs,1);
Aind = zeros(1,numOfVecs);
numOfNonZero = zeros(1,numOfVecs);
for i = 1: numOfVecs
    numOfNonZero(i) = nnz(dctVecSpar(:,i));
    Aind(i) = discretize(nnz(dctVecSpar(:,i)),edges);
    Amult = A{Aind(i)};
    compSenVec{i} = Amult*dctVecSpar(:,i);
end

%metadata sent over reliable channel
metadata.picSize = [size(picture,1) size(picture,2)];
metadata.chunkSize = chunkSize;
metadata.meanMat = meanMat;
metadata.varMat = varMat;
metadata.Aind = Aind;
metadata.dataLength = sum(cellfun('length',compSenVec));
metadata.sparsity = numOfNonZero/numOfChunks;


%power allocation no feedback
% P = 1;
% gamma = sqrt(P/sum(sqrt(varMat(:))));
% powAlocCell = cell(numOfVecs,1);
% g = zeros(numOfVecs,1);
% for i = 1 : numOfVecs
%     g(i) = 1; %(varMat(i)^-1/4)*gamma;
%     powAlocCell{i} = g(i)*compSenVec{i};
% end


%channel
SNR =  [0:50];
%SNR = 100;
psnrRes = zeros(length(SNR),3);
for iSNR = 1 : length(SNR)
    noisVar = 10^(-SNR(iSNR)/10);

%power allocation with feedback
P = 1;
n = noisVar*ones(1,numOfVecs);
gamma = (sum(varMat.*n)/(P + sum(n)))^2;
powAlocCell = cell(numOfVecs,1);
g = zeros(numOfVecs,1);
for i = 1 : numOfVecs
     lambda = varMat(i);
     g(i) = sqrt((sqrt(lambda*n(i)/gamma) - n(i))/lambda);
     powAlocCell{i} = g(i)*compSenVec{i};
end

%create IQ format with power allocation 
y = OFDMmodulator(powAlocCell);


%% Rx



%data for Rx
chunkSizeRx = metadata.chunkSize;
numOfChunksRx = prod(metadata.picSize./chunkSizeRx);
numOfVecsRx = prod(chunkSizeRx);


    
    
    
    yNoise = cell(length(y),1);
    for i = 1 : length(y)
        yNoise{i} = y{i} + sqrt(noisVar/2)*(randn(size(y{i})) + 1i*randn(size(y{i})));
    end
    
    %OFDM demodulator
    compSenVecRx = OFDMdemodulator(yNoise,metadata.dataLength, numOfVecsRx ,metadata.Aind,edges);
    
    %find g for power allocation
    Prx = P; %no loss
    nRx = noisVar*ones(1,numOfVecsRx);
    gammaRx = (sum(metadata.varMat.*nRx)/(Prx + sum(nRx)))^2;
    gRx = zeros(numOfVecsRx,1);
    for i = 1 : numOfVecsRx
        lambda = metadata.varMat(i);
       gRx(i) = sqrt((sqrt(lambda*nRx(i)/gammaRx) - nRx(i))/lambda);
    end
    gRx = g;
    %power scaling is bypassed for now
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
                rxPic((iChunk-1)*chunkSize(1) + 1 : (iChunk-1)*chunkSize(1)+chunkSize(1), ...
                    (jChunk-1)*chunkSize(2)+1:(jChunk-1)*chunkSize(2)+chunkSize(2))= ...
                    rxBlock(:,:,(iChunk-1)*dimOfChunk(2) + jChunk);
            end
        end
        %figure;
        %getSDRuDriverVersion
        %pause
        
        psnrRes(iSNR,iRx) = psnr(rxPic,pictureGrayScale);
    end
end

%plotting 
estimators = { 'AMP' , 'Basis Pursuit', 'Subspace Pursuit', 'OMP', 'CoSamp', 'MMSE'};

figure;
legendCell = cell(length(RxOpt),1);
for iRx = 1 : length(RxOpt)
    plot(SNR,psnrRes(:,iRx),'-x');
    hold on;
    legendCell{iRx} = estimators{RxOpt(iRx)};
end
grid on; xlabel('SNR (dB)'); ylabel('PSNR (dB)');
legend(legendCell);


% e = zeros(size(estX,2));
% for i = 1 : 225
%     e(i) = mean((estX(:,i) - dctVecNorm(:,i)).^2);
% end
% figure; plot(e)
    