%% TX

chunkSize = [25 25];
thresh = 0.01;

payloadLength = 30;


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
     g(i) = sqrt((sqrt(lambda*n(i)/gamma) - n(i))/lambda);
     powAlocCell{i} = g(i)*compSenVec{i};     
end

%create IQ format with power allocation 
[y, numOfDataSym] = OFDMmodulator(powAlocCell,payloadLength);


%save metadata
%metadata sent over reliable channel
metadata.picSize = [size(picture,1) size(picture,2)];
metadata.chunkSize = chunkSize;
metadata.meanMat = meanMat;
metadata.varMat = varMat;

metadata.edges = edges;
metadata.dataLength = numOfDataSym;
metadata.payloadLength = payloadLength;
metadata.sparsity = numOfNonZero/numOfChunks;



metadata.Aind = Aind;
metadata.A = A;

metadata.y = y;
metadata.compSenVec = powAlocCell;
metadata.sparsityPattern = sparsityPattern;
metadata.g = g;
metadata.dctVecSpar = dctVecSpar;

save('src/Metadata/metadata','metadata');

%transmit
TxWrapper(y);

