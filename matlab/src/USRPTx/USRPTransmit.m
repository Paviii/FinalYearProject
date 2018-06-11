function USRPTransmit( txOrg)
% Setup transmitter
% hSDRu = comm.SDRuTransmitter( ...
%     'Platform' , 'N200/N210/USRP2', ... 'Platform', 'B200', ...
%     'IPAddress','192.168.0.4', ...'SerialNum', '30A3E93', ...
%     'CenterFrequency',      2.3e9, ...
%     'InterpolationFactor',  4,... interpolate to match 100MHz
%     'Gain',                 30,...
%     'MasterClockRate',      100e6);

hSDRu = comm.SDRuTransmitter( ...
    'Platform', 'B200', ...
    'SerialNum', '30A3E9F', ...
    'CenterFrequency',      2.3e9, ...
    'InterpolationFactor',  1,...
    'Gain',                 70,...
    'MasterClockRate',      20e6);



% Run transmitter
%disp('Transmitting... pew! pew!');
for i = 1 :1000
    u = step(hSDRu, txOrg);   
end
release(hSDRu);

end

% iStart = 1;
% for iPacket = 1:length(numOfSymVec)
%     % Send data to USRP
%     txPacket = txOrg(iStart:iStart+numOfSymVec(iPacket)-1);
%     step(hSDRu, txPacket);
%     iStart = iStart +  numOfSymVec(iPacket);
%     release(hSDRu);
% end
