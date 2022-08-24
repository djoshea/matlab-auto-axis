import AutoAxis.PositionType;
import AutoAxis.AnchorInfo;
%close all;

figh = figure(1); clf; 
set(figh, Visible=true);
figSizeScale([8 3]);

xlim([-5 5]);
ylim([-5 5]);

axh = gca;

axi = axes(Position=[0.3 0.3 0.3 0.2]);

x = linspace(-5, 5, 100);
y = sin(x);
plot(x, y, Parent=axi);
%axis(axi, 'equal');
axis(axh, 'equal');
grid(axh, 'on');

axi.Color="none";

aa = AutoAxis(axh);
aa.restoreBuiltinAxes;
aa.anchorToDataLiteral(axi, PositionType.Left, 0, desc='anchor inset axis left to 0');
aa.anchorWidth(axi, 2, desc='anchor inset axis width');

aa.anchorToDataLiteral(axi, PositionType.Bottom, 0, desc='anchor inset axis bottom to 0');
aa.anchorHeight(axi, 2, desc='anchor inset axis height');
aa.update();

