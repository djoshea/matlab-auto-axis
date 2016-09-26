classdef AutoAxisDefaults
    methods(Static)
        function reset()
            setenv('AutoAxis_TickLength', '0.05');
            setenv('AutoAxis_TickLineWidth', '0.5'); % not in centimeters, this is stroke width
            setenv('AutoAxis_MarkerWidth', '0.0706');
            setenv('AutoAxis_MarkerHeight', '0.12');
            setenv('AutoAxis_MarkerCurvature', '0');
            setenv('AutoAxis_IntervalThickness', '0.1');
            setenv('AutoAxis_ScaleBarThickness', '0.08'); % scale bars should be thinner than intervals since they sit on top
            setenv('AutoAxis_TickLabelOffset', '0.1');
            setenv('AutoAxis_MarkerLabelOffset', '0.1'); % cm

            setenv('AutoAxis_DefaultPadding', '');
            setenv('AutoAxis_DefaultMargins', ''); 
        end
    end
end