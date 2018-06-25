%% TX

chunkSize = [25 25];
thresh = 0.001;
numOfCompFrames = 5;
payloadLength = 200;

%image
 picture = imread('test_data/image.jpg');
 pictureGrayScale = im2double(rgb2gray(picture));
 metadataBase.picSize = [size(pictureGrayScale,1) size(pictureGrayScale,2)];
 metadataBase.chunkSize = chunkSize;
 metadataBase.payloadLength = payloadLength;
 metadataBase.numOfFrames = 1;
 metadataBase.numOfCompFrames = numOfCompFrames;
 save('src/Metadata/metadataBase','metadataBase');

%video
% if ~exist('vid','var')
%     importVideoFile('test_data/vid.mp4');
%     [refFrames,motionVectsCell] =  montionCompensation(vid);
%     pictureGrayScale = refFrames{1};
%     
%     metadataBase.picSize = [size(pictureGrayScale,1) size(pictureGrayScale,2)];
%     metadataBase.chunkSize = chunkSize;
%     metadataBase.payloadLength = payloadLength;
%     metadataBase.numOfFrames = length(refFrames);
%     metadataBase.numOfCompFrames = numOfCompFrames;
%     save('src/Metadata/metadataBase','metadataBase');
% end

load('src/Metadata/matrix.mat','A');
load('src/Metadata/edges.mat','edges');

%generateRandMatrix(numOfChunks);

videoLen = 1;
compileIt = 1;
yCell = cell(videoLen,1);
for iFrame = 1 : videoLen
    
% pictureGrayScale = refFrames{iFrame};
% motionVectsGroup = motionVectsCell((iFrame-1)*(numOfCompFrames-1) + 1:iFrame*(numOfCompFrames-1));

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
    nonzeroVec = nonzeros(dctVecSpar(:,i));
    if isempty(nonzeroVec)
        nonzeroVec = 0;
    end
    meanMat(i) = mean(nonzeroVec); %mean of non-zero terms
    varMat(i) = var(nonzeroVec); %variance of non-zero terms
    nnzInd = dctVecSpar(:,i) ~= 0;
    sparsityPattern{i} = find(dctVecSpar(:,i) == 0 );
    dctVecSpar(nnzInd,i) = dctVecSpar(nnzInd,i) - meanMat(i);    
end

%video processing


%multiple by random matrix

compSenVec = cell(numOfVecs,1);
Aind = zeros(1,numOfVecs);
numOfNonZero = zeros(1,numOfVecs);
for i = 1: numOfVecs
    numOfNonZero(i) = max(nnz(dctVecSpar(:,i)),1);
    Aind(i) = discretize(numOfNonZero(i),edges);
    Amult = A{Aind(i)};
    compSenVec{i} = Amult*dctVecSpar(:,i);
end

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

%noisVar = 0.1;
noisVar = 0.01;
%power allocation with feedback
P = 100;
n = noisVar*ones(1,numOfVecs);
gamma = (sum(varMat.*n)/(P + sum(n)))^2;
powAlocCell = cell(numOfVecs,1);
g = zeros(numOfVecs,1);
for i = 1 : numOfVecs
     lambda = varMat(i);
     if lambda == 0
         g(i) = 0;
     else
         g(i) = sqrt(abs(sqrt(lambda*n(i)/gamma) - n(i))/lambda);
     end
     powAlocCell{i} = g(i)*compSenVec{i};     
end

if iFrame == 119
    5;
end

%create IQ format with power allocation 
[y, numOfDataSym] = OFDMmodulator(powAlocCell,payloadLength,iFrame);

%save metadata
%metadata sent over reliable channel

metadata.dataLength = numOfDataSym;
metadata.sparsity = numOfNonZero/numOfChunks;
metadata.Aind = Aind;
metadata.meanMat = meanMat;
metadata.varMat = varMat;
%metadata.motionVectsGroup = motionVectsGroup;

% metadata.y = y;
% metadata.compSenVec = powAlocCell;
 metadata.sparsityPattern = sparsityPattern;
% metadata.g = g;
% metadata.dctVecSpar = dctVecSpar;

save(sprintf('src/Metadata/metadata%d',iFrame),'metadata');

%transmit
yCell{iFrame} = y;

end


TxWrapper(yCell{1},compileIt);        