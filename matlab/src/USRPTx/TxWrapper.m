function TxWrapper(txSig)

%configure parameters
useCodegen = 1;

txSigInt = txSig;

if useCodegen
    codegen USRPTransmit -args {txSigInt}
end


while 1
    
    if useCodegen
        USRPTransmit_mex(txSigInt)
    else
        USRPTransmit(txSigInt)
    end    
    disp('packet done');
    pause(1);
    
end


