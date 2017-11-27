classdef AnchorInfo < handle & matlab.mixin.Copyable
    properties
        desc = ''; % description for debugging purposes
        
        valid = true;
        
        h % handle or vector of handles of object(s) to position
        ha % handle or vector of handles of object(s) to serve as anchor
        
        pos % AutoAxisPositionType value for this object
        posa % AutoAxisPositionType value or numerical scalar in paper units
        
        margin % gap between h point and anchor point in paper units, can be string if expression
        
        % indicates whether to 
        translateDontScale = true;
        %data % scalar value indicating the data coordinate used when posAnchro is Data
        
        % instead of moving the whole line object, position specific points
        % directly within a line
        applyToPointsWithinLine = [];
    end  
    
%     properties(Hidden, SetAccess=?AutoAxis)
%         % boolean flag for internal use. when pos is Height or Width,
%         % indicates what should be fixed when scaling the height or width
%         % e.g. if posScaleFixed is Top, the height should be changed by
%         % moving the bottom down, keeping the Top fixed
%         posScaleFixed
%     end
    
    properties(Dependent)
        isHandleH % boolean: true if h should be treated as a handle or handle vector directly (as opposed to a handle tag string or literal value)
        isHandleHa % boolean: true if ha should be treated as a handle directly (as opposed to a handle tag string or literal value)
    end
    
    methods
        function ai = AnchorInfo(varargin)
            p = inputParser;
            validatePos = @(x) isempty(x) || isa(x, 'AutoAxis.PositionType') || isscalar(x) || ischar(x) || isa(x, 'function_handle');
            p.addOptional('h', [], @(x) isvector(x) || isempty(x)); % this may be a vector
            p.addOptional('pos', [], validatePos);
            p.addOptional('ha', [], @(x) isvector(x) || isempty(x));
            p.addOptional('posa', [], validatePos);
            p.addOptional('margin', 0, @(x) ischar(x) || isscalar(x) || isa(x, 'function_handle'));
            p.addOptional('desc', '', @ischar);
            p.addParameter('translateDontScale', true, @islogical);
            p.parse(varargin{:});
            ai.h = p.Results.h;
            ai.pos = p.Results.pos;
            ai.ha = p.Results.ha;
            ai.posa = p.Results.posa;
            ai.margin = p.Results.margin;
            ai.desc = p.Results.desc;
            ai.translateDontScale = p.Results.translateDontScale;
        end
    end
    
    methods
        function tf = get.isHandleH(info)
            tf = ~isempty(info.h) && all(~ischar(info.h)) && ~iscellstr(info.h) && info.pos ~= AutoAxis.PositionType.Literal;
        end
        
        function tf = get.isHandleHa(info)
             tf = ~isempty(info.ha) && all(~ischar(info.ha)) && ~iscellstr(info.ha) && info.posa ~= AutoAxis.PositionType.Literal;
        end
        
        function h = get.h(info)
            h = AutoAxisUtilities.makecol(info.h);
        end
        
        function ha = get.ha(info)
            ha = AutoAxisUtilities.makecol(info.ha);
        end
        
        function tf = specifiesPosition(info, pos)
            import AutoAxis.PositionType;
            posvec = [info.pos];
            tf = posvec == pos | posvec == pos.flip() | ...
                (pos == PositionType.HCenter & posvec.isX() & ~posvec.specifiesSize()) | ...
                (pos == PositionType.VCenter & posvec.isY() & ~posvec.specifiesSize());
        end
    end
        
end

    
    
