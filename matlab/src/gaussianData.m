chunkSize = 1000;
numOfVecs = 1; 

dctVecNorm = randn(chunkSize,numOfVecs);


A{1} = randn(700,chunkSize); %(1/sqrt(chunkSize))*
%SNRvec = [0:50];
SNRvec = 1000;
eMMSE = zeros(length(SNRvec),1);
eAMP = zeros(length(SNRvec),1);
%eAMP2 = zeros(length(SNRvec),1);
%eAMP3 = zeros(length(SNRvec),1);

for iSNR = 1 : length(SNRvec)

e1 = zeros(numOfVecs,1);
e2 = zeros(numOfVecs,1);
%e3 = zeros(numOfVecs,1);
%e4 = zeros(numOfVecs,1);
sparsity = zeros(numOfVecs,1);
noiseVar = 10^(-SNRvec(iSNR)/10);
for i = 1 : numOfVecs    
    sparsityIndex = randperm(chunkSize,400);    
    index = i;
    dctVecSpar = dctVecNorm(:,index);
    dctVecSpar(sparsityIndex) = 0;
    compSenVec{index} = A{1}*dctVecSpar;
    
    gb_mean = 0;
    gb_var = 1; %var(nonzeros(dctVecSpar)); %varMat(index);
    numOfNonZero(index) = nnz(dctVecSpar);
    sparsity(i) = numOfNonZero(index)/length(dctVecSpar);
    compSenVecN{1} = compSenVec{index} + sqrt(noiseVar)*randn(size(compSenVec{index}));
    
    
    [a_gb,c_gb,history_gb] = ample(A{1},compSenVecN{1} ,@prior_gb,'prior_params',[gb_mean gb_var sparsity(i)],...
        'convergence_tolerance',1e-10,...
        'max_iterations',200,...
        'debug',0,...
        'learn_prior_params',0,...
        'learn_delta',0, ...
        'delta',1, ...
        'damp',10.00, ...
        'prior_damp',0.00,...
        'true_solution',  dctVecSpar,...
        'learning_mode', 'track',...
        'verbose_mode',0);
    
    
    %AMPv1 = AMPReconstruction2(compSenVecN,A,1,1);
    %AMPv2 = AMPReconstruction(compSenVecN,A,1,1,noiseVar);
    
    sparsityPattern = find(dctVecSpar == 0 );
    %[~,idxMin] = sort(abs(a_gb));
    %sparsityPattern = idxMin(1:chunkSize-numOfNonZero(index));
    estX = MMSEReconstruction(compSenVecN,A,1,1,noiseVar,sparsityPattern);
    %estX = MMSEReconstruction(compSenVecN,A,1,1,noiseVar);
    
    
    %[a_gb estX dctVecSpar];
    mean((a_gb - dctVecSpar).^2)
    mean((estX - dctVecSpar).^2)
    e1(i) = mean((a_gb - dctVecSpar).^2);
    e2(i) = mean((estX - dctVecSpar).^2);
    %e3(i) = mean((AMPv1 - dctVecSpar).^2);
    %e4(i) = mean((AMPv2 - dctVecSpar).^2);
end
eMMSE(iSNR) = mean(e1);
eAMP(iSNR) = mean(e2);
%eAMP2(iSNR) = mean(e3);
%eAMP3(iSNR) = mean(e4);

end

figure;
plot(1:numOfVecs,log(e1),1:numOfVecs,log(e2));
%plot(SNRvec,log(eMMSE),SNRvec,log(eAMP),SNRvec,log(eAMP2),SNRvec,log(eAMP3));
legend('AMP','MMSE');

figure;
plot(SNRvec,log(eMMSE),SNRvec,log(eAMP));
legend('AMP','MMSE');
xlabel('SNR (dB)');
ylabel('MSE (dB)');
grid on;