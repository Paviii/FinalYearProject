function y  = SoftCastEncoder(dctcoeff,P,rejectMatrix,chunkVarVec,chunkSize)


if ~exist('P','var')
    P = 1;
end

if ~exist('chunkSize','var')
    chunkSize = [10 10];
end

numOfComp = size(dctcoeff,3);
numOfFrames = size(dctcoeff,4);

y = {};
for iFrame = 1 : numOfFrames
    for iComp = 1 : numOfComp                                
        gEnc = (chunkVarVec{iFrame}{iComp}.^-1/4)*sqrt(P/sum(sqrt(chunkVarVec{iFrame}{iComp})));
        currentFrame = dctcoeff(:,:,iComp,iFrame);
        y{iFrame}{iComp} = repelem(gEnc,prod(chunkSize)).*(currentFrame(repelem(rejectMatrix(:,:,iComp,iFrame),chunkSize(1),chunkSize(2)) == 1));
    end
end

