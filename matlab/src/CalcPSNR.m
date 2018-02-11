ref = imread('boy.png');

mcsVec = [1:5];
SNRVec = [0:2:30];

psnrVec = zeros(length(mcsVec),length(SNRVec));

for iMcs = 1 : length(mcsVec)
    for iSNR = 1 : length(SNRVec)
        
        vht = wlanVHTConfig;
        vht.NumTransmitAntennas = 1;
        vht.NumSpaceTimeStreams = 1;
        vht.STBC = false;
        vht.MCS = mcsVec(iMcs);
        vht.APEPLength = length(ref(:)); %1024;
        
        binData = dec2bin(ref(:),8);
        txImage = reshape((binData-'0').',1,[]).';
        txWaveform = wlanWaveformGenerator(txImage,vht);
        
        % Parameterize the channel
        tgacChannel = wlanTGacChannel;
        tgacChannel.DelayProfile = 'Model-D';
        tgacChannel.NumTransmitAntennas = vht.NumTransmitAntennas;
        tgacChannel.NumReceiveAntennas = 1;
        tgacChannel.LargeScaleFadingEffect = 'None';
        tgacChannel.ChannelBandwidth = vht.ChannelBandwidth;%'CBW20';
        tgacChannel.TransmitReceiveDistance = 5;
        tgacChannel.SampleRate = wlanSampleRate(vht); %Rs;
        tgacChannel.RandomStream = 'mt19937ar with seed';
        tgacChannel.Seed = 10;
        
        % Pass signal through the channel. Append zeroes to compensate for channel
        % filter delay
        txWaveform = [txWaveform;zeros(10,1)];
        chanOut = tgacChannel(txWaveform);
        
        snr = SNRVec(iSNR); % In dBs
        rxWaveform = awgn(chanOut,snr,0);
        
        
        rxPSDU = WLAN_RX(vht,rxWaveform);
        numErr = biterr(txImage,rxPSDU(1:length(txImage)));
        rxData = rxPSDU;
        str = reshape(sprintf('%d',rxData(1:length(txImage))),8,[]).';
        decdata = uint8(bin2dec(str));
        receivedImage = reshape(decdata,size(ref));
        psnrVal = psnr(receivedImage,ref);
%         if psnrVal == inf
%             psnrVec(iMcs,iSNR) = max(psnrVec(iMcs,:));
%         else
%             psnrVec(iMcs,iSNR) = psnrVal;
%         end
    psnrVec(iMcs,iSNR) = psnrVal;
    end
end

figure;
plot(SNRVec,psnrVec,'-x')
legend('MCS:1','MCS:2','MCS:3','MCS:4','MCS:5');
xlabel('SNR'); ylabel('PSNR');
grid on;