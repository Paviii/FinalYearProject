function sOut = AMPReconstruction(y,A,Aind,numOfVecs,varMat)

numOfChunks = size(A{end},2);
sOut = zeros(numOfChunks,numOfVecs);

for iVec = 1 : numOfVecs
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};
    sparsity = size(Atmp,1) /size(A{end},2);        
    
    tol = 10e-6;
    maxiterations = 1000;
    Sest = cosamp(Atmp, yVec ,sparsity,tol,maxiterations);

    
    sOut(:,iVec) = Sest;
    
end

