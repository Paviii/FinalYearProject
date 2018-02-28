function sOut = OMPReconstruction(y,A,Aind,numOfVecs)

numOfChunks = size(A{end},2);
sOut = zeros(numOfChunks,numOfVecs);
for iVec = 1 : numOfVecs
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};
    K = size(Atmp,1); %/size(A{end},2);    
    
    
    [x] = OMP (K,yVec.',Atmp);
    
    sOut(:,iVec) = x;
    
end

