clf;

imagesc(randn(10, 10));
xlabel('xlabel');
ylabel('ylabel');
hc = colorbar;

% au = AutoAxis();
% au.axisMargin = 0;
% au.update();

ax = gca;
ax.Position
ax.OuterPosition
ax.LooseInset
ax.TightInset