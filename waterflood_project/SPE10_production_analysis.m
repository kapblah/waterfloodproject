
%% SPE10 Production Performance Analysis
% Uses the existing SPE10 waterflood simulation results.
% Production rates are converted from m3/s to m3/day.

clearvars -except G rock W schedule wellSols states fluid Swr Sor

%% 1. Check required simulation data

requiredVars = {'G','rock','schedule','wellSols','Swr','Sor'};

for k = 1:numel(requiredVars)
    assert(exist(requiredVars{k},'var') == 1, ...
        'Missing variable: %s. Load simulation results first.', ...
        requiredVars{k});
end

nWells = numel(wellSols{1});
nRecords = numel(wellSols);

% Extract timestep durations
dt = schedule.step.val(:);

assert(numel(dt) == nRecords, ...
    'Well-solution records and schedule timesteps do not match.');

timeDays = cumsum(dt)/day;

%% 2. Identify producer wells

wellNames = {wellSols{1}.name};
producerIdx = find(contains(wellNames,'Producer'));

assert(~isempty(producerIdx), 'No producer wells found.');

nProd = numel(producerIdx);

oilRate = zeros(nRecords,nProd);
waterRate = zeros(nRecords,nProd);
bhp = zeros(nRecords,nProd);

%% 3. Extract production rates

for t = 1:nRecords
    for j = 1:nProd
        w = producerIdx(j);

        % Negative rates indicate production in this model.
        oilRate(t,j) = max(-wellSols{t}(w).qOs,0)*day;
        waterRate(t,j) = max(-wellSols{t}(w).qWs,0)*day;

        bhp(t,j) = wellSols{t}(w).bhp/barsa;
    end
end

totalOilRate = sum(oilRate,2);
totalWaterRate = sum(waterRate,2);

%% 4. Calculate water cut

totalLiquidRate = totalOilRate + totalWaterRate;

waterCut = zeros(nRecords,1);
valid = totalLiquidRate > 0;

waterCut(valid) = totalWaterRate(valid)./totalLiquidRate(valid);

%% 5. Calculate cumulative production

% Rate values are treated as representative of each timestep.
% Cumulative volumes use the actual timestep durations.

cumOil = cumsum(totalOilRate .* dt/day);
cumWater = cumsum(totalWaterRate .* dt/day);

%% 6. Calculate approximate OOIP and recovery factor

% Assumes Bo = 1 and uses adjusted porosity values.
% This is an approximate stock-tank OOIP estimate.

PV = sum(G.cells.volumes .* rock.poro);
OOIP = PV*(1-Swr);

recoveryFactor = (cumOil/OOIP)*100;

%% 7. Display production summary

fprintf('\n========== SPE10 PRODUCTION SUMMARY ==========\n');

fprintf('Total simulation time: %.2f years\n', ...
    timeDays(end)/365.25);

fprintf('Approximate OOIP: %.2f m3\n', OOIP);

fprintf('Cumulative oil: %.2f m3\n', cumOil(end));

fprintf('Cumulative water: %.2f m3\n', cumWater(end));

fprintf('Final recovery factor: %.3f %%\n', ...
    recoveryFactor(end));

fprintf('Final water cut: %.2f %%\n', ...
    waterCut(end)*100);

fprintf('Final oil rate: %.2f m3/day\n', ...
    totalOilRate(end));

fprintf('Final water rate: %.2f m3/day\n', ...
    totalWaterRate(end));

%% 8. Plot oil production rate

figure('Name','Oil Production Rate');
plot(timeDays/365.25,totalOilRate,'LineWidth',1.5);
xlabel('Time (years)');
ylabel('Oil rate (m3/day)');
title('Total Oil Production Rate');
grid on;

%% 9. Plot cumulative oil production

figure('Name','Cumulative Oil Production');
plot(timeDays/365.25,cumOil,'LineWidth',1.5);
xlabel('Time (years)');
ylabel('Cumulative oil (m3)');
title('Cumulative Oil Production');
grid on;

%% 10. Plot water production rate

figure('Name','Water Production Rate');
plot(timeDays/365.25,totalWaterRate,'LineWidth',1.5);
xlabel('Time (years)');
ylabel('Water rate (m3/day)');
title('Total Water Production Rate');
grid on;

%% 11. Plot water cut

figure('Name','Water Cut');
plot(timeDays/365.25,waterCut*100,'LineWidth',1.5);
xlabel('Time (years)');
ylabel('Water cut (%)');
title('Field Water Cut');
ylim([0 100]);
grid on;

%% 12. Plot recovery factor

figure('Name','Recovery Factor');
plot(timeDays/365.25,recoveryFactor,'LineWidth',1.5);
xlabel('Time (years)');
ylabel('Recovery factor (%)');
title('Recovery Factor vs Time');
grid on;

%% 13. Plot individual producer water cuts

figure('Name','Producer Water Cuts');

hold on;

for j = 1:nProd
    liquid = oilRate(:,j) + waterRate(:,j);
    wc = zeros(nRecords,1);

    valid = liquid > 0;
    wc(valid) = waterRate(valid,j)./liquid(valid);

    plot(timeDays/365.25,wc*100,'LineWidth',1.3);
end

xlabel('Time (years)');
ylabel('Water cut (%)');
title('Water Cut by Producer');
legend(wellNames(producerIdx),'Location','best');
ylim([0 100]);
grid on;
hold off;

%% 14. Export production history

productionTable = table( ...
    timeDays, totalOilRate, totalWaterRate, ...
    cumOil, cumWater, waterCut*100, recoveryFactor, ...
    'VariableNames', { ...
    'Time_days','OilRate_m3day','WaterRate_m3day', ...
    'CumulativeOil_m3','CumulativeWater_m3', ...
    'WaterCut_percent','RecoveryFactor_percent'});

resultsDir = fullfile(pwd,'SPE10_results');

if ~isfolder(resultsDir)
    mkdir(resultsDir);
end

writetable(productionTable, ...
    fullfile(resultsDir,'SPE10_production_history.csv'));

fprintf('\nProduction history exported successfully.\n');
fprintf('Results folder: %s\n',resultsDir);
