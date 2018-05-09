function [imageChunk,chunksMean, chunksVar] = createChunksV1(dctcoeff,chunkSize)
%input DCT coefficients
%dimenstions: height * width * 3 (RGB component) or 1 (gray colour)  * number of Framer per GOP


if ~exist('chunkSize','var')
    chunkSize = [10 10];
end

numOfComp = size(dctcoeff,3);
numFrames = size(dctcoeff,4);
iSize = size(dctcoeff,1)/chunkSize(1);
jSize = size(dctcoeff,2)/chunkSize(2);
pictureChunksMean = zeros(iSize,jSize,numOfComp ,numFrames);
pictureChunksVar = zeros(iSize,jSize,numOfComp ,numFrames);
numOfChunks = iSize*jSize;
imageChunk = zeros(chunkSize(1),chunkSize(2),numOfChunks);

for iFrame = 1 : numFrames
    for iComp = 1 : numOfComp 
        for i = 1:iSize
            for j = 1: jSize
                chunk = (dctcoeff(chunkSize(1)*(i-1)+1:chunkSize(1)*(i-1)+chunkSize(1),...
                    chunkSize(2)*(j-1)+1:chunkSize(2)*(j-1)+chunkSize(2),iComp,iFrame));
                pictureChunksMean(i,j,iComp,iFrame) = mean(chunk(:));
                pictureChunksVar(i,j,iComp,iFrame) = var(chunk(:));
                imageChunk(:,:,j + jSize*(i-1)) = chunk;
            end
        end
    end
end

chunksMean = pictureChunksMean;
chunksVar = pictureChunksVar;