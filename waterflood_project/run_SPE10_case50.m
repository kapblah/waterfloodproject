
%% SPE10 3D Waterflood Model
% MRST 2026a
% Published SPE10 rock properties; fluid and well controls are assumptions.

clear; clc; close all;

mrstModule add spe10 ad-core ad-props

%% 1. Model dimensions
layers = 1:8;

nx = 60;
ny = 220;
nz = numel(layers);

% SPE10 Model 2 cell dimensions: 20 x 10 x 2 ft
G = cartGrid([nx, ny, nz], [1200, 2200, 2*nz]*ft);
G = computeGeometry(G);

%% 2. Load published SPE10 rock properties
rock = getSPE10rock(layers);

% Validate SPE10 rock properties
assert(size(rock.perm,1) == G.cells.num, ...
    'Permeability data does not match grid cell count.');
assert(numel(rock.poro) == G.cells.num, ...
    'Porosity data does not match grid cell count.');

% Identify zero-porosity cells in the original dataset
zeroPoro = rock.poro <= 0;

fprintf('Zero-porosity cells in original data: %d\n', ...
    nnz(zeroPoro));

% Numerical regularization for MRST's positive-pore-volume requirement.
% Keep the original permeability values unchanged.
% Sensitivity testing is required to assess the impact of this adjustment.
poroFloor = 1e-4;
rock.poro(rock.poro < poroFloor) = poroFloor;

% Confirm corrected properties
assert(all(rock.poro > 0), ...
    'Porosity must be positive in every cell.');
assert(all(rock.perm(:) >= 0), ...
    'Permeability cannot be negative.');

fprintf('Grid cells: %d\n', G.cells.num);
fprintf('Porosity range after adjustment: %.5f to %.5f\n', ...
    min(rock.poro), max(rock.poro));
fprintf('Permeability range: %.4g to %.4g m^2\n', ...
    min(rock.perm(:)), max(rock.perm(:)));


%% 3. Fluid model
Swr = 0.15;
Sor = 0.20;

fluid = initSimpleADIFluid( ...
    'phases', 'WO', ...
    'mu', [1, 5]*centi*poise, ...
    'rho', [1000, 800]*kilogram/meter^3, ...
    'n', [2, 2]);

% Corey relative permeability
fluid.krW = @(sw) max(0, min(1, (sw-Swr)/(1-Swr-Sor))).^2;
fluid.krO = @(so) max(0, min(1, (so-Sor)/(1-Swr-Sor))).^2;

%% 4. Create reservoir model
model = TwoPhaseOilWaterModel(G, rock, fluid);

%% 5. Initial reservoir state
pInitial = 250*barsa;
Sw0 = Swr;

state0 = initResSol(G, pInitial, [Sw0, 1-Sw0]);

%% 6. Wells: central injector, four corner producers
% Complete every well through all eight layers.
W = [];

wellCells = @(i,j) sub2ind([nx,ny,nz], ...
    repmat(i,nz,1), repmat(j,nz,1), (1:nz)');

% Injection rate: total 100 m^3/day
qInjection = 50*meter^3/day;

W = addWell(W, G, rock, wellCells(30,110), ...
    'Type', 'rate', ...
    'Val', qInjection, ...
    'Radius', 0.1*meter, ...
    'Comp_i', [1,0], ...
    'Name', 'Injector');

% Production wells held at 220 bar BHP
producerLocations = [1,1; nx,1; 1,ny; nx,ny];

for n = 1:size(producerLocations,1)
    i = producerLocations(n,1);
    j = producerLocations(n,2);

    W = addWell(W, G, rock, wellCells(i,j), ...
        'Type', 'bhp', ...
        'Val', 220*barsa, ...
        'Radius', 0.1*meter, ...
        'Comp_i', [0,1], ...
        'Name', sprintf('Producer%d',n));
end

%% 7. Simulation schedule: five years
totalTime = 5*year;
dtInitial = 0.1*day;
dtMax = 5*day;

nSteps = ceil((totalTime - dtInitial)/dtMax) + 1;
dt = [dtInitial; repmat(dtMax, nSteps-1, 1)];

% Ensure exactly five years of simulation
dt(end) = totalTime - sum(dt(1:end-1));

schedule = simpleSchedule(dt, 'W', W);
%% 8. Run simulation
[wellSols, states] = simulateScheduleAD( ...
    state0, model, schedule);

fprintf('\nSimulation completed.\n');
fprintf('Time steps: %d\n', numel(states));

%% 9. Plot final water saturation
figure('Name','SPE10 Final Water Saturation');
plotCellData(G, states{end}.s(:,1));
view(3);
axis tight equal;
colorbar;
title('Final Water Saturation');
xlabel('X'); ylabel('Y'); zlabel('Z');

%% 10. Plot final pressure
figure('Name','SPE10 Final Pressure');
plotCellData(G, states{end}.pressure/barsa);
view(3);
axis tight equal;
colorbar;
title('Final Pressure (bar)');
xlabel('X'); ylabel('Y'); zlabel('Z');

%% 11. Save simulation outputs
resultsDir = fullfile(pwd, 'SPE10_results');

if ~isfolder(resultsDir)
    mkdir(resultsDir);
end

save(fullfile(resultsDir, 'SPE10_case50_results.mat'), ...
    'G', 'rock', 'fluid', 'W', 'schedule', ...
    'wellSols', 'states', 'Swr', 'Sor', '-v7.3');

fprintf('Results saved to:\n%s\n', resultsDir);
