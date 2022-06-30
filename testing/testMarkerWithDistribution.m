clf;

x = linspace(0, 2*pi, 50);
y = sin(x);

plot(x, y, '-');


mask = y < -0.5;
xv = x(mask);
yv = -y(mask);
[~, ind] = min(y);
xmark = x(ind);

color = hex2rgb('2596be');

% xmark = 0;
% xv = [0 pi 2*pi];
% yv = [0.7 0.3 0.7];

aa = AutoAxis();
aa.addMarkerX(xmark, "min", ...
    'distribution', yv,  'distributionBins', xv, ...
    'markerColor', color, 'distributionColor', color, ...
    'alpha', 0.9, 'normalizeDistribution', true);

aa.update();