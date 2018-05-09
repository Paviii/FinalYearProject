%% TX

rxOption = 1; %1 - AMP, 2 - basis pursuit, 3 - MMSE
chunkSize = [10 10];
thresh = 0.0001;


%image
picture = imread('test_data/boy.png');
pictureGrayScale = im2double(rgb2gray(picture));
figure; subplot(1,4,1); title('original');
imshow(pictureGrayScale);


%do chunks before DFT
imageChunks = createChunksV2(pictureGrayScale,chunkSize);

%dct and subtract mean
dctpicture = zeros(size(imageChunks));
numOfChunks = size(imageChunks,3);
numOfVecs = prod(chunkSize);
for iDCT = 1 : numOfChunks
    dctpicture(:,:,iDCT) =  dct2(imageChunks(:,:,iDCT));
end

%vectorize dct components and subtract mean
dctVec = zeros(numOfChunks,prod(chunkSize));
meanMat = zeros(chunkSize(1),chunkSize(2));
varMat = zeros(chunkSize(1),chunkSize(2));
for iVec = 1 : chunkSize(1)
    for jVec = 1 : chunkSize(2)
        vecTmp = dctpicture(iVec,jVec,:);
        meanMat(iVec,jVec) = mean(vecTmp);
        varMat(iVec,jVec) = var(vecTmp);
        
        dctVec(:,(iVec-1)*chunkSize(2) + jVec) = vecTmp - meanMat(iVec,jVec);
    end
end

%remove near-zero coefficients
dctVecSpar = dctVec;
dctVecSpar(abs(dctVec) < thresh) = 0;


%power allocation no feedback
P = 1;
gGen = sqrt(P/sum(sqrt(varMat(:))));
varMatTmp = varMat';
dctVecPow = zeros(size(dctVec));
for i = 1 : numOfVecs
    dctVecPow(:,i) = gGen*(varMatTmp(i)^-1/4)*dctVecSpar(:,i);
end

%power allocation with feedback
% P = 1;
% n = 1;
% gamma = (sum(varMat(:)*n)/(P + n*numOfVecs))^2;
% varMatTmp = varMat';
% dctVecPow = zeros(size(dctVecSpar));
% for i = 1 : numOfVecs
%     
%     lambda = varMatTmp(i);    
%     g = sqrt((sqrt(lambda*n/gamma) - n)/lambda);
%     dctVecPow(:,i) = g*dctVecSpar(:,i);
%     dctVecNorm = dctVecPow(:,i)*sqrt(mean(dctVecPow(:,i).^2)/lambda);
%     dctVecPow(:,i) = dctVecNorm;
%     
% end


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
    compSenVec{i} = Amult*dctVecPow(:,i);
end

%power allocation and transmit vector currently bypassed
% txVec = zeros(numel(compSenVec),1);
% P = 1;
% varSum = sqrt(P/sum(sqrt(varMat(:))));
% for i = 1 : numOfVecs
%     gTx = varMat(i)*varSum;
%     txVec((i-1)*K + 1: i*K ) = gTx .* compSenVec(:,i);
% end


%metadata sent over reliable channel
metadata.picSize = [size(picture,1) size(picture,2)];
metadata.meanMat = meanMat;
metadata.varMat = varMat;
metadata.Aind = Aind;
metadata.dataLength = sum(cellfun('length',compSenVec));

%create IQ format
y = OFDMmodulator(compSenVec);


%% Rx

%channel
SNR =  [10:5:50];
SNR = 200;
psnrRes = zeros(length(SNR),3);

%data for Rx
chunkSizeRx = size(metadata.meanMat);
numOfChunksRx = prod(metadata.picSize./chunkSizeRx);
numOfVecsRx = prod(chunkSizeRx);

for iSNR = 1 : length(SNR)
    
    noisVar = 10^(-SNR(iSNR)/10);
    
    yNoise = y + sqrt(noisVar/2)*(randn(size(y)) + 1i*randn(size(y)));
    
    %OFDM demodulator
    compSenVecRx = OFDMdemodulator(yNoise,metadata.dataLength, numOfVecsRx ,metadata.Aind,edges);
    
%     for i = 1 : numOfVecsRx
%         yNoise{i} = compSenVec{i} + sqrt(noisVar)*randn(size(compSenVec{i}));
%     end
    
    %power scaling is bypassed for now
    RxOpt = [1 6];
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
                estX =  MMSEReconstruction(compSenVecRx,A,metadata.Aind,numOfVecsRx,noisVar);
                
        end
        
        %power decoder with no feedback
        Prx = P; %no loss
        estXPow = zeros(size(estX));
        gGenRx = sqrt(Prx/sum(sqrt(metadata.varMat(:))));
        varMatTmp = metadata.varMat';
        for i = 1 : numOfVecsRx
            g = (varMatTmp(i)^-1/4)*gGenRx;
            estXPow(:,i) = (varMatTmp(i)*g/(varMatTmp(i)*g^2 + noisVar))*estX(:,i);
        end
        
        %power decoder with feedback
        
%         Prx = P; %no loss
%         estXPow = zeros(size(estX));
%         gammaRx = (sum(metadata.varMat(:)*noisVar)/(P + noisVar*numOfVecsRx))^2;        
%         varMatTmp = metadata.varMat';
%         for i = 1 : numOfVecsRx
%             lambda = varMatTmp(i);
%             g = sqrt((sqrt(lambda*noisVar/gammaRx) - noisVar)/lambda);
%             h = roots([g,-1,gammaRx*g]);
%             estXPow(:,i) = h(1)*estX(:,i);
%         end       
        
        
        rxBlock = zeros(chunkSizeRx(1),chunkSizeRx(2),numOfChunksRx);
        for iChunk = 1 : numOfChunksRx
            rxBlock(:,:,iChunk) = idct2(reshape(estXPow(iChunk,:),[chunkSizeRx(1) chunkSizeRx(2)])' + metadata.meanMat);
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
        imshow(rxPic);
        
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
