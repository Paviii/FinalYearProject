function [sparsityPattern, estX] =  gbAMP(y,g,A,Aind,sigVar,sparsity,numOfVecs,noisVar)

numOfChunks = size(A{end},2);
estX = zeros(numOfChunks,numOfVecs);
sparsityPattern = cell(numOfVecs,1);
for iVec = 1 : numOfVecs
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};    
       
    gAtmp = g(iVec)*Atmp;
    
    
    [a_gb,c_gb,history_gb] = ample(gAtmp,yVec ,@prior_gb,'prior_params',[0 sigVar(iVec) sparsity(iVec)],...
        'convergence_tolerance',1e-10,...
        'max_iterations',200,...
        'debug',0,...
        'learn_prior_params',0,...
        'learn_delta',0, ... 
        'delta',noisVar, ... 
        'damp',0.00, ...
        'prior_damp',0.00,...
        'verbose_mode',0);
    
    estX(:,iVec) = a_gb;    
    
    [~,idxMin] = sort(abs(a_gb));
    numOfZeros = uint32((1 - sparsity(iVec))*numOfChunks);
    sparsityPattern{iVec} = idxMin(1:numOfZeros);
    
    
    
end



end