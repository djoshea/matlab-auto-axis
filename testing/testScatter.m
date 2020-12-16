clf;
plot(randn(100, 2));
hold on;
% h = scatter(0, 0, 500, 'r', 'XLimInclude', false, 'YLimInclude', false);
h = plot(0, 0, 'ro', 'MarkerSize', 40, 'XLimInclude', false, 'YLimInclude', false);
h.Clipping = 'off';
grid on

ax = gca;
% ax.XDir = 'reverse';
% ax.YDir = 'reverse';

aa = AutoAxis();
% aa.anchorToAxisBottomRight(h);
aa.anchorToAxisTopLeft(h);
aa.update();
