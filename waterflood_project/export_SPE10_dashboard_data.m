
%% SPE10 Dashboard Data Export
% Exports existing MATLAB simulation results for Python.
% No reservoir simulation is performed.

clear; clc;

%% 1. Define folders

projectDir = pwd;
resultsDir = fullfile(projectDir, 'SPE10_results');
exportDir = fullfile(projectDir, 'dashboard_data');

if ~isfolder(exportDir)
    mkdir(exportDir);
end

file50 = fullfile(resultsDir, 'SPE10_case50_results.mat');
file100 = fullfile(resultsDir, 'SPE10_waterflood_results.mat');

assert(isfile(file50), '50 m3/day result file not found.');
assert(isfile(file100), '100 m3/day result file not found.');

%% 2. Export both simulation cases

exportCase(file50, 50, exportDir);
exportCase(file100, 100, exportDir);

fprintf('\nBoth simulation cases exported.\n');

%% 3. Export reservoir rock-property maps
% Both cases use the same SPE10 rock model.

D = load(file100, 'G', 'rock');

G = D.G;
rock = D.rock;

nx = G.cartDims(1);
ny = G.cartDims(2);
nz = G.cartDims(3);

poro3D = reshape(rock.poro, [nx, ny, nz]);

% Geometric average of horizontal permeability components
permH = sqrt(rock.perm(:,1).*rock.perm(:,2));
permH_mD = permH/(milli*darcy);

perm3D = reshape(permH_mD, [nx, ny, nz]);

poroMap = mean(poro3D, 3);
permMap = mean(perm3D, 3);

writematrix(poroMap', ...
    fullfile(exportDir,'reservoir_porosity.csv'));

writematrix(permMap', ...
    fullfile(exportDir,'reservoir_permeability_mD.csv'));

%% 4. Export grid information

gridInfo = table(nx, ny, nz, G.cells.num, ...
    'VariableNames', {'NX','NY','NZ','TotalCells'});

writetable(gridInfo, ...
    fullfile(exportDir,'grid_information.csv'));

%% 5. Export completed

fprintf('\n====================================\n');
fprintf('SPE10 DASHBOARD DATA EXPORT COMPLETE\n');
fprintf('====================================\n');

fprintf('Grid cells: %d\n', G.cells.num);
fprintf('Export directory:\n%s\n', exportDir);

%% LOCAL FUNCTION: Export one simulation case

function exportCase(matFile, injectionRate, exportDir)

    fprintf('\nExporting %d m3/day case...\n', injectionRate);

    D = load(matFile, ...
        'G','rock','wellSols','states','schedule','Swr');

    G = D.G;
    rock = D.rock;
    wellSols = D.wellSols;
    states = D.states;
    schedule = D.schedule;
    Swr = D.Swr;

    n = numel(wellSols);

    dt = schedule.step.val(:);

    assert(numel(dt) == n, ...
        'Schedule and well-solution counts do not match.');

    timeDays = cumsum(dt)/day;
    timeYears = timeDays/365.25;

    %% Production data

    oilRate = zeros(n,1);
    waterRate = zeros(n,1);
    injectorBHP = zeros(n,1);

    wellNames = {wellSols{1}.name};
    producerIdx = find(contains(wellNames,'Producer'));

    for t = 1:n

        injectorBHP(t) = wellSols{t}(1).bhp/barsa;

        for j = 1:numel(producerIdx)

            w = producerIdx(j);

            oilRate(t) = oilRate(t) + ...
                max(-wellSols{t}(w).qOs,0)*day;

            waterRate(t) = waterRate(t) + ...
                max(-wellSols{t}(w).qWs,0)*day;

        end
    end

    %% Water cut

    liquidRate = oilRate + waterRate;

    waterCut = zeros(n,1);

    valid = liquidRate > 0;
    waterCut(valid) = waterRate(valid)./liquidRate(valid);

    %% Cumulative production

    cumOil = cumsum(oilRate.*dt/day);
    cumWater = cumsum(waterRate.*dt/day);

    %% Approximate OOIP and recovery factor

    PV = sum(G.cells.volumes .* rock.poro);
    OOIP = PV*(1-Swr);

    recoveryFactor = cumOil/OOIP*100;

    %% Production history table

    productionTable = table( ...
        timeDays, timeYears, oilRate, waterRate, ...
        cumOil, cumWater, waterCut*100, ...
        recoveryFactor, injectorBHP, ...
        'VariableNames', { ...
        'Time_days','Time_years', ...
        'OilRate_m3day','WaterRate_m3day', ...
        'CumulativeOil_m3','CumulativeWater_m3', ...
        'WaterCut_percent','RecoveryFactor_percent', ...
        'InjectorBHP_bar'});

    csvName = sprintf('production_%dm3day.csv', ...
        injectionRate);

    writetable(productionTable, ...
        fullfile(exportDir,csvName));

    %% Individual producer data

    producerOil = zeros(n,numel(producerIdx));
    producerWater = zeros(n,numel(producerIdx));

    for t = 1:n
        for j = 1:numel(producerIdx)

            w = producerIdx(j);

            producerOil(t,j) = ...
                max(-wellSols{t}(w).qOs,0)*day;

            producerWater(t,j) = ...
                max(-wellSols{t}(w).qWs,0)*day;

        end
    end

    producerTable = table(timeYears, ...
        producerOil(:,1), producerOil(:,2), ...
        producerOil(:,3), producerOil(:,4), ...
        producerWater(:,1), producerWater(:,2), ...
        producerWater(:,3), producerWater(:,4), ...
        'VariableNames', { ...
        'Time_years', ...
        'Producer1_Oil','Producer2_Oil', ...
        'Producer3_Oil','Producer4_Oil', ...
        'Producer1_Water','Producer2_Water', ...
        'Producer3_Water','Producer4_Water'});

    writetable(producerTable, ...
        fullfile(exportDir, ...
        sprintf('individual_producers_%dm3day.csv',injectionRate)));

    %% Water saturation snapshots

    targetYears = [1,3,5];

    nx = G.cartDims(1);
    ny = G.cartDims(2);
    nz = G.cartDims(3);

    for k = 1:numel(targetYears)

        [~,idx] = min(abs(timeYears-targetYears(k)));

        sw3D = reshape(states{idx}.s(:,1), ...
            [nx,ny,nz]);

        swMap = mean(sw3D,3);

        snapshotName = sprintf( ...
            'water_saturation_%dm3day_year%d.csv', ...
            injectionRate,targetYears(k));

        writematrix(swMap', ...
            fullfile(exportDir,snapshotName));

    end

    %% Summary

    fprintf('%d m3/day case:\n',injectionRate);
    fprintf('Cumulative oil: %.2f m3\n',cumOil(end));
    fprintf('Cumulative water: %.2f m3\n',cumWater(end));
    fprintf('Final recovery factor: %.3f %%\n', ...
        recoveryFactor(end));
    fprintf('Maximum injector BHP: %.2f bar\n', ...
        max(injectorBHP));

end
