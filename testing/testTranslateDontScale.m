clf;

import AutoAxis.AnchorInfo;
import AutoAxis.PositionType;

% keep the borders of a rectangle 1 cm from the edges of the axis
h = rectangle('Position', [0 0 1 1], 'FaceColor', [0.8 0.2 0.2], 'XLimInclude', 'off', 'YLimInclude', 'off');
hold on;
ax = AutoAxis;
a1 = AnchorInfo(h, PositionType.Top, gca, PositionType.Top, -1);
a2 = AnchorInfo(h, PositionType.Bottom, gca, PositionType.Bottom, -1);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

a1 = AnchorInfo(h, PositionType.Left, gca, PositionType.Left, -1);
a2 = AnchorInfo(h, PositionType.Right, gca, PositionType.Right, -1);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

% specify the positioning in the opposite order to test the other way
h = rectangle('Position', [0 0 1 1], 'FaceColor', [0.2 0.2 0.8], 'XLimInclude', 'off', 'YLimInclude', 'off');
hold on;
ax = AutoAxis;
a1 = AnchorInfo(h, PositionType.Bottom, gca, PositionType.Bottom, -2);
a2 = AnchorInfo(h, PositionType.Top, gca, PositionType.Top, -2);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

a1 = AnchorInfo(h, PositionType.Right, gca, PositionType.Right, -2);
a2 = AnchorInfo(h, PositionType.Left, gca, PositionType.Left, -2);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

% test the original with a line
h = plot([0 0 1 1 0], [0 1 1 0 0], 'k-', 'LineWidth', 2, 'XLimInclude', 'off', 'YLimInclude', 'off');
hold on;
ax = AutoAxis;
a1 = AnchorInfo(h, PositionType.Top, gca, PositionType.Top, -3);
a2 = AnchorInfo(h, PositionType.Bottom, gca, PositionType.Bottom, -3);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

a1 = AnchorInfo(h, PositionType.Left, gca, PositionType.Left, -3);
a2 = AnchorInfo(h, PositionType.Right, gca, PositionType.Right, -3);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

% test line positioning in the opposite order
h = plot([0 0 1 1 0], [0 1 1 0 0], '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 2, 'XLimInclude', 'off', 'YLimInclude', 'off');
hold on;
ax = AutoAxis;
a1 = AnchorInfo(h, PositionType.Bottom, gca, PositionType.Bottom, -4);
a2 = AnchorInfo(h, PositionType.Top, gca, PositionType.Top, -4);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

a1 = AnchorInfo(h, PositionType.Right, gca, PositionType.Right, -4);
a2 = AnchorInfo(h, PositionType.Left, gca, PositionType.Left, -4);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

% keep the borders of a green rectangle 1 cm within the gray rectangle
hsurround = h;
h = rectangle('Position', [0 0 1 1], 'FaceColor', [0.2 0.8 0.2], 'XLimInclude', 'off', 'YLimInclude', 'off', 'EdgeColor', 'w');
hold on;
ax = AutoAxis;
a1 = AnchorInfo(h, PositionType.Top, hsurround, PositionType.Top, -1);
a2 = AnchorInfo(h, PositionType.Bottom, hsurround, PositionType.Bottom, -1);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

a1 = AnchorInfo(h, PositionType.Left, hsurround, PositionType.Left, -1);
a2 = AnchorInfo(h, PositionType.Right, hsurround, PositionType.Right, -1);
a2.translateDontScale = false;
ax.addAnchor(a1);
ax.addAnchor(a2);

ax.update();