
import AutoAxis.AnchorInfo
import AutoAxis.PositionType

clf;

xlim([-2 2])
ylim([-2 2])
hold on;
axis equal

hred = rectangle('Position', [0 0 1 1], 'FaceColor', [0.8 0.2 0.2 0.5], 'XLimInclude', 'off', 'YLimInclude', 'off');
hblue = rectangle('Position', [-1 -1 1 1], 'FaceColor', [0.2 0.2 0.8 0.5], 'XLimInclude', 'off', 'YLimInclude', 'off');
hgreen = rectangle('Position', [-1 1 1 1], 'FaceColor', [0.2 0.8 0.2 0.5], 'XLimInclude', 'off', 'YLimInclude', 'off');

axh = gca;
axh.XDir = "normal";
axh.YDir = "normal";

aa = AutoAxis();
aa.restoreBuiltinAxes();

aa.addAnchor(AnchorInfo(hblue, PositionType.VFraction, hred, PositionType.Bottom, 0, 'blue vert', frac = 0.4));
aa.addAnchor(AnchorInfo(hgreen, PositionType.HFraction, hred, PositionType.Left, 0, 'green horz', frac = 0.4));

ticks = 0:0.2:1;
ht = gobjects(numel(ticks), 1);
for iT = 1:numel(ticks)
    ht(iT) = text(0, 0, sprintf("%g", ticks(iT)), Background="none", HorizontalAlignment="left");
    aa.addAnchor(AnchorInfo(ht(iT), PositionType.VCenter, hred, PositionType.VFraction, 0, sprintf('tick %d vertical location', iT), fraca=ticks(iT)));
end

aa.addAnchor(AnchorInfo(ht, PositionType.Left, hred, PositionType.Right, 0.5, 'ticks right of red'));

vt = gobjects(numel(ticks), 1);
for iT = 1:numel(ticks)
    vt(iT) = text(0, 0, sprintf("%g", ticks(iT)), Background="none");
    aa.addAnchor(AnchorInfo(vt(iT), PositionType.HCenter, hred, PositionType.HFraction, 0, sprintf('tick %d horz location', iT), fraca=ticks(iT)));
end

aa.addAnchor(AnchorInfo(vt, PositionType.Top, hred, PositionType.Bottom, 0.5, 'ticks below red'));

% now test aggregate positioning
ncirc = 5;
[hc, hv] = deal(gobjects(ncirc, 1));
for i = 1:ncirc
    hc(i) = rectangle(Position=[(i-1)*0.1, -1.5, 0.05, 0.05], Curvature=[1 1], FaceColor=hex2rgb('#AF7AC5'), ...
        EdgeColor=hex2rgb('#2E4053'), XLimInclude='off', YLimInclude='off');

    hv(i) = rectangle(Position=[-1.5, (i-1)*0.1, 0.05, 0.05], Curvature=[1 1], FaceColor=hex2rgb('#48C9B0'), ...
        EdgeColor=hex2rgb('#2E4053'), XLimInclude='off', YLimInclude='off');
end

aa.addAnchor(AnchorInfo(hc, PositionType.VCenter, hred, PositionType.VFraction, 0, 'hcirc to 0.6 v', fraca=0.6));
aa.addAnchor(AnchorInfo(hc, PositionType.HCenter, hred, PositionType.HFraction, 0, 'hcirc to 0.6 h', fraca=0.6));

aa.addAnchor(AnchorInfo(hv, PositionType.VCenter, hred, PositionType.VFraction, 0, 'vcirc to 0.65 v', fraca=0.65));
aa.addAnchor(AnchorInfo(hv, PositionType.HCenter, hred, PositionType.HFraction, 0, 'vcirc to 0.65 h', fraca=0.65));


aa.update();
