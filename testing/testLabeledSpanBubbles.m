individual = false;
clf;

t = linspace(0, 6*pi, 400)';
plot(t, [cos(t), sin(t)], '-', 'LineWidth', 3);
xlim([0 6*pi]);
ylim([-1 1]);
axis tight;

ax = gca;
ax.XTick = 0:pi/2:6*pi;
ax.YTick = -1:1/6:1;

continuationDots = [true, true];
bubblePadding = [0.1 0.1];
curvature = 0.5;
aa = AutoAxis();

if individual
    aa.addLabeledSpanBubbles('x', span=[0*pi 2*pi], label="phase 1", textColor='k', color=[0.8 0.2 0.2], ...
        continuationDots=continuationDots, bubblePadding=bubblePadding, curvature=curvature);
    aa.addLabeledSpanBubbles('x', span=[2*pi 4*pi], label="phase 2", textColor='k', color=[0.2 0.8 0.2], ...
        continuationDots=continuationDots, bubblePadding=bubblePadding, curvature=curvature);
    aa.addLabeledSpanBubbles('x', span=[4*pi 6*pi], label="phase 3", textColor='k', color=[0.2 0.2 0.8], ...
        continuationDots=continuationDots, bubblePadding=bubblePadding, curvature=curvature);
else
    aa.addLabeledSpanBubbles('x', span=[0*pi 2*pi; 2*pi 4*pi; 4*pi 6*pi]', label=["phase 1", "phase 2", "phase 3"], textColor='k', color=[0.8 0.2 0.2; 0.2 0.8 0.2; 0.2 0.2 0.8], ...
        continuationDots=continuationDots, bubblePadding=bubblePadding, curvature=curvature);
end

if individual
    aa.addLabeledSpanBubbles('y', span=[-1 -1/3], label="low amp", textColor='k', color=[1 0.64 0], rotation=90, ...
        rotation=90, continuationDots=continuationDots, bubblePadding=bubblePadding, curvature=curvature);
    aa.addLabeledSpanBubbles('y', span=[-1/3 1/3], label="mid amp", textColor='k', color=[1 0.64 0.5], rotation=90, ...
        rotation=90, continuationDots=continuationDots, bubblePadding=bubblePadding, curvature=curvature);
    aa.addLabeledSpanBubbles('y', span=[1/3 1], label="high amp", textColor='k', color=[1 0.64 1], rotation=90, ...
        rotation=90, continuationDots=continuationDots, bubblePadding=bubblePadding, curvature=curvature);
else
    aa.addLabeledSpanBubbles('y', span=[-1 -1/3; -1/3 1/3; 1/3 1]', label=["low amp", "mid amp", "high amp"], textColor='k', color=[1 0.64 0; 1 0.64 0.5; 1 0.64 1], ...
        continuationDots=continuationDots, bubblePadding=bubblePadding, rotation=90);
end

grid on;

aa.update();