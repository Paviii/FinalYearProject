
chunkSize = [25 25];
thresh = 0.001;

%image 
picture = imread('image.jpg');
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
        
        dctVec(:,(iVec-1)*chunkSize(2) + jVec) = vecTmp - meanMat(iVec,jVec);
    end
end       

%remove near-zero coefficients
dctVecSpar = dctVec;
dctVecSpar(abs(dctVec) < thresh) = 0;



%multiple by random matrix
K = 20;
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

y = compSenVec(:,1);

noisVar = 0;
Cn = diag(noisVar*ones(1,K));
Cx = diag(metadata.varMat(1,1)*ones(1,numOfChunksRx));
estX = Cx*A'*inv(A*Cx*A' + Cn)*y;


vidRetr = mirt_idctn(estX) + metadata.frameMean;

figure;
currAxes = axes;
for iFrame = 1 : numOfFrames   
    image(vidRetr(:,:,:,iFrame), 'Parent', currAxes);
    pause(1/v.FrameRate);
end

psnr(vidRetr,vidFrames)