
codegen 'runUSRPRx'

runUSRPRx_mex

%runUSRPRx

% function RxWrapper
% 
% 
% 
% CyclicPrefixLength = 16;
% FFTLength = 64;
% numOFDMSym = 80;
% PilotCarrierIndices = [12;26;40;54];
% hDataDeMod = comm.OFDMDemodulator(...
%     'CyclicPrefixLength',   CyclicPrefixLength,...
%     'FFTLength' ,           FFTLength,...
%     'NumGuardBandCarriers', [6; 5],...
%     'NumSymbols',           numOFDMSym,...    
%     'PilotOutputPort',       true,...
%     'PilotCarrierIndices',  PilotCarrierIndices,...    
%     'RemoveDCCarrier',      true);
% 
% sig = randn(numOFDMSym*numOFDMSym,1) + 1i*randn(numOFDMSym*numOFDMSym,1);
% 
% 
% deSig = hDataDeMod(sig);
% 
% disp(deSig)
% 
% end