function sOut = SubspacePursuitReconstruction(y,A,Aind,numOfVecs)

sOut = zeros(size(A{end},2),numOfVecs);
for iVec = 1 : numOfVecs
    
    
        
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};
    sparsity = size(Atmp,1); %/size(A{end},2);   
    
    
    Rec = CSRec_SP(sparsity,Atmp,yVec);
    
    
    
    
    sOut(:,iVec) = Rec.x_hat;
    
end

