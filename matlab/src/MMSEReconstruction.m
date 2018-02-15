function estX =  MMSEReconstruction(y,A,Aind,numOfVecs,noisVar)

numOfChunks = size(A{end},2);
estX = zeros(numOfChunks,numOfVecs);
for iVec = 1 : numOfVecs
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};
    
    Cn = diag(noisVar*ones(1,length(yVec)));
    W = Atmp'/(Atmp*Atmp' + Cn);
    estX(:,iVec) = W*yVec;
    
end

