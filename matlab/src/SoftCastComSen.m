
chunkSize = [25 25];
thresh = 0.01;

%image 
picture = imread('test_data/image.jpg');
pictureGrayScale = im2double(rgb2gray(picture)); 

%do chunks before DFT
imageChunks = createChunksV2(pictureGrayScale,chunkSize);

%dct and subtract mean
dctpicture = zeros(size(imageChunks));
numOfChunks = size(imageChunks,3);
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
        
        dctVec(:,(iVec-1)*chunkSize(2) + jVec) = vecTmp;% - meanMat(iVec,jVec);
    end
end

%remove near-zero coefficients
dctVecSpar = dctVec;
dctVecSpar(abs(dctVec) < thresh) = 0;


%multiple by random matrix

K = 81;
A = randn(K,size(dctVecSpar,1));
compSenVec = A*dctVecSpar;


%power allocation and transmit vector
txVec = zeros(numel(compSenVec),1);
P = 1;
varSum = sqrt(P/sum(sqrt(varMat(:))));
for i = 1 : prod(chunkSize)
   gTx = varMat(i)*varSum;
   txVec((i-1)*K + 1: i*K ) = gTx .* compSenVec(:,i);
end

%metadata sent over reliable channel 
metadata.picSize = [size(picture,1) size(picture,2)];
metadata.meanMat = meanMat;
metadata.varMat = varMat;
metadata.K = K;


%receiver
chunkSizeRx = size(metadata.meanMat);
numOfChunksRx = prod(metadata.picSize./chunkSizeRx);
%scale by power


%extimate X using MMSE
noisVar = 0.001;
y = compSenVec + sqrt(noisVar)*randn(size(compSenVec));


Cn = diag(noisVar*ones(1,K));
crsCov = xcov(dctVecSpar(:,1));
Cx = diag(crsCov(1:numOfChunksRx));
estX = A'*inv(A*A' + Cn)*y;


rxBlock = zeros(chunkSizeRx(1),chunkSizeRx(2),numOfChunksRx);

for iChunk = 1 : numOfChunksRx
   rxBlock(:,:,iChunk) = idct2(reshape(estX(iChunk,:),[chunkSizeRx(1) chunkSizeRx(2)])');% + metadata.meanMat);
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

figure; imshow(rxPic);
