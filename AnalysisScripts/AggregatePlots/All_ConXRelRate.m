varsC = {cellData0uMMock, dropDataSilicone10cSt, cellData0uMLama, dropDataSilicone100kcSt};
varsP = {cellPerimsData0uMMock, dropPerimsDataSilicone10cSt, cellPerimsData0uMLama, dropPerimsDataSilicone100kcSt};
titles = {'0uM Blebbistatin Mock', '10 cSt Silicone Droplets', '0uM Blebbistatin LamA OE', '100k cSt Silicone Droplets'};
frameRates = {1000, 500, 1000, 500};
figure;
title('hI');
for nn = 1:length(varsC)
    cData = varsC{nn};
    pData = varsP{nn};

    idx = 1;
    xs = [];
    ys = [];
    relRates = zeros(1, 7);
    relRateIt = 1;
    fps = frameRates{nn};

    for laneNum = 1:16
        numCells = length(cData{laneNum});
        for cellNum = 1:numCells
            llane = laneNum; celll = cellNum;

            ConXRelRate
            relRateIt = relRateIt+1;
            %i = 1;
        end
    end
    subplot(2,2,nn);
    boxplot(relRates);
    title(titles{nn});
    xlabel('Constriction #');
    ylabel('Trailing Edge Relaxation Rate (%)');
    ylim([0, 5]);
    xlim([0,7]);
end

hold off;
1+1