
%% SPE10 Waterflood Front Monitoring
% Uses existing simulation states. No new simulation required.

%% 1. Verify existing data

assert(exist('G','var') == 1, 'Grid G is missing.');
assert(exist('states','var') == 1, 'Simulation states are missing.');
assert(exist('schedule','var') == 1, 'Schedule is missing.');

%% 2. Calculate simulation time

dt = schedule.step.val(:);
timeDays = cumsum(dt)/day;
timeYears = timeDays/365.25;

%% 3. Select monitoring times

targetYears = [1, 3, 5];
snapshotIndices = zeros(size(targetYears));

for k = 1:numel(targetYears)
    [~, snapshotIndices(k)] = ...
        min(abs(timeYears - targetYears(k)));
end


%% 4. Plot vertically averaged water saturation maps

nx = G.cartDims(1);
ny = G.cartDims(2);
nz = G.cartDims(3);

x = linspace(0, 1200*0.3048, nx);
y = linspace(0, 2200*0.3048, ny);

for k = 1:numel(targetYears)

    idx = snapshotIndices(k);

    % Reshape cell saturation into 3D grid
    sw3D = reshape(states{idx}.s(:,1), [nx, ny, nz]);

    % Average saturation through the eight layers
    swMap = mean(sw3D, 3);

    figure('Name', sprintf('Water Front - Year %d', ...
        targetYears(k)));

    imagesc(x, y, swMap');

    set(gca, 'YDir', 'normal');
    axis equal tight;

    colormap(turbo);
    clim([0.15 0.80]);
    colorbar;

    xlabel('X Distance (m)');
    ylabel('Y Distance (m)');

    title(sprintf('Vertically Averaged Water Saturation - Year %.0f', ...
        targetYears(k)));

end

%% 5. Print monitoring information

fprintf('\n===== WATERFRONT MONITORING =====\n');

for k = 1:numel(targetYears)

    idx = snapshotIndices(k);
    sw = states{idx}.s(:,1);

    fprintf('\nTarget time: %.1f years\n', targetYears(k));
    fprintf('Actual time: %.3f years\n', timeYears(idx));
    fprintf('Minimum Sw: %.4f\n', min(sw));
    fprintf('Maximum Sw: %.4f\n', max(sw));
    fprintf('Average Sw: %.4f\n', mean(sw));

end

fprintf('\nWaterfront monitoring completed.\n');
