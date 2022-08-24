
%% generate random gaussian process image

S = 200;
rng(2.1);
img = randn(S, S);
cl = 20;
x = (-3*cl:3*cl)';
y = x';
[X,Y] = ndgrid(x, y);
filt = exp(-(X.^2 + Y.^2) ./ (cl^2/2));
filt = filt ./ sum(filt(:));
img = conv2(img, filt, 'same');
img = img ./ max(abs(img(:))) * 100;

% render using oxy colormap with two breaks at red / gray / yellow
map = cmocean('oxy', 100);
cbreaks = [21 80]; % 21 is first gray color such that values between first two intervals map to this gray row 21, 80 is last gray color, such that values between intervals 2 and 3 map to this gray

cbreaks_display = [21 81]; % here we want to ensure that the visual break happens after the 80 last gray color

clims = [-100 100];
cbreakIntervals = [-100 -60; -20 20; 60 100];
% cbreakLabels = [cbreakIntervals(1, 2) 2 0; 60 80]; % NaN means omit label

rgbimg = applyColormapWithBreaks(img, map, cbreakIntervals, cbreaks);
%image(rgbimg);

%% view colorm
clf
colorView(map);
axis on
hold on;
xline(cbreaks_display(1) - 0.5);
xline(cbreaks_display(2) - 0.5);
hold off;

%%

clf;
image(rgbimg);
colormap(map);
caxis([-0.07 0.07]);
xlim([0 200]);
ylim([0 200]);
xlabel('x');
ylabel('y');
title('color scale with breaks');

% test both modes
set(gca, 'YDir', 'reverse');
set(gca, 'YDir', 'normal');

aa = AutoAxis();
% aa.replace();
% aa.hideBuiltinAxes = false; % helpful for debugging
scale = getFigureSizeScale();
aa.addColorbar('cmap', map, 'limits', clims, 'breakInds', cbreaks_display, 'labelLimits', true, 'height', 3*scale, 'breakLimitIntervals', cbreakIntervals, 'labelFormat', '%+g', 'units', 'μm');
aa.axisMargin = [2.2 2 3 1];
aa.update();
