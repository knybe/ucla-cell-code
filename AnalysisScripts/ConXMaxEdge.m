clear xs; clear ys;

consNum = 8;
maxEdgeAngle = pi; % degrees, in rads, from theta=0 aligning with north, of max edge
avgRun = 2;
pData = cellPerimsData;
usePercent = true;
fps = 1000;

% UNCOMMENT BELOW FOR SINGLE CELL RUN
% llane = 11; celll = 1;
% maxExt = zeros(2, 7);
% maxExtIt = 1;
%
frameCount = length(pData{llane}{celll});
[delta, thetaIdx] = min(abs(pData{llane}{celll}{1}(:,1)-maxEdgeAngle));
base = pData{llane}{celll}{1}(thetaIdx, 2);

for currCon = 2:8
    conStart = find(cData{llane}{celll}(:, 9) == currCon, 1, 'first');
    conEnd = find(cData{llane}{celll}(:, 9) == currCon, 1, 'last');
    
    edgeDists = [];
    avg = [];
    for j = conStart:conEnd
        jIdx = j-conStart+1;
        edgeDists(jIdx) = pData{llane}{celll}{j}(thetaIdx, 2);
        avg(jIdx) = edgeDists(jIdx);
%         if (jIdx > avgRun)
%             avg(jIdx) = avg(jIdx-1) - avg(jIdx-avgRun)/avgRun + avg(jIdx)/avgRun;
%         end
        if usePercent == true
            edgeDists(jIdx) = (avg(jIdx)-base)/base*100;
        end
    end
    
    maxEdge = max(edgeDists);
    maxExt(maxExtIt, currCon-1) = maxEdge;
end

figure; boxplot(maxExt)

1+1;