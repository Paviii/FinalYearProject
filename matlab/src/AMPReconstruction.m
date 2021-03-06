function sOut = AMPReconstruction(y,A,Aind,numOfVecs,varMat)

numOfChunks = size(A{end},2);
sOut = zeros(numOfChunks,numOfVecs);


varVec = reshape(varMat',[1 numOfVecs]);


for iVec = 1 : numOfVecs
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};
    sparseRat = size(Atmp,1)/size(A{end},2);    
    
    inputEst0 = AwgnEstimIn(0, varVec(iVec));
    inputEst = SparseScaEstim( inputEst0, sparseRat );
    opt = AmpOpt();
    opt.tol = 1e-4;
    opt.nit = 1000;
    optA.rvarMethod = 'wvar'; optA.wvar = varVec(iVec);
    [estFin] = ampEst(inputEst, yVec, Atmp, opt);
    
    sOut(:,iVec) = estFin.xhat;
    
end

