function estX =  MMSEReconstruction(y,g,A,Aind,sigVar,numOfVecs,noisVar,sparsityPatternCell)

if exist('sparsityPatternCell','var')
    sparKnown = 1;
else
    sparKnown = 0;
end

numOfChunks = size(A{end},2);
estX = zeros(numOfChunks,numOfVecs);
for iVec = 1 : numOfVecs
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};
    sparsityPattern = sparsityPatternCell{iVec};
    
    nnzPattern = 1:numOfChunks;
    if sparKnown
        Atmp(:,sparsityPattern)  = [];
        nnzPattern(sparsityPattern) = [];
    end
    
    gAtmp = g(iVec)*Atmp;
    
    Cn = diag(noisVar*ones(1,length(nnzPattern)));
    W = sigVar(iVec)*gAtmp/(sigVar(iVec)*gAtmp'*gAtmp + Cn);
    %W = gAtmp/(gAtmp'*gAtmp + Cn);
    estX(nnzPattern,iVec) = W'*yVec;
    
end

