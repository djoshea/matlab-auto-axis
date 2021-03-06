classdef LocationCurrent < handle & matlab.mixin.Copyable
     % Specifed properties inferred from properties beginning with v*
     % or NaN if not specified
     
    properties(SetAccess=protected)
        h % graphics handle this refers to
        type % string type of graphics object
        isDynamic % should this position be re-queried on each update (false means trust the last position)
        top
        bottom
        left
        right
        
        markerDiameter
    end
    
    properties
        cachedInfo
    end
    
    properties(Dependent)
        vcenter
        height
        hcenter
        width
    end
    
    methods
        function v = get.vcenter(loc)
            v = (loc.top + loc.bottom) / 2;
        end
        
        function v = get.height(loc)
            v = abs(loc.top - loc.bottom);
        end
        
        function v = get.hcenter(loc)
            v = (loc.left + loc.right) / 2;
        end
        
        function v = get.width(loc)
            v = abs(loc.right - loc.left);
        end
    end
        
    methods(Static)
        function loc = buildForHandle(h, varargin)
            loc = AutoAxis.LocationCurrent();
            loc.h = h;
            if ~ishandle(h)
                return;
            end
            loc.type = get(h, 'Type');
            
            loc.isDynamic = strcmp(loc.type, 'axes') || strcmp(loc.type, 'text');

            loc.queryPosition(varargin{:});
        end
        
        function pos = getAggregateValue(infoVec, posType, xReverse, yReverse)
            % given a set of LocationSpec instances, determine the value of field that holds across all 
            % of the objects. E.g. if field is 'left', returns the minimum value of info.left for all info in infoVec
            % posType is AutoAxis.PositionType

            import AutoAxis.PositionType;
            import AutoAxis.LocationCurrent;
            
            field = posType.getDirectField();
            if numel(infoVec) == 1
                pos = infoVec.(field);
                return;
            end

            % compute derivative positions recursively
            pos = [];
            switch posType
                case PositionType.VCenter
                    top = LocationCurrent.getAggregateValue(infoVec, PositionType.Top, xReverse, yReverse);
                    bottom = LocationCurrent.getAggregateValue(infoVec, PositionType.Bottom, xReverse, yReverse);
                    pos = (top+bottom)/2;

                case PositionType.Height
                    top = LocationCurrent.getAggregateValue(infoVec, PositionType.Top, xReverse, yReverse);
                    bottom = LocationCurrent.getAggregateValue(infoVec, PositionType.Bottom, xReverse, yReverse);
                    pos = top - bottom;

                case PositionType.HCenter
                    left = LocationCurrent.getAggregateValue(infoVec, PositionType.Left, xReverse, yReverse);
                    right = LocationCurrent.getAggregateValue(infoVec, PositionType.Right, xReverse, yReverse);
                    pos = (left+right)/2;

                case PositionType.Width
                    left = LocationCurrent.getAggregateValue(infoVec, PositionType.Left, xReverse, yReverse);
                    right = LocationCurrent.getAggregateValue(infoVec, PositionType.Right, xReverse, yReverse);
                    pos = right - left;
            end
            if ~isempty(pos), return; end

            % find max or min over all values
            posVec = arrayfun(@(info) double(info.(field)), infoVec);
            switch posType
                case PositionType.Top
                    if yReverse
                        pos = nanmin(posVec);
                    else
                        pos = nanmax(posVec);
                    end
                case PositionType.Bottom
                    if yReverse
                        pos = nanmax(posVec);
                    else
                        pos = nanmin(posVec);
                    end
                case PositionType.Left
                    if xReverse
                        pos = nanmax(posVec);
                    else
                        pos = nanmin(posVec);
                    end
                case PositionType.Right
                    if xReverse
                        pos = nanmin(posVec);
                    else
                        pos = nanmax(posVec);
                    end
                case PositionType.MarkerDiameter
                    pos = nanmax(posVec);
            end
        end
    end
    
    methods
        function queryPosition(loc, xDataToPoints, yDataToPoints, xReverse, yReverse)
            % xReverse is true if x axis is reversed, yReverse if y
            % reversed
            
            if ~isvalid(loc.h)
                warning('Invalid handle');
                return;
            end
            
            switch loc.type
                case 'line'
                    marker = get(loc.h, 'Marker');
                    markerDiameterPoints =get(loc.h, 'MarkerSize');
                    if(strcmp(marker, '.'))
                        markerDiameterPoints = markerDiameterPoints * 3.4;
                    end
                    if strcmp(marker, 'none')
                        markerDiameterPoints = 0;
                    end
                    % convert marker to data coordinates
                    markerSizeX = markerDiameterPoints / xDataToPoints;
                    markerSizeY = markerDiameterPoints / yDataToPoints;
                    loc.markerDiameter = markerDiameterPoints;
                    
                    xdata = get(loc.h, 'XData');
                    ydata = get(loc.h, 'YData');

                    loc.top = nanmax(ydata) + markerSizeY/2;
                    loc.bottom = nanmin(ydata) - markerSizeY/2;
                    loc.left = nanmin(xdata) - markerSizeX/2;
                    loc.right = nanmax(xdata) + markerSizeX/2;
                    
                    if xReverse
                        tmp = loc.left;
                        loc.left = loc.right;
                        loc.right = tmp;
                    end
                    if yReverse
                        tmp = loc.top;
                        loc.top = loc.bottom;
                        loc.bottom = tmp;
                    end
                    
                case 'scatter'
                    
                    % convert marker to data coordinates
                    xdata = loc.h.XData;
                    ydata = loc.h.YData;
                    szdata = loc.h.SizeData; % in pts^2
                    markerRadiusY = sqrt(szdata / pi) / yDataToPoints;
                    markerRadiusX = sqrt(szdata / pi) / xDataToPoints;

                    loc.top = nanmax(ydata + markerRadiusY);
                    loc.bottom = nanmin(ydata - markerRadiusY);
                    loc.left = nanmin(xdata - markerRadiusX);
                    loc.right = nanmax(xdata + markerRadiusX);
                    
                    if xReverse
                        tmp = loc.left;
                        loc.left = loc.right;
                        loc.right = tmp;
                    end
                    if yReverse
                        tmp = loc.top;
                        loc.top = loc.bottom;
                        loc.bottom = tmp;
                    end
                    
                case 'patch'
                    data = get(loc.h, 'Vertices');
                    xdata = data(:, 1);
                    ydata = data(:, 2);
                    
                    loc.top = nanmax(ydata);
                    loc.bottom = nanmin(ydata);
                    loc.left = nanmin(xdata);
                    loc.right = nanmax(xdata);
                    
                    if xReverse
                        tmp = loc.left;
                        loc.left = loc.right;
                        loc.right = tmp;
                    end
                    if yReverse
                        tmp = loc.top;
                        loc.top = loc.bottom;
                        loc.bottom = tmp;
                    end

                case 'text'
                    set(loc.h, 'Units', 'data');
                    ext = get(loc.h, 'Extent'); % [left,bottom,width,height]
                    if yReverse
                        loc.bottom = ext(2);
                        loc.top = ext(2) - ext(4);
                    else
                        loc.top = ext(2) + ext(4);
                        loc.bottom = ext(2);
                    end
                    if xReverse
                        loc.left = ext(1);
                        loc.right = ext(1) - ext(3);
                    else
                        loc.left = ext(1);
                        loc.right = ext(1) + ext(3);
                    end

                case 'axes'
                    % return the limits of the axis...i.e. the coordinates
                    % of the inner position of the axis in data units
                    lim = axis(loc.h);
                    loc.top = lim(4);
                    loc.bottom = lim(3);
                    loc.left = lim(1);
                    loc.right = lim(2);
                    
                    if xReverse
                        tmp = loc.left;
                        loc.left = loc.right;
                        loc.right = tmp;
                    end
                    if yReverse
                        tmp = loc.top;
                        loc.top = loc.bottom;
                        loc.bottom = tmp;
                    end
                    
                case 'rectangle'
                    posv = get(loc.h, 'Position');
                    if yReverse
                        loc.top = posv(2);
                        loc.bottom = posv(2) - posv(4);
                    else
                        loc.bottom = posv(2);
                        loc.top = posv(2) + posv(4);
                    end
                    
                    if xReverse
                        loc.right = posv(1);
                        loc.left = posv(1) - posv(3);
                    else
                        loc.left = posv(1);
                        loc.right = posv(1) + posv(3);
                    end
                    
                case 'image'
                    xdata = get(loc.h, 'XData');
                    ydata = get(loc.h, 'YData');
                    
                    cdata = get(loc.h, 'CData');
                    nX = size(cdata, 2);
                    if isscalar(xdata)
                        if nX == 1
                            % each tile is 1 wide
                            xdata(2) = xdata(1); 
                            padX = 0.5;
                        else
                            % each tile is 1 wide
                            xdata(2) = xdata(1) + (nX-1);
                            padX = 0.5;
                        end
                    else
                        xdata = xdata([1 end]);
                        if nX == 1
                            % each tile is 3 * diff(xdata)
                            padX = xdata(2) - xdata(1);
                        else
                            % xdata spans the centers of the edge tiles
                            padX = (xdata(end) - xdata(1)) / (nX - 1) / 2; 
                        end
                    end
                    
                    nY = size(cdata, 1);
                    if isscalar(ydata)
                        if nY == 1
                            ydata(2) = ydata(1); 
                            padY = 0.5;
                        else
                            ydata(2) = ydata(1) + (nY-1);
                            padY = 0.5;
                        end
                    else
                        ydata = ydata([1 end]);
                        if nY == 1
                            padY = ydata(2) - ydata(1);
                        else
                            padY = (ydata(2) - ydata(1)) / (nY - 1) / 2; 
                        end
                    end
                    
                    % correct for the half pixel offset
                    xdata(1) = xdata(1) - padX;
                    xdata(2) = xdata(2) + padX;
                    ydata(1) = ydata(1) - padY;
                    ydata(2) = ydata(2) + padY;
                    
                    if yReverse
                        loc.top = ydata(1);
                        loc.bottom = ydata(2);
                    else
                        loc.top = ydata(2);
                        loc.bottom = ydata(1);
                    end
                    if xReverse
                        loc.right = xdata(1);
                        loc.left = ydata(2);
                    else
                        loc.right = xdata(2);
                        loc.left = xdata(1);
                    end
                otherwise
                    error('Unknown handle type %s', loc.type);
            end
            
            
        end

        function success = setPosition(loc, posType, value, xDataToPoints, yDataToPoints, xReverse, yReverse, translateDontScale, applyToPointsWithinLine)
            import AutoAxis.*;
            h = loc.h; %#ok<*PROP>
            type = get(h, 'Type');

            if ~exist('applyToPointsWithinLine', 'var')
                applyToPointsWithinLine = [];
            end
            
            success = false;
            switch type
                case 'line'
                    marker = get(h, 'Marker');
                    markerDiameterPoints = get(h, 'MarkerSize');
                    if(strcmp(marker, '.'))
                        markerDiameterPoints = markerDiameterPoints * 3.4;
                    end
                    if posType == PositionType.MarkerDiameter
                        % if we're about to update the marker size, we should 
                        % use the new value in computing the location of
                        % the plot
                        markerDiameterPoints = value * yDataToPoints;
                    end
                    if strcmp(marker, 'none')
                        markerDiameterPoints = 0;
                    end
                    markerSizeX = markerDiameterPoints / xDataToPoints;
                    markerSizeY = markerDiameterPoints / yDataToPoints;
                    
                    if posType == PositionType.MarkerDiameter
                        markerSizeX = value;
                        markerSizeY = value;
                    end
                    setMarkerSize = false;

                    xdata = get(h, 'XData');
                    ydata = get(h, 'YData');

                    if isempty(applyToPointsWithinLine)
                        % rescale the appropriate data points from their
                        % current values to scale linearly onto the new values
                        % but only along the dimension to be resized
                        switch posType
                            case PositionType.Top
                                if translateDontScale
                                    if yReverse
                                        ydata = ydata - nanmin(ydata) + value + markerSizeY/2;
                                    else
                                        ydata = ydata - nanmax(ydata) + value - markerSizeY/2;
                                    end
                                else
                                    % scale to keep current bottom
                                    if yReverse
                                        bottom = nanmax(ydata) + markerSizeY/2;
                                        top = nanmin(ydata) - markerSizeY/2;
                                    else
                                        top = nanmax(ydata) + markerSizeY/2;
                                        bottom = nanmin(ydata) - markerSizeY/2;
                                    end
                                    scale = (bottom-top) / (bottom-value);
                                    ydata = (ydata - bottom) / scale + bottom;
                                end

                            case PositionType.Bottom
                                if translateDontScale
                                    if yReverse
                                        ydata = ydata - nanmax(ydata) + value - markerSizeY/2;
                                    else
                                        ydata = ydata - nanmin(ydata) + value + markerSizeY/2;
                                    end
                                else
                                    % scale to keep current top
                                    if yReverse
                                        bottom = nanmax(ydata) + markerSizeY/2;
                                        top = nanmin(ydata) - markerSizeY/2;
                                    else
                                        top = nanmax(ydata) + markerSizeY/2;
                                        bottom = nanmin(ydata) - markerSizeY/2;
                                    end
                                    scale = (bottom-top) / (value-top);
                                    ydata = (ydata - top) / scale + top;
                                end

                            case PositionType.VCenter
                                lo = nanmin(ydata); hi = nanmax(ydata);
                                ydata = (ydata - (hi+lo)/2) + value;

                            case PositionType.Height
                                lo = nanmin(ydata); hi = nanmax(ydata); mid = (lo+hi) / 2;
                                if hi - lo < eps, return, end
                                if numel(ydata) == 1
                                    return
                                end % can't change height of single point
                                ydata = (ydata - mid) / (hi - lo + markerSizeY) * value + mid;

                            case PositionType.Left
                                if translateDontScale
                                    if xReverse
                                        xdata = xdata - nanmax(xdata) + value - markerSizeX/2;
                                    else
                                        xdata = xdata - nanmin(xdata) + value + markerSizeX/2;
                                    end
                                else
                                    % scale to keep current right
                                    if xReverse
                                        left = nanmax(xdata) + markerSizeX/2;
                                        right = nanmin(xdata) - markerSizeX/2;
                                    else
                                        left = nanmin(xdata) + markerSizeX/2;
                                        right = nanmax(xdata) - markerSizeX/2;
                                    end
                                    scale = (left-right) / (value-right);
                                    xdata = (xdata-right) / scale + right;
                                end 

                            case PositionType.Right
                                if translateDontScale
                                    if xReverse
                                        xdata = xdata - nanmin(xdata) + value + markerSizeX/2;
                                    else
                                        xdata = xdata - nanmax(xdata) + value - markerSizeX/2;
                                    end
                                else
                                    % scale to keep current left
                                    if xReverse
                                        left = nanmax(xdata) + markerSizeX/2;
                                        right = nanmin(xdata) - markerSizeX/2;
                                    else
                                        left = nanmin(xdata) + markerSizeX/2;
                                        right = nanmax(xdata) - markerSizeX/2;
                                    end
                                    scale = (left-right) / (left-value);
                                    xdata = (xdata-left) / scale + left;
                                end

                            case PositionType.HCenter
                                lo = nanmin(xdata); hi = nanmax(xdata);
                                xdata = (xdata - (hi+lo)/2) + value;

                            case PositionType.Width
                                lo = nanmin(xdata); hi = nanmax(xdata); mid = (lo+hi)/2;
                                if hi - lo < eps, return, end
                                if numel(xdata) == 1, return, end % can't change width of single point
                                xdata = (xdata - mid) / (hi - lo + markerSizeX) * value + mid;

                            otherwise
                                error('PositionType %s not supported for scatter', posType);
                        end
                    else
                        % position specific point within line
                        m = applyToPointsWithinLine;
                        switch posType
                            case PositionType.Top
                                if yReverse
                                    ydata(m) = value + markerSizeY/2;
                                else
                                    ydata(m) = value - markerSizeY/2;
                                end
                                
                            case PositionType.Bottom
                                if yReverse
                                    ydata(m) = value - markerSizeY/2;
                                else
                                    ydata(m) = value + markerSizeY/2;
                                end
                                
                            case PositionType.VCenter
                                ydata(m) = value;

                            case PositionType.Left
                                if xReverse
                                    xdata(m) = value - markerSizeX/2;
                                else
                                    xdata(m) = value + markerSizeX/2;
                                end

                            case PositionType.Right
                                if xReverse
                                    xdata(m) = value + markerSizeX/2;
                                else
                                    xdata(m) = value - markerSizeX/2;
                                end
                                
                            case PositionType.HCenter
                                xdata(m) = value;
                                
                            case PositionType.MarkerDiameter
                                markerSize = markerDiameterPoints;
                                if(strcmp(marker, '.'))
                                    % for ., the size is the diameter
                                    markerSize = markerSize * 3.4;
                                elseif strcmp(marker, 'none')
                                    markerSize = 0;
                                end 
                                setMarkerSize = true;
                            otherwise
                                error('PositionType %s not supported for applyToPointsWithinLine', posType);
                        end
                    end

                    set(h, 'XData', xdata, 'YData', ydata); %#ok<*PROPLC>
                    if setMarkerSize && markerSize > 0
                        set(h, 'MarkerSize', markerSize);
                    end
                    success = true;
                    
                    % update position based on new settings, including
                    % marker sizes
                    if xReverse
                        loc.right = nanmin(xdata) - markerSizeX/2;
                        loc.left = nanmax(xdata) + markerSizeX/2;
                    else
                        loc.left = nanmin(xdata) - markerSizeX/2;
                        loc.right = nanmax(xdata) + markerSizeX/2;
                    end
                    
                    if yReverse
                        loc.bottom = nanmax(ydata) + markerSizeY/2;
                        loc.top = nanmin(ydata) - markerSizeY/2;
                    else
                        loc.top = nanmax(ydata) + markerSizeY/2;
                        loc.bottom = nanmin(ydata) - markerSizeY/2;
                    end
                    
                case 'scatter'
                    xdata = get(h, 'XData');
                    ydata = get(h, 'YData');
                    szdata = get(h, 'SizeData');
                    markerSizeY = 2 * sqrt(szdata / pi) / yDataToPoints; % diameter of marker
                    markerSizeX = 2 * sqrt(szdata / pi) / xDataToPoints;
                    
                    % rescale the appropriate data points from their
                    % current values to scale linearly onto the new values
                    % but only along the dimension to be resized
                    switch posType
                        case PositionType.Top
                            if translateDontScale
                                if yReverse
                                    ydata = ydata - nanmin(ydata - markerSizeY/2) + value; % sign arrangement is different because we consider the individual marker sizes inside the min
                                else
                                    ydata = ydata - nanmax(ydata + markerSizeY/2) + value;
                                end
                            else
                                % scale to keep current bottom
                                if yReverse
                                    bottom = nanmax(ydata + markerSizeY/2);
                                    top = nanmin(ydata - markerSizeY/2);
                                else
                                    top = nanmax(ydata + markerSizeY);
                                    bottom = nanmin(ydata - markerSizeY/2);
                                end
                                scale = (bottom-top) / (bottom-value);
                                ydata = (ydata - bottom) / scale + bottom;
                            end

                        case PositionType.Bottom
                            if translateDontScale
                                if yReverse
                                    ydata = ydata - nanmax(ydata + markerSizeY/2) + value;
                                else
                                    ydata = ydata - nanmin(ydata - markerSizeY/2) + value;
                                end
                            else
                                % scale to keep current top
                                if yReverse
                                    bottom = nanmax(ydata + markerSizeY/2);
                                    top = nanmin(ydata - markerSizeY/2);
                                else
                                    top = nanmax(ydata + markerSizeY/2);
                                    bottom = nanmin(ydata - markerSizeY/2);
                                end
                                scale = (bottom-top) / (value-top);
                                ydata = (ydata - top) / scale + top;
                            end

                        case PositionType.VCenter
                            lo = nanmin(ydata); hi = nanmax(ydata);
                            ydata = (ydata - (hi+lo)/2) + value;

                        case PositionType.Height
                            lo = nanmin(ydata); hi = nanmax(ydata); mid = (lo+hi) / 2;
                            if hi - lo < eps, return, end
                            if numel(ydata) == 1
                                return
                            end % can't change height of single point
                            ydata = (ydata - mid) / (hi - lo + markerSizeY) * value + mid;

                        case PositionType.Left
                            if translateDontScale
                                if xReverse
                                    xdata = xdata - nanmax(xdata + markerSizeX/2) + value;
                                else
                                    xdata = xdata - nanmin(xdata - markerSizeX/2) + value;
                                end
                            else
                                % scale to keep current right
                                if xReverse
                                    left = nanmax(xdata + markerSizeX/2);
                                    right = nanmin(xdata - markerSizeX/2);
                                else
                                    left = nanmin(xdata + markerSizeX/2);
                                    right = nanmax(xdata - markerSizeX/2);
                                end
                                scale = (left-right) / (value-right);
                                xdata = (xdata-right) / scale + right;
                            end 

                        case PositionType.Right
                            if translateDontScale
                                if xReverse
                                    xdata = xdata - nanmin(xdata - markerSizeX/2) + value;
                                else
                                    xdata = xdata - nanmax(xdata + markerSizeX/2) + value;
                                end
                            else
                                % scale to keep current left
                                if xReverse
                                    left = nanmax(xdata + markerSizeX/2);
                                    right = nanmin(xdata - markerSizeX/2);
                                else
                                    left = nanmin(xdata + markerSizeX/2);
                                    right = nanmax(xdata - markerSizeX/2);
                                end
                                scale = (left-right) / (left-value);
                                xdata = (xdata-left) / scale + left;
                            end

                        case PositionType.HCenter
                            lo = nanmin(xdata); hi = nanmax(xdata);
                            xdata = (xdata - (hi+lo)/2) + value;

                        case PositionType.Width
                            lo = nanmin(xdata); hi = nanmax(xdata); mid = (lo+hi)/2;
                            if hi - lo < eps, return, end
                            if numel(xdata) == 1, return, end % can't change width of single point
                            xdata = (xdata - mid) / (hi - lo + markerSizeX) * value + mid;
                            
                       otherwise
                                error('PositionType %s not supported for applyToPointsWithinLine', posType);
                            
                    end

                    set(h, 'XData', xdata, 'YData', ydata); %#ok<*PROPLC>
                    success = true;
                    
                    % update position based on new settings, including
                    % marker sizes
                    if xReverse
                        loc.right = nanmin(xdata - markerSizeX/2);
                        loc.left = nanmax(xdata + markerSizeX/2);
                    else
                        loc.left = nanmin(xdata - markerSizeX/2);
                        loc.right = nanmax(xdata + markerSizeX/2);
                    end
                    
                    if yReverse
                        loc.bottom = nanmax(ydata + markerSizeY/2);
                        loc.top = nanmin(ydata - markerSizeY/2);
                    else
                        loc.top = nanmax(ydata + markerSizeY/2);
                        loc.bottom = nanmin(ydata - markerSizeY/2);
                    end
                    
                case 'patch'
                    data = get(h, 'Vertices');
                    xdata = data(:, 1);
                    ydata = data(:, 2);
                    
                    % rescale the appropriate data points from their
                    % current to scale linearly onto the new values
                    % but only along the dimension to be resized
                    switch posType
                        case PositionType.Top
                            if translateDontScale
                                if yReverse
                                    ydata = ydata - nanmin(ydata) + value;
                                else
                                    ydata = ydata - nanmax(ydata) + value;
                                end
                            else
                                % scale to keep current bottom
                                if yReverse
                                    bottom = nanmax(ydata);
                                    top = nanmin(ydata);
                                else
                                    top = nanmax(ydata);
                                    bottom = nanmin(ydata);
                                end
                                scale = (bottom-top) / (bottom-value);
                                ydata = (ydata - bottom) / scale + bottom;
                            end

                        case PositionType.Bottom
                            if translateDontScale
                                if yReverse
                                    ydata = ydata - nanmax(ydata) + value;
                                else
                                    ydata = ydata - nanmin(ydata) + value;
                                end
                            else
                                % scale to keep current top
                                if yReverse
                                    bottom = nanmax(ydata);
                                    top = nanmin(ydata);
                                else
                                    top = nanmax(ydata);
                                    bottom = nanmin(ydata);
                                end
                                scale = (bottom-top) / (value-top);
                                ydata = (ydata - top) / scale + top;
                            end

                        case PositionType.VCenter
                            lo = nanmin(ydata); hi = nanmax(ydata);
                            ydata = (ydata - (hi+lo)/2) + value;

                        case PositionType.Height
                            lo = nanmin(ydata); hi = nanmax(ydata); mid = (lo+hi) / 2;
                            if hi - lo < eps, return, end
                            ydata = (ydata - mid) / (hi - lo) * value + mid;

                        case PositionType.Left
                            if translateDontScale
                                if xReverse
                                    xdata = xdata - nanmax(xdata) + value;
                                else
                                    xdata = xdata - nanmin(xdata) + value;
                                end
                            else
                                % scale to keep current right
                                if xReverse
                                    left = nanmax(xdata);
                                    right = nanmin(xdata);
                                else
                                    left = nanmin(xdata);
                                    right = nanmax(xdata);
                                end
                                scale = (left-right) / (value-right);
                                xdata = (xdata-right) / scale + right;
                            end 

                        case PositionType.Right
                            if translateDontScale
                                if xReverse
                                    xdata = xdata - nanmin(xdata) + value;
                                else
                                    xdata = xdata - nanmax(xdata) + value;
                                end
                            else
                                % scale to keep current left
                                if xReverse
                                    left = nanmax(xdata);
                                    right = nanmin(xdata);
                                else
                                    left = nanmin(xdata);
                                    right = nanmax(xdata);
                                end
                                scale = (left-right) / (left-value);
                                xdata = (xdata-left) / scale + left;
                            end

                        case PositionType.HCenter
                            lo = nanmin(xdata); hi = nanmax(xdata);
                            xdata = (xdata - (hi+lo)/2) + value;

                        case PositionType.Width
                            lo = nanmin(xdata); hi = nanmax(xdata); mid = (lo+hi)/2;
                            if hi - lo < eps, return, end
                            xdata = (xdata - mid) / (hi - lo) * value + mid;
                    end

                    data = [xdata, ydata];
                    set(h, 'Vertices', data); %#ok<*PROPLC>
                    success = true;
                    
                    % update position based on new settings, including
                    % marker sizes
                    if xReverse
                        loc.right = nanmin(xdata);
                        loc.left = nanmax(xdata);
                    else
                        loc.left = nanmin(xdata);
                        loc.right = nanmax(xdata);
                    end
                    
                    if yReverse
                        loc.bottom = nanmax(ydata);
                        loc.top = nanmin(ydata);
                    else
                        loc.top = nanmax(ydata);
                        loc.bottom = nanmin(ydata);
                    end 
                   
                case 'text'
                    set(h, 'Units', 'data');
                    p = get(h, 'Position'); % [x y z] - ancor depends on alignment
                    ext = get(h, 'Extent'); % [left,bottom,width,height]
                    yoff = ext(2) - p(2);
                    xoff = ext(1) - p(1);
                    %m = get(h, 'Margin'); % margin in pixels
                    %mx = m / ax.xDataToPixels;
                    %my = m / ax.yDataToPixels;

                    switch posType
                        case PositionType.Top
                            if yReverse
                                p(2) = value + ext(4) - yoff;
                            else
                                p(2) = value - ext(4) - yoff;
                            end
                            
                        case PositionType.Bottom
                            p(2) = value - yoff;
                            
                        case PositionType.VCenter
                            if yReverse
                                p(2) = value + ext(4)/2 - yoff;
                            else
                                p(2) = value - ext(4)/2 - yoff;
                            end

                        case PositionType.Right
                            if xReverse
                                p(1) = value + ext(3) - xoff;
                            else
                                p(1) = value - ext(3) - xoff;
                            end
                            
                        case PositionType.Left
                            p(1) = value - xoff;
                            
                        case PositionType.HCenter
                            if xReverse
                                p(1) = value + ext(3)/2 - xoff;
                            else
                                p(1) = value - ext(3)/2 - xoff;
                            end
                    end

                    set(h, 'Position', p);
                    success = true;
                    
                    % update internal position
                    %ext = get(h, 'Extent'); % [left,bottom,width,height]
                    ext(1) = p(1) + xoff;
                    ext(2) = p(2) + yoff;
                    if yReverse
                        loc.bottom = ext(2);
                        loc.top = ext(2) - ext(4);
                    else
                        loc.bottom = ext(2);
                        loc.top = ext(2) + ext(4);
                    end
                    if xReverse
                        loc.left = ext(1);
                        loc.right = ext(1) - ext(3);
                    else
                        loc.left = ext(1);
                        loc.right = ext(1) + ext(3);
                    end
                    
                case 'rectangle'
                    p = get(h, 'Position'); % [left, bottom, width, height]

                    switch posType
                        case PositionType.Top
                            if translateDontScale
                                if yReverse
                                    p(2) = value;
                                else
                                    p(2) = value - p(4);
                                end
                            else
                                % scale to keep current bottom
                                if yReverse
                                    % bottom is p(2) + p(4);
                                    bottom = p(2) + p(4);
                                    p(2) = value;
                                    p(4) = bottom - value;
                                else
                                    % bottom is p(2)
                                    p(4) = value - p(2);
                                end
                            end
                        case PositionType.Bottom
                            if translateDontScale
                                if yReverse
                                    p(2) = value - p(4);
                                else
                                    p(2) = value;
                                end
                            else
                                % scale to keep current top
                                if yReverse
                                    % top is p(2)
                                    p(4) = value - p(2);
                                else
                                    % top is p(2) + p(4);
                                    top = p(2) + p(4);
                                    p(2) = value;
                                    p(4) = top - value;
                                end
                            end
                        case PositionType.VCenter
                            p(2) = value - p(4)/2;
                            
                        case PositionType.Height
                            % maintain vertical center
                            p(2) = (p(2) + p(4) / 2) - value/2;
                            p(4) = value;
                            
                        case PositionType.Right
                            if translateDontScale
                                if xReverse
                                    p(1) = value;
                                else
                                    p(1) = value - p(3);
                                end
                            else
                                % scale to keep current left
                                if xReverse
                                    % left is p(1) + p(3);
                                    right = p(1) + p(3);
                                    p(1) = value;
                                    p(3) = right- value;
                                else
                                    % left is p(1)
                                    p(3) = value - p(1);
                                end
                            end
                        case PositionType.Left
                            if translateDontScale
                                if xReverse
                                    p(1) = value - p(3);
                                else
                                    p(1) = value;
                                end
                            else
                                % scale to keep current bottom
                                if xReverse
                                    % right is p(1)
                                    p(3) = value - p(1);
                                else
                                    % right is p(1) + p(3);
                                    left = p(1) + p(3);
                                    p(1) = value;
                                    p(3) = left - value;
                                end
                            end
                        case PositionType.HCenter
                            p(1) = value - p(3)/2;
                            
                        case PositionType.Width
                            % maintain horizontal center
                            p(1) = (p(1) + p(3)/2) - value/2;
                            p(3) = value;
                            
                    end

                    % test for negative scaling
                    if p(3) < 0
                        p(1) = p(1) + p(3);
                        p(3) = -p(3);
                    end
                    
                    if p(4) < 0
                        p(2) = p(2) + p(4);
                        p(4) = -p(4);
                    end
                    set(h, 'Position', p);
                    success = true;
                    
                    h.Clipping = 'off';
                    if yReverse
                        loc.top = p(2);
                        loc.bottom = p(2) + p(4);
                    else
                        loc.top = p(2) + p(4);
                        loc.bottom = p(2);
                    end
                    
                    if xReverse
                        loc.left = p(1) + p(3);
                        loc.right = p(1);
                    else
                        loc.left = p(1);
                        loc.right = p(1) + p(3);
                    end
                    
                    
                case 'image'
                    % compute the current [xmin xmax] as xext, [ymin ymax] as yext, considering the current axes directions
                    if xReverse
                        xext = [loc.right loc.left];
                    else
                        xext = [loc.left loc.right];
                    end
                    if yReverse
                        yext = [loc.top loc.bottom];
                    else
                        yext = [loc.bottom loc.top];
                    end
                    
                    % then apply the desired position setting to these extents
                    switch posType
                        case PositionType.Top
                            if translateDontScale
                                if yReverse
                                    % top is yext(1)
                                    yext = yext - (yext(1) - value);
                                else
                                    yext = yext - (yext(2) - value);
                                end
                            else
                                if yReverse
                                    % top is yext(1)
                                    yext(1) = value;
                                else
                                    yext(2) = value;
                                end
                            end
                        case PositionType.Bottom
                            if translateDontScale
                                if yReverse
                                    % bottom is yext(2)
                                    yext = yext - (yext(2) - value);
                                else
                                    yext = yext - (yext(1) - value);
                                end
                            else
                                if yReverse
                                    % bottom is yext(2)
                                    yext(2) = value;
                                else
                                    yext(1) = value;
                                end
                            end
                        case PositionType.VCenter
                            yext = yext - (mean(yext) - value);
                            
                        case PositionType.Height
                            % maintain vertical center
                            yext = mean(yext) + [-value/2 value/2];
                            
                        case PositionType.Right
                            if translateDontScale
                                if xReverse
                                    % right is xext(1)
                                    xext = xext - (xext(1) - value);
                                else
                                    xext = xext - (xext(2) - value);
                                end
                            else
                                if xReverse
                                    % right is xext(1)
                                    xext(1) = value;
                                else
                                    xext(2) = value;
                                end
                            end
                        case PositionType.Left
                            if translateDontScale
                                if xReverse
                                    % left is xext(2)
                                    xext = xext - (xext(2) - value);
                                else
                                    xext = xext - (xext(1) - value);
                                end
                            else
                                if xReverse
                                    % left is xext(2)
                                    xext(2) = value;
                                else
                                    xext(1) = value;
                                end
                            end
                        case PositionType.HCenter
                            xext = xext - (mean(xext) - value);
                            
                        case PositionType.Width
                            % maintain horizontal center
                            xext = mean(xext) + [-value/2 value/2];
                            
                    end
                    
                    % assign the updated extents as the updated positions
                    if yReverse
                        loc.top = yext(1);
                        loc.bottom = yext(2);
                    else
                        loc.top = yext(2);
                        loc.bottom = yext(1);
                    end
                    if xReverse
                        loc.right = xext(1);
                        loc.left = yext(2);
                    else
                        loc.right = xext(2);
                        loc.left = xext(1);
                    end
                    
                    % now we query the image CData, which determines how the pixel xdata and ydata are mapped to pixel extents
                    cdata = get(h, 'CData');
                    nX = size(cdata, 2);
                    nY = size(cdata, 1);
                    
                    % compute the padding required from the extents to the min max xdata/ydata values
                    if nX == 1
                        % each tile is 3 * xdata_delta
                        padX = (xext(2) - xext(1)) / 3;
                    else
                        % xext spans the centers of the edge tiles
                        padX = (xext(2) - xext(1)) / nX / 2; 
                    end
                    
                    if nY == 1
                        padY = (yext(2) - yext(1)) / 3;
                    else
                        padY = (yext(2) - yext(1)) / nY / 2; 
                    end
                    
                    % now compute the desired XData and YData to achieve xext and yext, factoring in the padding
                    xdata = linspace(xext(1) + padX, xext(2) - padX, max(nX, 2));
                    ydata = linspace(yext(1) + padY, yext(2) - padY, max(nY, 2));
                    set(h, 'XData', xdata, 'YData', ydata, 'Clipping', 'off', 'XLimInclude', 'off', 'YLimInclude', 'off');
                    success = true;
                    
                otherwise
                    error('Unknown type %s', loc.type);
            end
            
        end
    end   
end
