clf;

x = 0:20;

rng(1);
y = rand(size(x)) > 0.3;

plot(x, y, '-');

mask = y;

color = hex2rgb('2596be');

aa = AutoAxis();
aa.addColorStrip("x", position=x, indicator=~mask, Color=color);
aa.addColorStrip("x", position=x, indicator=mask, Color=color, otherSide=true);

aa.update();