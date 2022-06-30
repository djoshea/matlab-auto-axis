clf;

x = linspace(0, 2*pi, 20);
y = sin(x);

plot(x, y, '-');

xlim([-0.5 2*pi+0.5]);
ylim([-1.5 1.5]);

aa = AutoAxis();
aa.addColorStrip("x", position=x, values=y, uniformSpacing=true);
aa.addColorStrip("x", position=x, values=-y, otherSide=true, uniformSpacing=false);

yy = linspace(-1, 1, 10);
xx = abs(yy);
aa.addColorStrip("y", position=yy, values=xx);
aa.addColorStrip("y", position=yy, values=-xx, otherSide=true, uniformSpacing=false);
aa.axisMargin = 0.5*scale;
aa.update();