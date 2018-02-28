function sOut = basisPursuitReconstruction(y,A,Aind,numOfVecs)

sOut = zeros(size(A{end},2),numOfVecs);
for iVec = 1 : numOfVecs
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};
    %___l2 NORM SOLUTION___ s2 = Theta\y; %s2 = pinv(Theta)*y
    s2 = pinv(Atmp)*yVec;
    
    %___BP SOLUTION___
    s1 = l1eq_pd(s2,Atmp,Atmp',yVec,1e-4,100); % L1-magic toolbox
    
    
    sOut(:,iVec) = s1;
    
end

