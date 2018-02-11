clear all;
%image 
picture = imread('boy.jpg');
pictureGrayScale = im2double(rgb2gray(picture)); 
%dct
pictureGrayScaleNorm = pictureGrayScale - mean(pictureGrayScale(:));
dctpicture = dct2(im2double(pictureGrayScaleNorm));


%chunks
thresh = 0.001;
chunkSize = [10 10];
iSize = size(dctpicture,1)/chunkSize(1);
jSize = size(dctpicture,2)/chunkSize(2);
pictureChunks = zeros(iSize,jSize);
pictureChunksVar = zeros(iSize,jSize);

for i = 1:iSize
    for j = 1: jSize
         chunk = (dctpicture(chunkSize(1)*(i-1)+1:chunkSize(1)*(i-1)+chunkSize(1),...
                             chunkSize(2)*(j-1)+1:chunkSize(2)*(j-1)+chunkSize(2)));
        pictureChunks(i,j) = mean(chunk(:));
        pictureChunksVar(i,j) = var(chunk(:)); 
    end
end


%reject near zero chunks
rejectMatrix = abs(pictureChunks) > thresh;
chunkVarVec = pictureChunksVar(rejectMatrix == 1);


%g calculation
P = 1;
%P = sum(abs(dctpicture(:)));

idxEnc = 1;
idxVar = 1;
y = zeros(sum(rejectMatrix(:)),1);
gEnc = zeros(length(chunkVarVec),1);
for iIdx = 1 : iSize
    for jIdx = 1 : jSize
        if rejectMatrix(iIdx,jIdx) == 1
            gEnc(idxVar) = (chunkVarVec(idxVar)^-1/4)*sqrt(P/sum(sqrt(chunkVarVec(:))));
            for iChunk = 1 : chunkSize(1)
                for jChunk = 1 : chunkSize(2)                 
                    y(idxEnc) = gEnc(idxVar)*dctpicture((iIdx-1)*iSize+iChunk,(jIdx-1)*jSize+jChunk);
                    idxEnc = idxEnc + 1;
                end
            end
            idxVar = idxVar + 1;
        end
    end
end


%decoder
%metadata
metadata.picSize = size(pictureGrayScale);
metadata.chunkSize = chunkSize;
metadata.matrix = rejectMatrix;
metadata.picMean = mean(pictureGrayScale(:));
metadata.lambda = chunkVarVec;


PRx = P; %fixed
var = 0;
estimateX = zeros(metadata.picSize);


idxDec = 1;
idxDecVar = 1;
gRx = zeros(length(metadata.lambda),1);
for iIdx = 1 : size(metadata.matrix,1)
    for jIdx = 1 : size(metadata.matrix,2)
        if metadata.matrix(iIdx,jIdx) == 1
            gRx(idxDecVar) = (metadata.lambda(idxDecVar)^-1/4)*sqrt(PRx/sum(sqrt(metadata.lambda(:))));          
            for iChunk = 1 : metadata.chunkSize(1)
                for jChunk = 1 : metadata.chunkSize(2)
                    estimateX((iIdx-1)*metadata.chunkSize(1)+iChunk,(jIdx-1)*metadata.chunkSize(2)+jChunk) = ...
                        metadata.lambda(idxDecVar)*gRx(idxDecVar)*y(idxDec)/(metadata.lambda(idxDecVar)*gRx(idxDecVar)^2 + var);
                    idxDec = idxDec + 1;
                end
            end
            idxDecVar = idxDecVar + 1;
        end
    end
end

recievedImg = estimateX;
% figure
% imshow(log(abs(dctpicture)),[])
% colormap(gca,jet(64))
% colorbar
% 
% figure
% imshow(log(abs(recievedImg)),[])
% colormap(gca,jet(64))
% colorbar

rxPicture = idct2(recievedImg);
finalPicture = rxPicture + metadata.picMean;
figure; imshow(finalPicture)


