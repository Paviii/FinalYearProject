function TxWrapper(txSig,compileIt)

%configure parameters
%compileIt = 0;
useCodegen = 1;

%txSigInt = vertcat(txSig{:});
txSigInt = txSig;
%indVec = zeros(length(txSig),1);
%for iFrame = 1 : length(txSig)
% indVec(iFrame) = length(txSig{iFrame}) + sum(indVec);
%end
%indVec = [0; indVec];

if compileIt
    codegen USRPTransmit -args {txSigInt}
end

while 1
% iFrame = 1;
% ack = 0;
% fileID = fopen('src/Metadata/ack.bin','w+'); 
% fwrite(fileID,ack,'uint');

    
%     txSigInt = txSig{iFrame};
    
    if useCodegen
        USRPTransmit_mex(txSigInt)
    else
        USRPTransmit(txSigInt)
    end
    disp('packet done');
    pause(1);
    
%     ack = fread(fileID,1,'uint');
%     if ack
%         iFrame = iFrame + 1;
%         ack = 0;
%         fwrite(fileID,ack,'uint');
%     end
    
end


