function Sest = cosamp(Phi,u,K,tol,maxiterations)

% Cosamp algorithm
%   Input
%       K : sparsity of Sest
%       Phi : measurement matrix
%       u: measured vector
%       tol : tolerance for approximation between successive solutions. 
%   Output
%       Sest: Solution found by the algorithm


% Initialization
Sest = zeros(size(Phi,2),1);
v = u;
t = 1; 
numericalprecision = 1e-12;
T = [];
while (t <= maxiterations) && (norm(v)/norm(u) > tol)
  y = abs(Phi'*v);
  [vals,z] = sort(y,'descend');
  Omega = find(y >= vals(2*K) & y > numericalprecision);
  T = union(Omega,T);
  b = pinv(Phi(:,T))*u;
  [vals,z] = sort(abs(b),'descend');
  Kgoodindices = (abs(b) >= vals(K) & abs(b) > numericalprecision);
  T = T(Kgoodindices);
  Sest = zeros(size(Phi,2),1);
  b = b(Kgoodindices);
  Sest(T) = b;
  v = u - Phi(:,T)*b;
  t = t+1;
end