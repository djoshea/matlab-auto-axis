clf;
ax = gca;

h = rectangle(Position=[0 0 1 1], EdgeColor='k', LineWidth=3);

hold on;
ha(1) = annotation('arrow', Parent=ax, Position=[0 0 1 0], Color='r');
ha(2) = annotation('arrow', Parent=ax, Position=[1 0 0 1], Color='g');
ha(3) = annotation('arrow', Parent=ax, Position=[1 1 -1 0], Color='b');
ha(4) = annotation('arrow', Parent=ax, Position=[0 1 0 -1], Color='m');

xlim([-2 2]);
ylim([-2 2]);

niceGrid;
axis equal;

%%

% ax.XDir='reverse';
% ax.YDir='reverse';

import AutoAxis.AnchorInfo;
import AutoAxis.PositionType;
aa = AutoAxis;
aa.addAnchor(AnchorInfo(h, PositionType.Right, 0, PositionType.Literal, 0));
aa.addAnchor(AnchorInfo(h, PositionType.Top, 0, PositionType.Literal, 0));

aa.addAnchor(AnchorInfo(ha, PositionType.Top, h, PositionType.Top, 0));
aa.addAnchor(AnchorInfo(ha, PositionType.Right, h, PositionType.Right, 0));
aa.restoreBuiltinAxes();
aa.update();
