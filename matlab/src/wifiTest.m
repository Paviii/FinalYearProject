%image
picture = imread('test_data/boy.png');
pictureGrayScale = rgb2gray(picture);
binRep = dec2bin(pictureGrayScale(:));

txPSDU = str2num(binRep(:));

mcs = 1;
snr = 5;
numPSDU = ceil(length(txPSDU)/32816);
rxData = [];

switch(mcs)
    case 0
        PSDUlength = 32784;
    case 1
        PSDUlength = 32784;        
    case 8
        PSDUlength = 33048;        
end
         
for iNumPSDU = 1 : numPSDU    
    if iNumPSDU == numPSDU
        txPSDUPacket = txPSDU((iNumPSDU-1)*PSDUlength+1:end);
        %append zeros
        txPSDUPacket = [txPSDUPacket; zeros(iNumPSDU*PSDUlength-length(txPSDU),1)];
    else
        txPSDUPacket = txPSDU((iNumPSDU-1)*PSDUlength+1:iNumPSDU*PSDUlength);
    end
    
    
    [numErr, rxDataPacket] = WLANTxRx(mcs,txPSDUPacket,snr);
    rxData = [rxData; rxDataPacket];
end

rxDataBin = reshape(rxData(1:length(txPSDU)),[numel(pictureGrayScale) 8]);
rxImgVec = bi2de(rxDataBin,'left-msb');
rxImg = reshape(rxImgVec,size(pictureGrayScale));
psnr(uint8(rxImg),pictureGrayScale)
