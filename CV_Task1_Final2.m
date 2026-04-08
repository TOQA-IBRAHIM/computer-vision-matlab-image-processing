
classdef CV_Task1_Final2 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        Label                      matlab.ui.control.Label
        TechniqueDropDown_2        matlab.ui.control.DropDown
        TechniqueDropDown_2Label   matlab.ui.control.Label
        ParameterValueSlider       matlab.ui.control.Slider
        ParameterValueSliderLabel  matlab.ui.control.Label
        TypeDropDown               matlab.ui.control.DropDown
        TypeDropDownLabel          matlab.ui.control.Label
        LoadanImageButton          matlab.ui.control.Button
        UIAxes_2                   matlab.ui.control.UIAxes
        UIAxes                     matlab.ui.control.UIAxes
    end

    properties (Access = private)
        img % original image
    end

    methods (Access = private)

        % startup
        function startupFcn(app)
            app.TypeDropDown.Items = {'Enhancement', 'Spatial Filter', 'Frequency Filter', 'Color Conversion'};
            app.TypeDropDown.Value = 'Enhancement';

            % default techniques (must match switch-case labels)
            app.TechniqueDropDown_2.Items = {'Brightness', 'Histogram Equalization'};
            app.TechniqueDropDown_2.Value = 'Brightness';

            % sensible slider range (0..100)
            app.ParameterValueSlider.Limits = [-100 100];
            app.ParameterValueSlider.Value = 0;

        end

        % Load button
        function LoadanImageButtonPushed(app, event)
            [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff','Image Files'});
            if isequal(file,0) || isequal(path,0)
                % user canceled
                return;
            end
            imgFull = imread(fullfile(path, file));
            app.img = imgFull;
            imshow(app.img, 'Parent', app.UIAxes);
            title(app.UIAxes, 'Original Image');
            % update processed preview if technique already selected
            app.TechniqueDropDown_2ValueChanged();   % simplest — framework will pass app automatically
        end

        % Type dropdown changed -> change technique list
        function TypeDropDownValueChanged(app, event)
            
           value = app.TypeDropDown.Value;
           switch value
              case 'Enhancement'
                  app.TechniqueDropDown_2.Items = {'Brightness','Histogram Equalization'};
                  app.TechniqueDropDown_2.Value = 'Brightness';

              case 'Spatial Filter'
                  % list all implemented spatial options (names must match switch)
                  app.TechniqueDropDown_2.Items = {'Box','Weighted Average','Median', ...
                                                   'Laplacian (1st)','Laplacian (2nd)', ...
                                                   'Boosted Laplacian (1st)','Boosted Laplacian (2nd)', ...
                                                   'Sobel (Horizontal)','Sobel (Vertical)','Boosted Sobel', ...
                                                   'Prewitt (Horizontal)','Prewitt (Vertical)'};
                  app.TechniqueDropDown_2.Value = 'Box';

               case 'Frequency Filter'
                  app.TechniqueDropDown_2.Items = {'Ideal Low-Pass','Butterworth Low-Pass','Gaussian Low-Pass', ...
                                              'Ideal High-Pass','Butterworth High-Pass','Gaussian High-Pass'};
                  app.TechniqueDropDown_2.Value = 'Ideal Low-Pass';

               case 'Color Conversion'
                  app.TechniqueDropDown_2.Items = {'RGB→HSI','RGB→Lab','RGB→YCbCr'};
                  app.TechniqueDropDown_2.Value = 'RGB→HSI';
           end
           % update display if an image is loaded
           app.TechniqueDropDown_2ValueChanged();   % simplest — framework will pass app automatically

        end

        % Main processing callback
        function TechniqueDropDown_2ValueChanged(app, event)
             value = app.TechniqueDropDown_2.Value;
                if nargin < 2
                        event = [];
                end
                
                    % If no image loaded, clear processed axes and exit
                    if isempty(app.img)
                        cla(app.UIAxes_2);
                        title(app.UIAxes_2, 'No image loaded');
                        return;
                    end
             % require an image
             if isempty(app.img)
                 cla(app.UIAxes_2);
                 title(app.UIAxes_2, 'No image loaded');
                 return;
             end

             imj = app.img;
             paramVal = app.ParameterValueSlider.Value;
             out = [];

             % compute filter size for box/median when relevant
             spatialFilters = {'Box','Weighted Average','Median'};
             if ismember(value, spatialFilters)
                n = (round(paramVal/20)*2) + 3; % odd sizes: 3,5,7,9
                app.Label.Text = sprintf('Filter size: %dx%d', n, n);
             else
                app.Label.Text = '';
             end

             % helper: ensure grayscale
             function gray = ensureGray(img)
                 if ndims(img)==3
                     gray = rgb2gray(img);
                 else
                     gray = img;
                 end
             end

             % processing cases
            switch value
                   
                         case 'Brightness'
                                % Robust brightness addition that supports uint8, uint16, and double [0,1]
                                val = app.ParameterValueSlider.Value; % slider value (can be negative if you allow)
                            
                                img0 = imj;                     % original image (may be RGB or gray)
                                % Work in double for arithmetic, then cast back safely
                                if isfloat(img0)
                                    % assume range [0,1]
                                    outD = img0 + (val / 255);      % map 0..255 slider to 0..1 range
                                    outD = min(max(outD, 0), 1);
                                    out = outD;                     % keep as double in [0,1]
                                else
                                    % uint8, uint16, or other integer types -> use double math then clamp
                                    infoClass = class(img0);
                                    switch infoClass
                                        case 'uint8'
                                            maxv = 255; minv = 0;
                                        case 'uint16'
                                            maxv = 65535; minv = 0;
                                        otherwise
                                            % generic fallback assume 0..255
                                            maxv = 255; minv = 0;
                                    end
                            
                                    outD = double(img0) + double(val);   % add scalar to all channels
                                    outD = min(max(outD, minv), maxv);   % clamp
                                    % cast back to original class
                                    out = cast(round(outD), infoClass);
                                end



                   case 'Histogram Equalization'
                         gray = ensureGray(imj);
                         out = histeq(gray);

                  case 'Box'
                        gray = ensureGray(imj);
                        H = (1/(n^2)) * ones(n,n);
                        out = imfilter(double(gray), H, 'replicate');
                        % result double -> keep as double for scaling later

                  case 'Weighted Average'
                        gray = ensureGray(imj);
                        if paramVal < 25
                           H = (1/16)*[1 2 1; 2 4 2; 1 2 1]; % 3x3
                        elseif paramVal < 50
                           H = (1/65)*[1 2 2 2 1;
                                       1 2 4 2 1;
                                       2 4 8 4 2;
                                       1 2 4 2 1;
                                       1 2 2 2 1];
                        elseif paramVal < 75
                           H = (1/128)*[1 1 1 2 1 1 1;
                                        1 1 2 4 1 1 2;
                                        1 2 4 8 4 2 1;
                                        2 4 8 16 8 4 2;
                                        1 2 4 8 4 2 1;
                                        1 1 2 4 1 1 2;
                                        1 1 1 2 1 1 1];
                        else
                           H = (1/280)*[1 1 1 1 2 1 1 1 1;
                                        1 1 1 2 4 2 1 1 1;
                                        1 1 2 4 8 4 2 1 1;
                                        1 2 4 8 16 8 4 2 1;
                                        2 4 8 16 32 16 8 4 2;
                                        1 2 4 8 16 8 4 2 1;
                                        1 1 2 4 8 4 2 1 1;
                                        1 1 1 2 4 2 1 1 1;
                                        1 1 1 1 2 1 1 1 1];
                        end
                        out = imfilter(double(gray), H, 'replicate');

                 case 'Median'
                       gray = ensureGray(imj);
                       out = medfilt2(double(gray), [n n]);

                 case 'Laplacian (1st)'
                       gray = ensureGray(imj);
                       Lp1 = [0 -1 0; -1 4 -1; 0 -1 0];
                       out = double(gray) + imfilter(double(gray), Lp1, 'replicate');

                 case 'Laplacian (2nd)'
                       gray = ensureGray(imj);
                       Lp2 = [-1 -1 -1; -1 8 -1; -1 -1 -1];
                       out = double(gray) + imfilter(double(gray), Lp2, 'replicate');

                 case 'Boosted Laplacian (1st)'
                       gray = ensureGray(imj);
                       A = paramVal / 10;
                       Lp1b = [0 -1 0; -1 (4 + A) -1; 0 -1 0];
                       out = double(gray) + imfilter(double(gray), Lp1b, 'replicate');

                 case 'Boosted Laplacian (2nd)'
                       gray = ensureGray(imj);
                       A = paramVal / 10;
                       Lp2b = [-1 -1 -1; -1 (8 + A) -1; -1 -1 -1];
                       out = double(gray) + imfilter(double(gray), Lp2b, 'replicate');

                 case 'Sobel (Horizontal)'
                       gray = ensureGray(imj);
                       SbX = [-1 -2 -1; 0 0 0; 1 2 1];
                       J = imfilter(double(gray), SbX, 'replicate');
                       out = double(gray) + J;

                 case 'Sobel (Vertical)'
                       gray = ensureGray(imj);
                       SbY = [-1 0 1; -2 0 2; -1 0 1];
                       J = imfilter(double(gray), SbY, 'replicate');
                       out = double(gray) + J;

                 case 'Boosted Sobel'
                       gray = ensureGray(imj);
                       A = paramVal / 10;
                       SbXb = [-1 -(2 + A) -1; 0 0 0; 1 (2 + A) 1];
                       SbYb = SbXb';
                       Jx = imfilter(double(gray), SbXb, 'replicate');
                       Jy = imfilter(double(gray), SbYb, 'replicate');
                       out = double(gray) + (Jx + Jy);

                 case 'Prewitt (Horizontal)'
                       gray = ensureGray(imj);
                       Px = [-1 -1 -1; 0 0 0; 1 1 1];
                       J = imfilter(double(gray), Px, 'replicate');
                       out = double(gray) + J;

                 case 'Prewitt (Vertical)'
                       gray = ensureGray(imj);
                       Py = [-1 0 1; -1 0 1; -1 0 1];
                       J = imfilter(double(gray), Py, 'replicate');
                       out = double(gray) + J;

                 % Frequency Filters (all operate on gray)
                 case {'Ideal Low-Pass','Butterworth Low-Pass','Gaussian Low-Pass', ...
                       'Ideal High-Pass','Butterworth High-Pass','Gaussian High-Pass'}

                       gray = ensureGray(imj);
                       [m, n] = size(gray);
                       F = fftshift(fft2(double(gray)));
                       [X, Y] = meshgrid(1:n, 1:m);
                       X = X - (n+1)/2;
                       Y = Y - (m+1)/2;
                       D = sqrt(X.^2 + Y.^2);

                       D0 = max(1, round(paramVal * 2)); % cutoff (avoid zero)
                       order = 2; % Butterworth order

                       switch value
                              case 'Ideal Low-Pass'
                                    H = double(D <= D0);
                              case 'Butterworth Low-Pass'
                                    H = 1 ./ (1 + (D./D0).^(2*order));
                              case 'Gaussian Low-Pass'
                                    H = exp(-(D.^2) / (2*(D0^2)));
                              case 'Ideal High-Pass'
                                    H = double(D > D0);
                              case 'Butterworth High-Pass'
                                    H = 1 ./ (1 + (D0./(D + eps)).^(2*order)); % +eps avoids inf at D=0
                              case 'Gaussian High-Pass'
                                    H = 1 - exp(-(D.^2) / (2*(D0^2)));
                       end

                       G = F .* H;
                       out = real(ifft2(ifftshift(G)));

                 % Color Space Conversions
                 case 'RGB→HSI'
                       % MATLAB doesn't have rgb2hsi; rgb2hsv is close (Hue,Saturation,Value).
                       % We'll return HSV since HSI would require custom conversion.
                       out = rgb2hsv(imj);

                 case 'RGB→Lab'
                       % rgb2lab expects double in 0..1 or uint8; allow both.
                       out = rgb2lab(imj);

                 case 'RGB→YCbCr'
                       out = rgb2ycbcr(imj);
            end

            % Prepare output for display
            % If grayscale (2D) -> scale with mat2gray and show as uint8
            % If RGB or multi-channel -> show correctly (uint8) or scale float in [0,1]
            try
                if isempty(out)
                    imshow([], 'Parent', app.UIAxes_2);
                    title(app.UIAxes_2, value);
                else
                    if ndims(out) == 2
                        % 2D grayscale: scale and convert to uint8 for reliable display
                        dispImg = uint8(255 * mat2gray(out));
                        imshow(dispImg, 'Parent', app.UIAxes_2);
                    elseif ndims(out) == 3
                        % 3D color-like array
                        if isfloat(out)
                            % if floats are in [0,1] -> scale up, else assume already 0..255
                            mx = max(out(:));
                            if mx <= 1
                                dispImg = uint8(255 * out);
                            else
                                dispImg = uint8(out);
                            end
                        else
                            dispImg = out;
                        end
                        imshow(dispImg, 'Parent', app.UIAxes_2);
                    else
                        % fallback
                        imshow(uint8(255 * mat2gray(out)), 'Parent', app.UIAxes_2);
                    end
                    title(app.UIAxes_2, value);
                end
            catch ME
                % If display fails, show an error text in the axes
                cla(app.UIAxes_2);
                text(0.1,0.5, ['Display error: ' ME.message], 'Parent', app.UIAxes_2);
                axis(app.UIAxes_2,'off');
            end
        end

        % slider changed
        function ParameterValueSliderValueChanged(app, event)
            % call the technique handler so change is applied immediately
            app.TechniqueDropDown_2ValueChanged();   % simplest — framework will pass app automatically
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 760 520];
            app.UIFigure.Name = 'MATLAB App - CV Task 1';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Original Image')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            app.UIAxes.Position = [30 250 340 240];

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.UIFigure);
            title(app.UIAxes_2, 'Processed Image')
            xlabel(app.UIAxes_2, 'X')
            ylabel(app.UIAxes_2, 'Y')
            app.UIAxes_2.Position = [390 250 340 240];

            % Create LoadanImageButton
            app.LoadanImageButton = uibutton(app.UIFigure, 'push');
            app.LoadanImageButton.ButtonPushedFcn = createCallbackFcn(app, @LoadanImageButtonPushed, true);
            app.LoadanImageButton.Position = [310 200 140 30];
            app.LoadanImageButton.Text = 'Load an Image';

            % Create TypeDropDownLabel
            app.TypeDropDownLabel = uilabel(app.UIFigure);
            app.TypeDropDownLabel.HorizontalAlignment = 'right';
            app.TypeDropDownLabel.Position = [400 180 32 22];
            app.TypeDropDownLabel.Text = 'Type';

            % Create TypeDropDown
            app.TypeDropDown = uidropdown(app.UIFigure);
            app.TypeDropDown.ValueChangedFcn = createCallbackFcn(app, @TypeDropDownValueChanged, true);
            app.TypeDropDown.Position = [445 180 140 23];

            % Create ParameterValueSliderLabel
            app.ParameterValueSliderLabel = uilabel(app.UIFigure);
            app.ParameterValueSliderLabel.HorizontalAlignment = 'right';
            app.ParameterValueSliderLabel.Position = [170 120 94 22];
            app.ParameterValueSliderLabel.Text = 'Parameter Value';

            % Create ParameterValueSlider
            app.ParameterValueSlider = uislider(app.UIFigure);
            app.ParameterValueSlider.ValueChangedFcn = createCallbackFcn(app, @ParameterValueSliderValueChanged, true);
            app.ParameterValueSlider.Position = [280 130 260 3];

            % Create TechniqueDropDown_2Label
            app.TechniqueDropDown_2Label = uilabel(app.UIFigure);
            app.TechniqueDropDown_2Label.HorizontalAlignment = 'right';
            app.TechniqueDropDown_2Label.Position = [400 150 60 22];
            app.TechniqueDropDown_2Label.Text = 'Technique';

            % Create TechniqueDropDown_2
            app.TechniqueDropDown_2 = uidropdown(app.UIFigure);
            app.TechniqueDropDown_2.ValueChangedFcn = createCallbackFcn(app, @TechniqueDropDown_2ValueChanged, true);
            app.TechniqueDropDown_2.Position = [470 150 180 22];

            % Create Label
            app.Label = uilabel(app.UIFigure);
            app.Label.Position = [200 80 240 22];
            app.Label.Text = '';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = CV_Task1_Final2

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
