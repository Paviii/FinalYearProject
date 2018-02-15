function sOut = basisPursuitReconstruction(y,A,Aind,numOfVecs)

sOut = zeros(size(A{end},2),numOfVecs);
for iVec = 1 : numOfVecs
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};
    %___l2 NORM SOLUTION___ s2 = Theta\y; %s2 = pinv(Theta)*y
    s2 = pinv(Atmp)*yVec;
    
    %___BP SOLUTION___
    s1 = l1eq_pd(s2,Atmp,Atmp',yVec,5e-3,length(yVec)); % L1-magic toolbox
    %x = l1eq_pd(y,A,A',b,5e-3,32);
    
    sOut(:,iVec) = s1;
    
end

