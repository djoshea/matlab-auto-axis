import AutoAxis.PositionType;
import AutoAxis.AnchorInfo;

figure(1), clf, set(1, 'Color', 'w');

t = linspace(-6,6,300);


avals = linspace(0.5, 5, 20);
cmap = copper(numel(avals));
for i = 1:numel(avals)
    y = avals(i)*sin(2*pi*0.5*t) + t/2;
    plot(t, y, '-', 'Color', cmap(i, :), 'LineWidth', 2);
    hold on
end

ylabel('Y Label');
xlabel('X Label');
title('Plot Title');
subtitle('This is the subtitle');

xlim([-6.5 6.5]);
ylim([-6.5 6.5]);

% set(gca, 'XTick', -6:6);
% set(gca, 'YTick', -6:6);

au = AutoAxis();
% au.addTickBridge('x', 'extendToLimits', true, tickMarks=false, manualPositionOrthogonalAxis=0);
% au.addTickBridge('y', 'extendToLimits', true, tickMarks=false, manualPositionOrthogonalAxis=-3);

au.autoAxisXManualPositionY = 0;
au.autoAxisYManualPositionX = -3;
au.addAutoAxisX();
au.addAutoAxisY();
au.axisMargin = [2 2 2 2];
au.gridOn
au.update();


