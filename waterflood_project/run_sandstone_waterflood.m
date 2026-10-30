
function run_sandstone_waterflood()
% RUN_SANDSTONE_WATERFLOOD
% Two-phase oil-water simulation of a representative sandstone reservoir.
%
% Units: SI internally; exports use m3/day, bar and days.
% Data: synthetic representative assumptions, not field measurements.
%
% Requires MRST modules: ad-core, ad-props, ad-blackoil, mrst-gui.

clc;
close all;

%% 1. Initialize MRST
mrstModule add ad-core ad-props ad-blackoil mrst-gui

% Horizontal reservoir: neglect gravity for this first model.
gravity reset off

%% 2. Project settings
outDir = fullfile(pwd, 'results');

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% Grid dimensions
nx = 40;
ny = 20;
nz = 1;

% Reservoir dimensions (m)
Lx = 500;
Ly = 250;
Lz = 10;

% Rock properties
phi = 0.20;
kx_mD = 100;
ky_mD = 100;
kz_mD = 10;

% Fluid properties
muW_cP = 1.0;
muO_cP = 5.0;
rhoW = 1000;
rhoO = 800;

% Initial conditions
p0_bar = 250;


% Residual saturation assumptions
Swr = 0.15;
Sor = 0.20;
Sw0 = Swr;

% Well controls
qInj_m3day = 100;
pProd_bar = 220;

% Simulation period and number of steps
nSteps = 60;
T = 5 * year;

fprintf('Building reservoir grid...\n');

%% 3. Grid and geometry
G = cartGrid([nx, ny, nz], [Lx, Ly, Lz]);
G = computeGeometry(G);

%% 4. Rock properties
% Convert mD to SI permeability.
perm = repmat([kx_mD, ky_mD, kz_mD], ...
    G.cells.num, 1) * milli * darcy;

rock = makeRock(G, perm, phi);

%% 5. Fluid model
% MRST phase ordering: water, oil.
fluid = initSimpleADIFluid( ...
    'phases', 'wo', ...
    'mu', [muW_cP, muO_cP] * centi * poise, ...
    'rho', [rhoW, rhoO] * kilogram / meter^3, ...
    'n', [2, 2]);

% Corey-style relative permeability with residual saturations.
% These endpoints are stated assumptions, not fitted laboratory data.
denom = 1 - Swr - Sor;

fluid.krW = @(sw) max((sw - Swr) ./ denom, 0).^2;
fluid.krO = @(so) max((so - Sor) ./ denom, 0).^2;

%% 6. Reservoir model and initial state
model = TwoPhaseOilWaterModel(G, rock, fluid);

state0 = initResSol(G, p0_bar * barsa, [Sw0, 1 - Sw0]);

%% 7. Place the wells
% Injector near the left boundary.
% Producer near the right boundary.

injCell = sub2ind([nx, ny, nz], 1, round(ny/2), 1);
prodCell = sub2ind([nx, ny, nz], nx, round(ny/2), 1);

W = [];

W = addWell(W, G, rock, injCell, ...
    'Name', 'INJ', ...
    'Type', 'rate', ...
    'Val', qInj_m3day * meter^3 / day, ...
    'Comp_i', [1, 0]);

W = addWell(W, G, rock, prodCell, ...
    'Name', 'PROD', ...
    'Type', 'bhp', ...
    'Val', pProd_bar * barsa, ...
    'Comp_i', [0, 1]);

%% 8. Simulation schedule
dt = repmat(T / nSteps, nSteps, 1);

schedule = simpleSchedule(dt, 'W', W);

%% 9. Run simulation
fprintf('Running two-phase simulation...\n');

[wellSols, states] = simulateScheduleAD( ...
    state0, model, schedule);

fprintf('Simulation finished.\n');

%% Diagnostic: producer water saturation history

SwProducer = zeros(numel(states), 1);

for j = 1:numel(states)
    SwProducer(j) = states{j}.s(prodCell, 1);
end

figure('Name', 'Producer water saturation');
plot(0:numel(states)-1, SwProducer, 'LineWidth', 1.5);

xlabel('Saved state index');
ylabel('Water saturation at producer');
title('Producer Water Saturation History');
grid on;

fprintf('Initial producer Sw: %.4f\n', SwProducer(1));
fprintf('Final producer Sw: %.4f\n', SwProducer(end));
fprintf('Residual Sw: %.4f\n', Swr);
fprintf('Producer cell index: %d\n', prodCell);

fprintf('Initial producer Sw: %.6f\n', ...
    states{1}.s(prodCell, 1));

fprintf('Final producer Sw: %.6f\n', ...
    states{end}.s(prodCell, 1));

fprintf('Maximum final Sw: %.6f\n', ...
    max(states{end}.s(:, 1)));

%% 10. Check basic state validity
assert(~isempty(states), ...
    'No reservoir states were returned.');

for j = 1:numel(states)
    sw = states{j}.s(:, 1);

    assert(all(isfinite(sw)), ...
        'Non-finite water saturation found.');

    assert(all(sw >= -1e-7 & sw <= 1 + 1e-7), ...
        'Water saturation outside physical bounds.');
end

%% 11. Plot permeability
figure('Name', 'Reservoir permeability');
plotCellData(G, rock.perm(:, 1) / (milli * darcy));
axis tight;
colorbar;
title('Horizontal Permeability (mD)');
xlabel('X');
ylabel('Y');

%% 12. Plot final water saturation
figure('Name', 'Final water saturation');
plotCellData(G, states{end}.s(:, 1));
axis tight;
colorbar;
title('Final Water Saturation');
xlabel('X');
ylabel('Y');

%% 13. Plot final pressure
figure('Name', 'Final reservoir pressure');
plotCellData(G, states{end}.pressure / barsa);
axis tight;
colorbar;
title('Final Pressure (bar)');
xlabel('X');
ylabel('Y');

%% 14. Extract well results
n = numel(wellSols);
timeDays = cumsum(schedule.step.val(:)) / day;

assert(n == numel(timeDays), ...
    'Well-solution count does not match schedule steps.');

qOil = zeros(n, 1);
qWater = zeros(n, 1);
qInjection = zeros(n, 1);
pProducer = zeros(n, 1);

for it = 1:n
    ws = wellSols{it};

    injIdx = find(strcmp({ws.name}, 'INJ'), 1);
    prodIdx = find(strcmp({ws.name}, 'PROD'), 1);

    assert(~isempty(injIdx) && ~isempty(prodIdx), ...
        'Injector or producer not found in well solutions.');

    % Positive magnitudes, in m3/day.
    qOil(it) = abs(ws(prodIdx).qOs) / (meter^3 / day);
    qWater(it) = abs(ws(prodIdx).qWs) / (meter^3 / day);
    qInjection(it) = abs(ws(injIdx).qWs) / (meter^3 / day);

    pProducer(it) = ws(prodIdx).bhp / barsa;
end

%% 15. Calculate performance indicators
liquidRate = qOil + qWater;

waterCut = zeros(n, 1);
mask = liquidRate > 1e-10;
waterCut(mask) = qWater(mask) ./ liquidRate(mask);

% Approximate OOIP at reservoir conditions.
% Assumes Bo = 1 for this simplified model.
PV = sum(poreVolume(G, rock));
OOIP = PV * (1 - Sw0);

% Include time zero in the numerical integration.
cumOil = cumtrapz([0; timeDays], [0; qOil]);
cumOil = cumOil(2:end);

recoveryFactor = 100 * cumOil / OOIP;

production = table( ...
    timeDays, qInjection, qOil, qWater, waterCut, ...
    pProducer, cumOil, recoveryFactor, ...
    'VariableNames', { ...
    'time_days', 'injection_m3_day', ...
    'oil_m3_day', 'water_m3_day', ...
    'water_cut_fraction', 'producer_bhp_bar', ...
    'cumulative_oil_m3', 'recovery_factor_pct'});

writetable(production, ...
    fullfile(outDir, 'production.csv'));

%% 16. Export saturation snapshots
nStates = numel(states);
Sw = zeros(G.cells.num, nStates);

for j = 1:nStates
    Sw(:, j) = states{j}.s(:, 1);
end

% Match snapshots to their simulation times.
if nStates == nSteps + 1
    snapshotDays = [0; timeDays];
elseif nStates == nSteps
    snapshotDays = timeDays;
else
    warning(['Unexpected state count. Snapshot times are ', ...
        'approximated over the simulation period.']);
    snapshotDays = linspace(0, timeDays(end), nStates)';
end

writematrix(Sw, ...
    fullfile(outDir, 'Sw_snapshots.csv'));

writetable(table(snapshotDays, ...
    'VariableNames', {'time_days'}), ...
    fullfile(outDir, 'snapshot_times.csv'));

%% 17. Export metadata
metadata = table( ...
    nx, ny, nz, Lx, Ly, Lz, phi, ...
    kx_mD, ky_mD, kz_mD, Sw0, Swr, Sor, ...
    qInj_m3day, pProd_bar, ...
    'VariableNames', { ...
    'nx', 'ny', 'nz', 'Lx_m', 'Ly_m', 'Lz_m', ...
    'porosity', 'kx_mD', 'ky_mD', 'kz_mD', ...
    'initial_water_saturation', 'Swr', 'Sor', ...
    'injection_m3_day', 'producer_bhp_bar'});

writetable(metadata, ...
    fullfile(outDir, 'metadata.csv'));

%% 18. Save the simulation
save(fullfile(outDir, 'baseline.mat'), ...
    'G', 'rock', 'fluid', 'wellSols', ...
    'states', 'schedule', 'production', ...
    'metadata', '-v7.3');

%% 19. Plot production history
figure('Name', 'Waterflood production');
plot(timeDays, qOil, 'LineWidth', 1.5);
hold on;
plot(timeDays, qWater, 'LineWidth', 1.5);
xlabel('Time (days)');
ylabel('Rate (m^3/day)');
legend('Oil production', 'Water production', ...
    'Location', 'best');
grid on;
title('Production History');

figure('Name', 'Water cut');
plot(timeDays, 100 * waterCut, 'LineWidth', 1.5);
xlabel('Time (days)');
ylabel('Water cut (%)');
ylim([0, 100]);
grid on;
title('Produced Water Cut');

%% 20. Report results
fprintf('\n--- WATERFLOOD SUMMARY ---\n');
fprintf('Grid cells: %d\n', G.cells.num);
fprintf('Total pore volume: %.2f m3\n', PV);
fprintf('Approximate OOIP: %.2f m3\n', OOIP);
fprintf('Final cumulative oil: %.2f m3\n', cumOil(end));
fprintf('Final recovery factor: %.3f %%\n', ...
    recoveryFactor(end));
fprintf('Final water cut: %.2f %%\n', ...
    100 * waterCut(end));
fprintf('Results folder: %s\n', outDir);

end
