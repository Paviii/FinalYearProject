%% TX

rxOption = 6; %1 - AMP, 2 - basis pursuit, 3 - MMSE
chunkSize = [10 10];
thresh = 0.1;


%image
picture = imread('test_data/boy.png');
pictureGrayScale = im2double(rgb2gray(picture));
figure; subplot(1,4,1); title('original');
imshow(pictureGrayScale);


%subtract mean and dct
pictureMean = mean(pictureGrayScale);
pictureNorm = pictureGrayScale - pictureMean;
dctpicture = dct2(pictureNorm);

%do chunks after DFT
[ imageChunks, ~, chunksVar] = createChunksV1(dctpicture ,chunkSize);
numOfChunks = size(imageChunks,3);
numOfVecs = prod(chunkSize);

%vectorize dct components 
dctVec = zeros(numOfChunks,prod(chunkSize));
meanMat = zeros(chunkSize(1),chunkSize(2));
varMat = zeros(chunkSize(1),chunkSize(2));
for iVec = 1 : chunkSize(1)
    for jVec = 1 : chunkSize(2)        
        dctVec(:,(iVec-1)*chunkSize(2) + jVec) = imageChunks(iVec,jVec,:);
    end
end

%remove near-zero coefficients
dctVecSpar = dctVec;
dctVecSpar(abs(dctVec) < thresh) = 0;


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

compSenVec = {};
Aind = zeros(1,numOfVecs);
numOfNonZero = zeros(1,numOfVecs);
for i = 1: numOfVecs
    numOfNonZero(i) = nnz(dctVecSpar(:,i));
    Aind(i) = discretize(nnz(dctVecSpar(:,i)),edges);
    Amult = A{Aind(i)};
    compSenVec{i} = Amult*dctVecSpar(:,i);
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
metadata.meanPic = pictureMean;
metadata.varMat = chunksVar;
metadata.Aind = Aind;


%% Rx

%channel
SNR =  [10:5:50];
psnrRes = zeros(length(SNR),2);


%data for Rx
chunkSizeRx = size(metadata.varMat);
numOfChunksRx = prod(metadata.picSize./chunkSizeRx);
numOfVecsRx = prod(chunkSizeRx);

for iSNR = 1 : length(SNR)
    
    noisVar = 10^(-SNR(iSNR)/10);
    y = {};
    for i = 1 : numOfVecsRx
        y{i} = compSenVec{i} + sqrt(noisVar/2)*randn(size(compSenVec{i}));
    end
    
    %power scaling is bypassed for now
    RxOpt = [1 6];
    for iRx = 1 : length(RxOpt)
        
        switch RxOpt(iRx)
            case 1
                %AMP estimator
                %estX = AMPReconstruction(y,A,metadata.Aind,numOfVecsRx,metadata.varMat);
                estX = AMPReconstruction2(y,A,metadata.Aind,numOfVecsRx);
                
            case 2
                %basis pursuit estimator
                estX = basisPursuitReconstruction(y,A,metadata.Aind,numOfVecsRx );
                
            case 3
                %subspace pursuit estimator
                estX = SubspacePursuitReconstruction(y,A,metadata.Aind,numOfVecsRx);
                
            case 4                
                % OMP estimator
                estX = OMPReconstruction(y,A,metadata.Aind,numOfVecsRx);
                
            case 5
                %CoSamp reconstruction
                estX = CoSampReconstruction(y,A,metadata.Aind,numOfVecsRx);
                
            otherwise
                %extimate X using MMSE
                estX =  MMSEReconstruction(y,A,metadata.Aind,numOfVecsRx,noisVar);
                
        end
        
        rxBlock = zeros(chunkSizeRx(1),chunkSizeRx(2),numOfChunksRx);
        for iChunk = 1 : numOfChunksRx
            rxBlock(:,:,iChunk) = reshape(estX(iChunk,:),[chunkSizeRx(1) chunkSizeRx(2)])';
        end
        
        rxPicDCT = zeros(metadata.picSize);
        dimOfChunk = metadata.picSize./chunkSizeRx;
        for iChunk = 1 : dimOfChunk(1)
            for jChunk = 1 : dimOfChunk(2)
                rxPicDCT((iChunk-1)*chunkSize(1) + 1 : (iChunk-1)*chunkSize(1)+chunkSize(1), ...
                    (jChunk-1)*chunkSize(2)+1:(jChunk-1)*chunkSize(2)+chunkSize(2))= ...
                    rxBlock(:,:,(iChunk-1)*dimOfChunk(2) + jChunk);
            end
        end
        rxPic = idct2(rxPicDCT) + metadata.meanPic;
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
%legend('AMP','basis pursuit','MMSE');
% figure;
% subplot(1,2,1);
% imshow(pictureGrayScale); title('original');
% subplot(1,2,2);
% imshow(rxPic); title('Reconstructed');
