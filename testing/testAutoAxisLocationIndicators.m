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

ax.addLocationIndicator('x', 0, 'x=0');
ax.addLocationIndicator('x', 0, 'x=0', 'otherSide', true);

ax.addLocationIndicator('y', 0, 'y=0');
ax.addLocationIndicator('y', 0, 'y=0', 'otherSide', true);

ax.update();
