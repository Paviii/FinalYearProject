function sOut = SubspacePursuitReconstruction(y,A,Aind,numOfVecs)

sOut = zeros(size(A{end},2),numOfVecs);
for iVec = 1 : numOfVecs
    
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};
    K = size(Atmp,1); %/size(A{end},2);   
    
    
    %1st version of the algorithm
    %Rec = CSRec_SP(K,Atmp,yVec);
    %sOut(:,iVec) = Rec.x_hat;
    
    %2second version of the algorithm
    [xfinal,That]=SP(K, Atmp, yVec,size(Atmp,2));
    sOut(:,iVec) = xfinal;
    
    
    
    
    
end

