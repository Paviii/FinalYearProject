function estimateX  = SoftCastDecoder(symRx,P,rejectMatrix,chunkVarVec,picSize,var)


if ~exist('P','var')
    P = 1;
end

numOfFrames = length(symRx);
numOfComp = length(symRx{1});

heightChunkSize = picSize(1)/size(rejectMatrix,1);
widthChunkSize = picSize(2)/size(rejectMatrix,2);

estimateX = zeros(picSize(1),picSize(2),numOfComp,numOfFrames);
for iFrame = 1 : numOfFrames
    for iComp = 1 : numOfComp                                
        gDec = repelem((chunkVarVec{iFrame}{iComp}.^-1/4)*sqrt(P/sum(sqrt(chunkVarVec{iFrame}{iComp}))),heightChunkSize*widthChunkSize);
        currentFrame = zeros(picSize(1),picSize(2));
        rejectMatrixPic = repelem(rejectMatrix(:,:,iComp,iFrame),heightChunkSize,widthChunkSize);
        chunkVarCurrFr = repelem(chunkVarVec{iFrame}{iComp},heightChunkSize*widthChunkSize);
        currentFrame(rejectMatrixPic == 1) = chunkVarCurrFr.*gDec.*symRx{iFrame}{iComp}./(chunkVarCurrFr.*gDec.^2 + var);
        estimateX(:,:,iComp,iFrame) = currentFrame;
    end
end
