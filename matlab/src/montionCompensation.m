function [refFrames,motionVects] =  montionCompensation(vid)


%motion compensation parameters
mbSize = 25;
p = 15;
numOfCompFrames = 5;

%convert video to grayscale
videoLength = size(vid,4);
dim1 = floor(size(vid,1)/mbSize)*mbSize;
dim2 = floor(size(vid,2)/mbSize)*mbSize;
videoGrayScale = zeros(dim1,dim2, videoLength);

for iFrame = 1 : videoLength    
    videoGrayScale(:,:,iFrame) = im2double(rgb2gray(vid(1:dim1,1:dim2,:,iFrame)));    
end



numOfRefFrames = floor(videoLength/numOfCompFrames);
refFrames = cell(numOfRefFrames,1);
motionVects = cell(videoLength - numOfRefFrames,1);

for iBlock = 1 : numOfRefFrames
    
    refFrames{iBlock} = videoGrayScale(:,:,(iBlock-1)*numOfCompFrames+1);
    
    for iFrame = 1 : min((numOfCompFrames-1),videoLength - (iBlock-1)*numOfCompFrames+1)
        
        imgP = videoGrayScale(:,:,(iBlock-1)*numOfCompFrames+iFrame + 1);
        imgI = videoGrayScale(:,:,(iBlock-1)*numOfCompFrames+iFrame);
        [motionVect, computations] = motionEstARPS(imgP,imgI,mbSize,p);
        motionVects{(iBlock-1)*(numOfCompFrames-1)+iFrame} = motionVect;
        
    end
    
end


end