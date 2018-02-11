%use SoftCasts with multiple parallel channels


%read video 

numOfFrames = 15; %for GOP
numOfComp = 3;
chunkSize = [10 10];
thresh = 0.0001;
P = 1; %power



v = VideoReader('vid1.mp4');
v.CurrentTime = 2; %read video from 2 seconds
vidFrames = zeros(v.Height,v.Width,3,numOfFrames);
for iFrame = 1 : numOfFrames
    frm = readFrame(v);
    vidFrames(:,:,:,iFrame) = im2double(frm);
    %image(vidFrames(:,:,:,iFrame), 'Parent', currAxes);
    %pause(1/v.FrameRate);
end

vidFramesNorm = mean(vidFrames(:));
dctCoeff = mirt_dctn(vidFrames - vidFramesNorm);

%chunks 1st version 
[chunkMean, chunkVar ]= createChunksV1(dctCoeff,chunkSize);

%reject near zero chunks
rejectMatrix = abs(chunkMean) > thresh;
chunkVarVec = {};
for iFrame = 1 : numOfFrames
    for iComp = 1 : numOfComp
        
        filtChunk = chunkVar(:,:,iComp,iFrame);
        chunkVarVec{iFrame}{iComp} = filtChunk(rejectMatrix(:,:,iComp,iFrame) == 1);
    end
end

%encoder
y = SoftCastEncoder(dctCoeff,P,rejectMatrix,chunkVarVec);
snr = 80;
%one stream
for iFrame = 1 : numOfFrames
    for iComp = 1 : numOfComp
                
        y_n{iFrame}{iComp} = awgn(y{iFrame}{iComp},snr);
    end
end


%metadata sent over reliable channel 
metadata.picSize = [v.Height v.Width];
metadata.matrix = rejectMatrix;
metadata.frameMean =vidFramesNorm;
metadata.lambda = chunkVarVec;

var = 10^(-snr/10);
estX  = SoftCastDecoder(y_n,P,metadata.matrix,metadata.lambda,metadata.picSize,var);


vidRetr = mirt_idctn(estX) + metadata.frameMean;

figure;
currAxes = axes;
for iFrame = 1 : numOfFrames   
    image(vidRetr(:,:,:,iFrame), 'Parent', currAxes);
    pause(1/v.FrameRate);
end

psnr(vidRetr,vidFrames)