import AutoAxis.PositionType;
import AutoAxis.AnchorInfo;
close all;

figure(1), clf, set(1, 'Color', 'w');

t = linspace(-6,6,300);
xlim([-5 5]);
ylim([-5 5]);

avals = linspace(0.5, 5, 3);
cmap = copper(numel(avals));
for i = 1:numel(avals)
    y = avals(i)*sin(2*pi*0.5*t);
    h(i) = plot(t, y, '-', 'Color', cmap(i, :), 'LineWidth', 2);
    hold on
end

ax = AutoAxis();
axh = gca;

ax.addLocationIndicatorTop(0, 'x=0 Top');
ax.addLocationIndicatorBottom(0, 'x=0 Bottom');

ax.addLocationIndicatorRight(0, 'y=0 Right');
ax.addLocationIndicatorLeft(0, 'y=0 Left');

ax.update();
