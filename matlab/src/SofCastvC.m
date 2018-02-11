clear all
picture = imread('image.jpg');
picture = im2double(rgb2gray(picture));
%picture = dct2(im2double(picture));
[row column] = size(picture);  
c=75;d=75;   % reshape it into 75*75 matrices
l=0;
for i=1:c:row-(c-1)
for j=1:d:column-(d-1)
C=picture((i:i+(c-1)),(j:j+(d-1)));
eval(['block_' num2str(l+1) '=C'])
l=l+1;
end
end
whole = cat(3,block_1,block_2,block_3,block_4,block_5,block_6,block_7,block_8,block_9);
for t=1:9
   dctwhole(:,:,t) = dct2(whole(:,:,t)); 
end
%%%%apply threshold for near zero dct components%%%%
thres = 0.1;
dctwhole(abs(dctwhole) < thres)=0;
nnz(dctwhole)
%%%%find means and variances
for ii=1:c
    for jj=1:d
         meancomponents(ii,jj) = mean(dctwhole(ii,jj,:));
         variancecomponents(ii,jj) = var(dctwhole(ii,jj,:));    
    end
end
%!!!!!!!!!!!means are already sent as metadata!!!!!!!!!!!!%
%%%%Power Allocation wrt variances
P=1;
% mean(variancecomponents);
for ii = 1 : c
    for jj = 1 : d
            gEnc(ii,jj) = (variancecomponents(ii,jj)^(-1/4))*sqrt(P/sum(sqrt(variancecomponents(:))));
            if variancecomponents(ii,jj)==0;
                gEnc(ii,jj)=0;
            end
    end
end
%%%%%send data with scaling
scaleddctwhole=dctwhole.*gEnc;
%%%%%channel%%%%%%%
phi=scaleddctwhole.*randn(75);
%dctwholereceived = awgn(scaleddctwhole,1)
 
%%%%inverse dct%%%%%%%
        for t=1:9
           idctwhole(:,:,t) = idct2(dctwhole(:,:,t)); 
        end
%%%recovery%%%%%
R1 = horzcat(idctwhole(:,:,1),idctwhole(:,:,2),idctwhole(:,:,3));
R2 = horzcat(idctwhole(:,:,4),idctwhole(:,:,5),idctwhole(:,:,6));
R3 = horzcat(idctwhole(:,:,7),idctwhole(:,:,8),idctwhole(:,:,9));
captured = vertcat(R1,R2,R3);
imshow(picture);figure;
imshow(captured);
