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
axis(axi, 'equal');
axis(axh, 'equal');
axi.Units = 'normalized';
axi.Color="none";

nf_inset = AutoAxis.axisPosInNormalizedFigureUnits(axi);
pos = AutoAxis.normFigureUnitsToAxisDataUnits(axh, nf_inset);
h = rectangle(Position=pos, EdgeColor='g', LineWidth=3, Parent=axh, XLimInclude=false, YLimInclude=false);

return;
% for debugging

axover = axes(Position=[0 0 1 1], Color="none");
axover.XLim = [0 1];
axover.YLim = [0 1];
axover.HitTest = false;
hold(axover, 'on');


nfpos_inset = axi.Position;
nfpb_inset = AutoAxis.plotboxpos(axi);
nfouterpos_inset = axi.OuterPosition;

rectangle(Position=nfpb_inset, EdgeColor='r', Parent=axover);
%rectangle(Position=nfpos_inset, EdgeColor='b', Parent=axover);
rectangle(Position=nfouterpos_inset, EdgeColor='b', Parent=axover);

axh.Units = 'normalized';
nfpos = axh.Position;
nfpb = AutoAxis.plotboxpos(axh);
nfouterpos = axh.OuterPosition;

rectangle(Position=nfpb, EdgeColor='r', Parent=axover);
rectangle(Position=nfpos, EdgeColor='b', Parent=axover);
rectangle(Position=nfouterpos, EdgeColor='b', Parent=axover);

%% Get limits
xl = axh.XLim;
yl = axh.YLim;
axwidth = diff(xl);
axheight = diff(yl);
 
pos = nan(1,4);
pos(1) = (nfpb_inset(:,1) - nfpb(1))*axwidth/nfpb(3) + xl(1) +0.05;
pos(2) = (nfpb_inset(:,2) - nfpb(2))*axheight/nfpb(4) + yl(1) + 0.05;
pos(3) = nfpb_inset(:,3)*axwidth/nfpb(3);
pos(4) = nfpb_inset(:,4)*axheight/nfpb(4);        

h = rectangle(Position=pos, EdgeColor='g', Parent=axh, XLimInclude=false, YLimInclude=false);




