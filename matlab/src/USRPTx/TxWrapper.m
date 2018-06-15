function TxWrapper(payloadMessage)

%configure parameters
useCodegen = 1;

bw = 20e6; %20MHz

%[STF1, LTF] = generatePreamble();
STF = std(payloadMessage)*wlanLSTF( wlanNonHTConfig('ChannelBandwidth','CBW20'));
LTF = std(payloadMessage)*wlanLLTF( wlanNonHTConfig('ChannelBandwidth','CBW20'));

%interpolate
rateConverter = dsp.FIRRateConverter('InterpolationFactor', 5,...
    'DecimationFactor', 4);

txSig =[STF; LTF; payloadMessage];
%txSigInt = rateConverter(txSig);
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


