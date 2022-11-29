clf;
ax = gca;

h = rectangle(Position=[0 0 1 1], EdgeColor='k', LineWidth=3);
hold on;
plot(0.5, 0.5, 'ko', MarkerFaceColor='k');

h2 = rectangle(Position=[0.25 0.25 0.5 0.5], EdgeColor='r', LineWidth=3);

h3 = rectangle(Position=[0.25 -0.25 0.5 0.5], EdgeColor='b', LineWidth=3);
plot(0.5, 0, 'bo', MarkerFaceColor='b');
xlim([-2 2]);
ylim([-2 2]);

niceGrid;
axis equal;

%%

% ax.XDir='reverse';
% ax.YDir='reverse';

scale = getFigureSizeScale();
import AutoAxis.AnchorInfo;
import AutoAxis.PositionType;
aa = AutoAxis;
aa.anchorWidth([h; h2], 2*scale, preserveAspectRatio=true);

aa.anchorWidth(h3, 2*scale, preserveAspectRatio=true);
aa.update();
