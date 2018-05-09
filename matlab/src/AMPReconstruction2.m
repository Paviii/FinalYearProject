function sOut = AMPReconstruction2(y,A,Aind,numOfVecs)
%another version of AMP algorithm

numOfChunks = size(A{end},2);
sOut = zeros(numOfChunks,numOfVecs);


%set tolerance 
tol = 0.00001;
% Number of iterations
T = 1000;


for iVec = 1 : numOfVecs
    
    yVec = y{iVec};
    Atmp = A{Aind(iVec)};  
    
    xamp = reconstructAmp(Atmp, yVec, T, tol);
    sOut(:,iVec) = xamp;
    
end

