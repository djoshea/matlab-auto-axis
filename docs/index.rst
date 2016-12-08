.. MATLAB Sphinx Documentation Test documentation master file, created by
   sphinx-quickstart on Wed Jan 15 11:38:03 2014.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

AutoAxis Documentation
============================================================

.. toctree::
   :maxdepth: 4

.. .. currentmodule:: autoaxis

.. _AutoAxis:

AutoAxis
===========

AutoAxis is a Matlab library for drawing custom axis decorations to 2D figure axes. AutoAxis attaches to an axis and provides many pre-built decorations such as:

  * despined axes tick marks (which are offset from the axis box by a fixed distance) which automaticaly update with the axis limits and major tick marks.
  * scale bars along the X and Y axis labeled with custom units.
  * labeled markers along the axis, e.g. for identifying key timepoints on a time axis
  * labeled spans and intervals to identify groups of plotted items, such as vertically stacked timeseries or trials in a spike raster.

Each of these high-level pre-configured decorations are built using AutoAxis's low level functionality, which is also accessible directly to the user. AutoAxis allows the user to specify a set of `anchors` that should be maintained as the figure is resized or the axes zoomed or panned. Some examples of anchors:

  * The top edge of a text box should be located 1.5 mm below the bottom edge of the axis
  * The width of a rectangle should be 4 mm
  * The right edge of a line should be located 2 mm left of the left edge of the axis
  * The vertical center of a line marker (``'o'``) should be located 3 mm below the bottom of the axis.

All offsets, sizes, and positions are specified directly in paper units, in centimeters, and AutoAxis takes care of adjusting the positions of everything on the axis to match these paper units. This facilitates an extraordinary degree of consistency across generated figures.

AutoAxis prefers explicit settings over automagically determined offsets and spacing. Matlab axes by default will adjust to accommodate tick marks and axis labels, which can be convenient for a single axis but can create inconsistencies and misalignment when multiple plots are combined in a single figure. AutoAxis allows the user to manually specify the margins and padding around each axis, although reasonable defaults are provided. All defaults can be either using the default Matlab ``set(groot, 'Default...', ...)`` mechanism or specified as environment variables (using ``setenv``).

.. .. autoclass:: AutoAxis
..     :show-inheritance:
..     :members:

.. _TestBookmark:

AutoAxis Package
----------------

.. automodule:: autoaxis.+AutoAxis

.. autoclass:: PositionType
  :show-inheritance:
  :member-order: bysource
  :members:


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
