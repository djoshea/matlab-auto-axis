import AutoAxis.PositionType;
import AutoAxis.AnchorInfo;
close all;

figure(1), clf, set(1, 'Color', 'w');

img = image(rand(10, 5, 3));
% img = image(rand(1, 5, 3));
% img = image(rand(10, 1, 3));


ax = gca;

aa = AutoAxis();
aa.addAnchor(AnchorInfo(img, PositionType.Top, ax, PositionType.Top));
aa.addAnchor(AnchorInfo(img, PositionType.Left, ax, PositionType.Left));
aa.addAnchor(AnchorInfo(img, PositionType.Height, [], 6));
aa.addAnchor(AnchorInfo(img, PositionType.Width, [], 3));

aa.showMatlabAxes();
aa.update;
% 
% 
%%

import AutoAxis.PositionType;
import AutoAxis.AnchorInfo;
close all;

figure(1), clf, set(1, 'Color', 'w');

t = linspace(-6,6,300);
xlim([-5 5]);
ylim([-5 5]);

avals = linspace(0.5, 5, 20);
cmap = copper(numel(avals));
for i = 1:numel(avals)
    y = avals(i)*sin(2*pi*0.5*t);
    h(i) = plot(t, y, '-', 'Color', cmap(i, :), 'LineWidth', 2);
    hold on
end

aa = AutoAxis();
aa.addColorbar('cmap', cmap, 'labelLow', '0', 'labelHigh', '100', 'labelCenter', 'Value');
aa.update();

%%

import AutoAxis.PositionType;
import AutoAxis.AnchorInfo;
close all;

figure(1), clf, set(1, 'Color', 'w');

t = linspace(-6,6,300);
xlim([-5 5]);
ylim([-5 5]);

avals = linspace(0.5, 5, 20);
cmap = copper(numel(avals));
for i = 1:numel(avals)
    y = avals(i)*sin(2*pi*0.5*t);
    h(i) = plot(t, y, '-', 'Color', cmap(i, :), 'LineWidth', 2);
    hold on
end

aa = AutoAxis();
aa.addColorbar('cmap', cmap, 'labelLow', '0', 'labelHigh', '100', 'labelCenter', 'Value', 'backgroundColor', 'r', 'backgroundAlpha', 0.5);
aa.update();

%%

import AutoAxis.PositionType;
import AutoAxis.AnchorInfo;

figure(1), clf, set(1, 'Color', 'w');

aa = AutoAxis();

houter = rectangle('Position', [0.25 0.25 0.5 0.5], 'FaceColor', 'g', 'Tag', 'Outer');

hinner = rectangle('Position', [0 0 1 1], 'FaceColor', 'r', 'Tag', 'Inner');
hold on;


xlim([-1 2]);
ylim([-1 2]);

aa.anchorAroundObjectWithPadding(houter, hinner, 0.1);
aa.anchorToAxisTopLeft(houter);
% aa.update();