function generateRandMatrix(numOfChunks)

%generate Random matrix, known for tx and rx
A  = {};
edges = round([1 numOfChunks*0.2 numOfChunks*0.5 numOfChunks*0.7 numOfChunks]);
% 20%
A{1} = (1/sqrt(edges(2)))*randn(edges(2),numOfChunks);
% 50%
A{2} = (1/sqrt(edges(3)))*randn(edges(3),numOfChunks);
% 70%
A{3} = (1/sqrt(edges(4)))*randn(edges(4),numOfChunks);
% 100%
A{4} = (1/sqrt(edges(5)))*randn(edges(5),numOfChunks);

save('src/Metadata/matrix','A');
save('src/Metadata/edges','edges');

end


