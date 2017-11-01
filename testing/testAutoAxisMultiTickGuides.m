figure(1), clf, set(1, 'Color', 'w');

t = linspace(-6,6,300);

avals = linspace(0.5, 5, 5);
cmap = copper(numel(avals));
for i = 1:numel(avals)
    y = avals(i)*sin(2*pi*0.5*t);
    h(i) = plot(t, y, '-', 'Color', cmap(i, :), 'LineWidth', 2);
    hold on
    plot(t + 13.3, y, '-', 'Color', cmap(i, :), 'LineWidth', 2);
    
    plot(t, y+11.3, '-', 'Color', cmap(i, :), 'LineWidth', 2);
    plot(t + 13.3, y+11.3, '-', 'Color', cmap(i, :), 'LineWidth', 2);
end

xlim([-6 19.3]);
ylim([-5 16.3]);

% playing around with a dot and label

%hm = plot(5.5,4, 'o', 'MarkerSize', 20, 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'none');
%ht = text(1,1, 'Anchored Label', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');

aa = AutoAxis();
axh = gca;
aa.addAutoBridgeX('zero', 0, 'start', -6, 'stop', 6);
aa.addAutoBridgeX('zero', 13.3, 'start', -6, 'stop', 6);
aa.addAutoBridgeY('zero', 0, 'start', -5, 'stop', 5);
aa.addAutoBridgeY('zero', 11.3, 'start', -5, 'stop', 5);
aa.update();

grid minor;