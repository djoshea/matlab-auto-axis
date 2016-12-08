classdef TensorUtils
   methods(Static)
        function idxFull = indicesIntoMaskToOriginalIndices(idxIntoMasked, mask)
            maskInds = find(mask);
            idxFull = maskInds(idxIntoMasked);
        end

        function [out, which] = catWhich(dim, varargin)
            % works like cat, but returns a vector indicating which of the
            % inputs each element of out came from
            out = cat(dim, varargin{:});
            if nargout > 1
                which = cell2mat(AutoAxisUtilities.makecol(cellfun(@(in, idx) idx*ones(size(in, dim), 1), varargin, ...
                    num2cell(1:numel(varargin)), 'UniformOutput', false)));
            end
        end
    
        function [out, which] = catWhichIgnoreEmpty(dim, varargin)
            % works like cat, but returns a vector indicating which of the
            % inputs each element of out came from
            
            isEmpty = cellfun(@isempty, varargin);
            out = cat(dim, varargin{~isEmpty});
            if isempty(out)
                which = [];
                return;
            end
            if nargout > 1
                whichMasked = cell2mat(AutoAxisUtilities.makecol(cellfun(@(in, idx) idx*ones(size(in, dim), 1), varargin(~isEmpty), ...
                    num2cell(1:nnz(~isEmpty)), 'UniformOutput', false)));
                
                % whichMasked indexes into masked varargin, reset these to
                % index into the original varargin
                which = AutoAxis.TensorUtils.indicesIntoMaskToOriginalIndices(whichMasked, ~isEmpty);
            end
        end
    end
end
