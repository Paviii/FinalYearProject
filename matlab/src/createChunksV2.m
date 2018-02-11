function [imageChunk] = createChunksV2(image,chunkSize)
%input DCT coefficients
%dimenstions: height * width * 3 (RGB component) or 1 (gray colour)  * number of Framer per GOP
%second versions of chunks this is doing it before DCT


if ~exist('chunkSize','var')
    chunkSize = [10 10];
end

numOfComp = size(image,3);
numFrames = size(image,4);
iSize = size(image,1)/chunkSize(1);
jSize = size(image,2)/chunkSize(2);
numOfChunks = iSize*jSize;
imageChunk = zeros(chunkSize(1),chunkSize(2),numOfChunks);

for iFrame = 1 : numFrames
    for iComp = 1 : numOfComp 
        for i = 1:iSize
            for j = 1: jSize
                chunk = (image(chunkSize(1)*(i-1)+1:chunkSize(1)*(i-1)+chunkSize(1),...
                    chunkSize(2)*(j-1)+1:chunkSize(2)*(j-1)+chunkSize(2),iComp,iFrame));
                imageChunk(:,:,j + jSize*(i-1)) = chunk;
            end
        end
    end
end
