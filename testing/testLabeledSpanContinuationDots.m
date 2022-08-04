individual = false;
% when individual is false, there will only be dots at the beginning and end of the initial / final span rather than in
% between (unless continuationDots is passed as true(3, 2) ).

clf;

t = linspace(0, 6*pi, 400)';
plot(t, [cos(t), sin(t)], '-', 'LineWidth', 3);
xlim([0 6*pi]);
ylim([-1 1]);
axis tight;

ax = gca;
ax.XTick = 0:pi/2:6*pi;
ax.YTick = -1:1/6:1;

ax.XDir = 'reverse';
ax.YDir = 'reverse';

% continuationDots = [true, true];
continuationDots = true(3, 2);
spanPadding = [0.1 0.1];
aa = AutoAxis();

if individual
    aa.addLabeledSpan('x', span=[0*pi 2*pi], label="phase 1", labelColor='k', color=[0.8 0.2 0.2], ...
        continuationDots=continuationDots, spanPadding=spanPadding);
    aa.addLabeledSpan('x', span=[2*pi 4*pi], label="phase 2", labelColor='k', color=[0.2 0.8 0.2], ...
        continuationDots=continuationDots, spanPadding=spanPadding);
    aa.addLabeledSpan('x', span=[4*pi 6*pi], label="phase 3", labelColor='k', color=[0.2 0.2 0.8], ...
        continuationDots=continuationDots, spanPadding=spanPadding);
else
    aa.addLabeledSpan('x', span=[0*pi 2*pi; 2*pi 4*pi; 4*pi 6*pi]', label=["phase 1", "phase 2", "phase 3"], labelColor='k', color=[0.8 0.2 0.2; 0.2 0.8 0.2; 0.2 0.2 0.8], ...
        continuationDots=continuationDots, spanPadding=spanPadding);
end

if individual
    aa.addLabeledSpan('y', span=[-1 -1/3], label="low amp", labelColor='k', color=[1 0.64 0], ...
        rotation=90, continuationDots=continuationDots, spanPadding=spanPadding, rotation=90);
    aa.addLabeledSpan('y', span=[-1/3 1/3], label="mid amp", labelColor='k', color=[1 0.64 0.5], ...
        rotation=90, continuationDots=continuationDots, spanPadding=spanPadding, rotation=90);
    aa.addLabeledSpan('y', span=[1/3 1], label="high amp", labelColor='k', color=[1 0.64 1], ...
        rotation=90, continuationDots=continuationDots, spanPadding=spanPadding, rotation=90);
else
    aa.addLabeledSpan('y', span=[-1 -1/3; -1/3 1/3; 1/3 1]', label=["low amp", "mid amp", "high amp"], labelColor='k', color=[1 0.64 0; 1 0.64 0.5; 1 0.64 1], ...
        continuationDots=continuationDots, spanPadding=spanPadding, rotation=90);
end

grid on;

aa.update();