%% Recreate Python dashboard figures in MATLAB
% Reads the CSV files already exported by the MRST project.
% No reservoir simulation is run by this script.

clear; clc; close all;

%% 1. Locate exported CSV files
projectDir = 'C:\Users\Cyborg\research\waterflood_project';
dataDir = fullfile(projectDir, 'dashboard_data');

if ~isfolder(dataDir)
    error('Could not find dashboard_data folder: %s', dataDir);
end

% Read production histories
P50  = readtable(fullfile(dataDir, 'production_50m3day.csv'), ...
    'VariableNamingRule', 'preserve');
P100 = readtable(fullfile(dataDir, 'production_100m3day.csv'), ...
    'VariableNamingRule', 'preserve');

% Read individual producer histories
W50  = readtable(fullfile(dataDir, 'individual_producers_50m3day.csv'), ...
    'VariableNamingRule', 'preserve');
W100 = readtable(fullfile(dataDir, 'individual_producers_100m3day.csv'), ...
    'VariableNamingRule', 'preserve');

% Read reservoir property maps
poroMap = readmatrix(fullfile(dataDir, 'reservoir_porosity.csv'));
permMap = readmatrix(fullfile(dataDir, 'reservoir_permeability_mD.csv'));

%% 2. Standardise map orientation
% Dashboard maps are expected to have Y rows and X columns.
% SPE10 subset dimensions are NX=60 and NY=220.
NX = 60;
NY = 220;

poroMap = orientMap(poroMap, NY, NX);
permMap = orientMap(permMap, NY, NX);

%% 3. Production rates and injector BHP — selected cases
figure('Name', 'Production Rates - 50 and 100 m3/day', ...
    'Color', 'w');
tiledlayout(2,2, 'TileSpacing','compact');

nexttile;
plot(P50.Time_years, P50.OilRate_m3day, 'LineWidth', 1.8); hold on;
plot(P50.Time_years, P50.WaterRate_m3day, 'LineWidth', 1.8);
title('Production Rates - 50 m^3/day');
xlabel('Time (years)'); ylabel('Rate (m^3/day)');
legend('Oil rate','Water rate','Location','best'); grid on;

nexttile;
plot(P100.Time_years, P100.OilRate_m3day, 'LineWidth', 1.8); hold on;
plot(P100.Time_years, P100.WaterRate_m3day, 'LineWidth', 1.8);
title('Production Rates - 100 m^3/day');
xlabel('Time (years)'); ylabel('Rate (m^3/day)');
legend('Oil rate','Water rate','Location','best'); grid on;

nexttile;
plot(P50.Time_years, P50.InjectorBHP_bar, 'LineWidth', 1.8);
title('Injector BHP - 50 m^3/day');
xlabel('Time (years)'); ylabel('BHP (bar)'); grid on;

nexttile;
plot(P100.Time_years, P100.InjectorBHP_bar, 'LineWidth', 1.8);
title('Injector BHP - 100 m^3/day');
xlabel('Time (years)'); ylabel('BHP (bar)'); grid on;

%% 4. Cumulative production and field water cut
figure('Name', 'Cumulative Production and Water Cut', 'Color', 'w');
tiledlayout(2,2, 'TileSpacing','compact');

nexttile;
plot(P50.Time_years, P50.CumulativeOil_m3, 'LineWidth', 1.8); hold on;
plot(P100.Time_years, P100.CumulativeOil_m3, 'LineWidth', 1.8);
title('Cumulative Oil Production');
xlabel('Time (years)'); ylabel('Oil (m^3)');
legend('50 m^3/day','100 m^3/day','Location','best'); grid on;

nexttile;
plot(P50.Time_years, P50.CumulativeWater_m3, 'LineWidth', 1.8); hold on;
plot(P100.Time_years, P100.CumulativeWater_m3, 'LineWidth', 1.8);
title('Cumulative Water Production');
xlabel('Time (years)'); ylabel('Water (m^3)');
legend('50 m^3/day','100 m^3/day','Location','best'); grid on;

nexttile;
plot(P50.Time_years, P50.WaterCut_percent, 'LineWidth', 1.8);
title('Field Water Cut - 50 m^3/day');
xlabel('Time (years)'); ylabel('Water cut (%)');
ylim([0 100]); grid on;

nexttile;
plot(P100.Time_years, P100.WaterCut_percent, 'LineWidth', 1.8);
title('Field Water Cut - 100 m^3/day');
xlabel('Time (years)'); ylabel('Water cut (%)');
ylim([0 100]); grid on;

%% 5. Individual producer rates
producerOil = {'Producer1_Oil','Producer2_Oil','Producer3_Oil','Producer4_Oil'};
producerWater = {'Producer1_Water','Producer2_Water', ...
                 'Producer3_Water','Producer4_Water'};

figure('Name', 'Individual Producer Performance', 'Color', 'w');
tiledlayout(2,2, 'TileSpacing','compact');

nexttile;
plotProducerRates(W50, producerOil, 'Oil Rates by Producer - 50 m^3/day');
nexttile;
plotProducerRates(W50, producerWater, 'Water Rates by Producer - 50 m^3/day');
nexttile;
plotProducerRates(W100, producerOil, 'Oil Rates by Producer - 100 m^3/day');
nexttile;
plotProducerRates(W100, producerWater, 'Water Rates by Producer - 100 m^3/day');

%% 6. Water saturation maps at Years 1, 3 and 5
for rate = [50 100]
    figure('Name', sprintf('Water Saturation - %d m3/day', rate), ...
        'Color', 'w');
    tiledlayout(1,3, 'TileSpacing','compact');

    for yr = [1 3 5]
        filename = sprintf('water_saturation_%dm3day_year%d.csv', rate, yr);
        saturation = readmatrix(fullfile(dataDir, filename));
        saturation = orientMap(saturation, NY, NX);

        nexttile;
        imagesc(1:NX, 1:NY, saturation);
        set(gca, 'YDir', 'normal');
        axis tight;
        colormap(gca, turbo);
        caxis([0.15 0.80]);
        colorbar;
        title(sprintf('Year %d', yr));
        xlabel('Grid X index'); ylabel('Grid Y index');
    end
    sgtitle(sprintf('Vertically Averaged Water Saturation - %d m^3/day', rate));
end

%% 7. Reservoir porosity and permeability maps
figure('Name', 'SPE10 Reservoir Properties', 'Color', 'w');
tiledlayout(1,2, 'TileSpacing','compact');

nexttile;
imagesc(1:NX, 1:NY, poroMap);
set(gca, 'YDir', 'normal');
axis tight; colorbar; colormap(gca, parula);
title('Vertically Averaged Porosity');
xlabel('Grid X index'); ylabel('Grid Y index');

nexttile;
% Logarithmic display is useful because permeability spans orders of magnitude.
logPerm = log10(permMap);
imagesc(1:NX, 1:NY, logPerm);
set(gca, 'YDir', 'normal');
axis tight; colorbar; colormap(gca, turbo);
title('Log_{10} Permeability (mD)');
xlabel('Grid X index'); ylabel('Grid Y index');

%% 8. Direct comparison of the two injection-rate cases
figure('Name', 'Injection Rate Comparison', 'Color', 'w');
tiledlayout(2,2, 'TileSpacing','compact');

nexttile;
plot(P50.Time_years, P50.CumulativeOil_m3, 'LineWidth', 1.8); hold on;
plot(P100.Time_years, P100.CumulativeOil_m3, 'LineWidth', 1.8);
title('Cumulative Oil Comparison');
xlabel('Time (years)'); ylabel('Cumulative oil (m^3)');
legend('50 m^3/day','100 m^3/day','Location','best'); grid on;

nexttile;
plot(P50.Time_years, P50.CumulativeWater_m3, 'LineWidth', 1.8); hold on;
plot(P100.Time_years, P100.CumulativeWater_m3, 'LineWidth', 1.8);
title('Cumulative Water Comparison');
xlabel('Time (years)'); ylabel('Cumulative water (m^3)');
legend('50 m^3/day','100 m^3/day','Location','best'); grid on;

nexttile;
plot(P50.Time_years, P50.InjectorBHP_bar, 'LineWidth', 1.8); hold on;
plot(P100.Time_years, P100.InjectorBHP_bar, 'LineWidth', 1.8);
title('Injector BHP Comparison');
xlabel('Time (years)'); ylabel('BHP (bar)');
legend('50 m^3/day','100 m^3/day','Location','best'); grid on;

nexttile;
plot(P50.Time_years, P50.WaterCut_percent, 'LineWidth', 1.8); hold on;
plot(P100.Time_years, P100.WaterCut_percent, 'LineWidth', 1.8);
title('Field Water Cut Comparison');
xlabel('Time (years)'); ylabel('Water cut (%)');
ylim([0 100]); legend('50 m^3/day','100 m^3/day','Location','best'); grid on;

fprintf('\nAll dashboard figures have been recreated in MATLAB.\n');
fprintf('CSV source folder: %s\n', dataDir);

%% Local helper functions
function A = orientMap(A, nRows, nCols)
    if isequal(size(A), [nRows, nCols])
        return;
    elseif isequal(size(A), [nCols, nRows])
        A = A.';
    else
        error('Unexpected map dimensions: %d x %d. Expected %d x %d.', ...
            size(A,1), size(A,2), nRows, nCols);
    end
end

function plotProducerRates(T, columns, plotTitle)
    hold on;
    for k = 1:numel(columns)
        col = columns{k};
        if ~ismember(col, T.Properties.VariableNames)
            error('Expected column "%s" was not found in producer CSV.', col);
        end
        plot(T.Time_years, T.(col), 'LineWidth', 1.5, ...
            'DisplayName', strrep(col, '_', ' '));
    end
    title(plotTitle);
    xlabel('Time (years)');
    ylabel('Rate (m^3/day)');
    legend('Location','best');
    grid on;
end
