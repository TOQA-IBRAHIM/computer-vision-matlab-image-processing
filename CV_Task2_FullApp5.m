classdef CV_Task2_FullApp5 < matlab.apps.AppBase


    % Properties that correspond to app components
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        ModuleDrop           matlab.ui.control.DropDown
        LoadBtn              matlab.ui.control.Button
        SelectTemplateBtn    matlab.ui.control.Button
        ClearTemplateBtn     matlab.ui.control.Button
        RunBtn               matlab.ui.control.Button
        SaveBeforeBtn        matlab.ui.control.Button
        SaveAfterBtn         matlab.ui.control.Button
        ControlsPanel        matlab.ui.container.Panel
        AxBefore             matlab.ui.control.UIAxes
        AxAfter              matlab.ui.control.UIAxes
        StatusLabel          matlab.ui.control.Label

        % Pyramid controls
        SpinnerPyrLevels     matlab.ui.control.Spinner
        BtnPyramids          matlab.ui.control.Button
        BtnUpsample          matlab.ui.control.Button
        BtnDownsample        matlab.ui.control.Button

        % Template controls
        ChkUsePyramid        matlab.ui.control.CheckBox
        SliderTMThreshold    matlab.ui.control.Slider
        TxtTMThresh          matlab.ui.control.Label
        BtnTemplateMatch     matlab.ui.control.Button

        % Filter bank controls
        PopupFilterType      matlab.ui.control.DropDown
        EditWavelengths      matlab.ui.control.EditField
        EditOrientations     matlab.ui.control.EditField
        BtnFilterBank        matlab.ui.control.Button
        SpinnerFilterShow    matlab.ui.control.Spinner

        % Edge controls
        PopupEdge            matlab.ui.control.DropDown
        BtnEdge              matlab.ui.control.Button
        SliderCannyLow       matlab.ui.control.Slider
        SliderCannyHigh      matlab.ui.control.Slider
        TxtCanny             matlab.ui.control.Label

        % Corner controls
        PopupCornerMethod    matlab.ui.control.DropDown
        BtnCorners           matlab.ui.control.Button
        SliderHarrisK        matlab.ui.control.Slider
        SliderHarrisThresh   matlab.ui.control.Slider
    end

    properties (Access = private)
        % data
        Img                  % original image (RGB)
        ImgGray              % grayscale double
        Template             % template patch (RGB)
        TemplateRect         % ROI handle
        CurrentAfterImage    % last result (uint8 image)
    end

    methods (Access = public)

        % Construct app
        function app = CV_Task2_FullApp5()
            createComponents(app)
            registerApp(app, app.UIFigure)

            app.ModuleDrop.Value = 'Pyramids';
            onModuleChanged(app)
            onEdgeOperatorChanged(app)
            app.updateStatus('Ready — load an image to begin');
        end

        % Code that executes before app deletion
        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure)
            end
        end
    end

    methods (Access = private)

        function createComponents(app)
            % Main figure
            app.UIFigure = uifigure('Position',[100 100 1180 760],'Name','CV Task 2 - Smart App');

            % Top controls
            uilabel(app.UIFigure,'Text','Module:','Position',[20 720 60 22]);
            app.ModuleDrop = uidropdown(app.UIFigure,'Position',[80 722 260 24],...
                'Items',{'Pyramids','Template Matching','Filter Banks','Edge Detection','Corner Detection'},...
                'ValueChangedFcn',@(s,e)onModuleChanged(app));

            app.LoadBtn = uibutton(app.UIFigure,'push','Text','Load Image','Position',[360 722 100 26], 'ButtonPushedFcn',@(s,e)onLoad(app));
            app.SelectTemplateBtn = uibutton(app.UIFigure,'push','Text','Select Template','Position',[470 722 120 26], 'ButtonPushedFcn',@(s,e)onSelectTemplate(app));
            app.ClearTemplateBtn = uibutton(app.UIFigure,'push','Text','Clear Template','Position',[600 722 110 26], 'ButtonPushedFcn',@(s,e)onClearTemplate(app));
            app.SelectTemplateBtn.Enable = 'off';
            app.ClearTemplateBtn.Enable = 'off';

            app.RunBtn = uibutton(app.UIFigure,'push','Text','Run','Position',[730 722 80 26],'ButtonPushedFcn',@(s,e)onRun(app));
            app.SaveBeforeBtn = uibutton(app.UIFigure,'push','Text','Save Before','Position',[820 722 100 26],'ButtonPushedFcn',@(s,e)onSaveBefore(app));
            app.SaveAfterBtn  = uibutton(app.UIFigure,'push','Text','Save After','Position',[930 722 100 26],'ButtonPushedFcn',@(s,e)onSaveAfter(app));

            % Controls panel (dynamic)
            app.ControlsPanel = uipanel(app.UIFigure,'Title','Controls','Position',[20 540 840 160]);

            % Axes
            app.AxBefore = uiaxes(app.UIFigure,'Position',[20 80 540 440]); title(app.AxBefore,'Before');
            app.AxAfter  = uiaxes(app.UIFigure,'Position',[580 80 580 440]); title(app.AxAfter,'After');

            % Status
            app.StatusLabel = uilabel(app.UIFigure,'Text','Status:','Position',[20 50 900 20]);


            % Pyramids
            uilabel(app.ControlsPanel,'Text','Levels:','Position',[10 110 60 18],'Tag','pyrLab','Visible','off');
            app.SpinnerPyrLevels = uispinner(app.ControlsPanel,'Position',[70 110 70 22],'Limits',[1 6],'Value',3,'Tag','pyrSpin','Visible','off');
            app.BtnPyramids = uibutton(app.ControlsPanel,'push','Text','Show Pyramids','Position',[160 110 120 26],'ButtonPushedFcn',@(s,e)onPyramids(app),'Visible','off');
            app.BtnUpsample = uibutton(app.ControlsPanel,'push','Text','Upsample x2','Position',[290 110 100 26],'ButtonPushedFcn',@(s,e)onUpsample(app),'Visible','off');
            app.BtnDownsample = uibutton(app.ControlsPanel,'push','Text','Downsample /2','Position',[400 110 100 26],'ButtonPushedFcn',@(s,e)onDownsample(app),'Visible','off');

            % Template matching
            app.ChkUsePyramid = uicheckbox(app.ControlsPanel,'Text','Use Pyramid (coarse->fine)','Position',[10 120 200 20],'Value',true,'Visible','off');
            uilabel(app.ControlsPanel,'Text','Thresh:','Position',[220 124 50 18],'Visible','off','Tag','tmLab');
            app.SliderTMThreshold = uislider(app.ControlsPanel,'Position',[270 130 260 3],'Limits',[0.1 0.99],'Value',0.6,'ValueChangedFcn',@(s,e)onTMThreshChange(app),'Visible','off');
            app.TxtTMThresh = uilabel(app.ControlsPanel,'Text',sprintf('%.2f',0.6),'Position',[540 120 40 18],'Visible','off');
            app.BtnTemplateMatch = uibutton(app.ControlsPanel,'push','Text','Template Match','Position',[600 110 120 26],'ButtonPushedFcn',@(s,e)onTemplateMatch(app),'Visible','off');

            % Filter bank - now supports exactly LM, Gabor, Sobel and BlurCenter
            uilabel(app.ControlsPanel,'Text','Bank:','Position',[10 120 40 18],'Tag','fLab','Visible','off');
            app.PopupFilterType = uidropdown(app.ControlsPanel,'Items',{'Gabor','LM','Sobel','BlurCenter'},'Position',[60 120 100 22],'Visible','off');
            uilabel(app.ControlsPanel,'Text','Gabor wavelengths:','Position',[180 120 120 18],'Tag','fLab2','Visible','off');
            app.EditWavelengths = uieditfield(app.ControlsPanel,'text','Position',[300 120 120 22],'Value','[4 8 16]','Visible','off');
            uilabel(app.ControlsPanel,'Text','Orientations:','Position',[430 120 80 18],'Visible','off');
            app.EditOrientations = uieditfield(app.ControlsPanel,'text','Position',[520 120 120 22],'Value','0:45:135','Visible','off');
            uilabel(app.ControlsPanel,'Text','Show responses:','Position',[10 80 100 18],'Visible','off');
            app.SpinnerFilterShow = uispinner(app.ControlsPanel,'Position',[120 80 60 22],'Limits',[1 24],'Value',4,'Visible','off');
            app.BtnFilterBank = uibutton(app.ControlsPanel,'push','Text','Run Filter Bank','Position',[200 80 140 26],'ButtonPushedFcn',@(s,e)onFilterBank(app),'Visible','off');

            % Edge detection
            uilabel(app.ControlsPanel,'Text','Operator:','Position',[10 120 70 18],'Visible','off');
            app.PopupEdge = uidropdown(app.ControlsPanel,'Items',{'Canny','Sobel','Prewitt','LoG','DoG'},'Position',[90 120 120 22],...
                'ValueChangedFcn',@(s,e)onEdgeOperatorChanged(app),'Visible','off');
            app.BtnEdge = uibutton(app.ControlsPanel,'push','Text','Run Edge','Position',[220 120 90 26],'ButtonPushedFcn',@(s,e)onEdge(app),'Visible','off');
            uilabel(app.ControlsPanel,'Text','Canny low/high:','Position',[320 120 90 18],'Visible','off');
            app.SliderCannyLow = uislider(app.ControlsPanel,'Position',[410 130 150 3],'Limits',[0 1],'Value',0.1,'ValueChangedFcn',@(s,e)onCannyChange(app),'Visible','off');
            app.SliderCannyHigh = uislider(app.ControlsPanel,'Position',[570 130 150 3],'Limits',[0 1],'Value',0.3,'ValueChangedFcn',@(s,e)onCannyChange(app),'Visible','off');
            app.TxtCanny = uilabel(app.ControlsPanel,'Text',sprintf('L=%.2f H=%.2f',0.1,0.3),'Position',[730 120 140 18],'Visible','off');

            % Corner detection
            uilabel(app.ControlsPanel,'Text','Method:','Position',[10 120 60 18],'Visible','off');
            app.PopupCornerMethod = uidropdown(app.ControlsPanel,'Items',{'Harris (manual)','Harris built-in','SURF (scale-inv)'},'Position',[80 120 200 22],'Visible','off');
            app.BtnCorners = uibutton(app.ControlsPanel,'push','Text','Find Corners','Position',[300 120 120 26],'ButtonPushedFcn',@(s,e)onCorners(app),'Visible','off');
            uilabel(app.ControlsPanel,'Text','Harris k:','Position',[420 120 60 18],'Visible','off');
            app.SliderHarrisK = uislider(app.ControlsPanel,'Position',[480 130 120 3],'Limits',[0.01 0.2],'Value',0.04,'Visible','off');
            uilabel(app.ControlsPanel,'Text','Harris thr:','Position',[610 120 70 18],'Visible','off');
            app.SliderHarrisThresh = uislider(app.ControlsPanel,'Position',[680 130 120 3],'Limits',[0.001 0.2],'Value',0.02,'Visible','off');

            % ensure sliders initial label values updated
            onTMThreshChange(app);
            onCannyChange(app);
        end


        function onLoad(app)
            [f,p] = uigetfile({'*.png;*.jpg;*.bmp;*.tif','Images'},'Select an image');
            if isequal(f,0), return; end
            I = imread(fullfile(p,f));
            app.Img = I;
            if size(I,3)==3
                app.ImgGray = im2double(rgb2gray(I));
            else
                app.ImgGray = im2double(I);
            end
            imshow(app.Img,'Parent',app.AxBefore);
            cla(app.AxAfter);
            title(app.AxBefore,'Before');
            title(app.AxAfter,'After');
            app.Template = [];
            app.SelectTemplateBtn.Enable = 'on';
            app.ClearTemplateBtn.Enable = 'off';
            app.updateStatus('Image loaded');
        end

        function onSelectTemplate(app)
            if isempty(app.Img)
                uialert(app.UIFigure,'Load an image first','No image');
                return;
            end
            imshow(app.Img,'Parent',app.AxBefore);
            title(app.AxBefore,'Draw rectangle for template (double-click to finish)');
            roi = drawrectangle(app.AxBefore,'Color','yellow');
            wait(roi); % blocks until ROI placed
            pos = round(roi.Position); % [x y w h]
            x = max(1,pos(1)); y = max(1,pos(2));
            w = max(1,pos(3)); h = max(1,pos(4));
            x2 = min(size(app.Img,2), x+w-1); y2 = min(size(app.Img,1), y+h-1);
            app.Template = app.Img(y:y2, x:x2, :);
            app.TemplateRect = roi;
            imshow(app.Template,'Parent',app.AxAfter);
            title(app.AxAfter,'Template (preview)');
            app.ClearTemplateBtn.Enable = 'on';
            app.updateStatus('Template selected');
        end

        function onClearTemplate(app)
            app.Template = [];
            if ~isempty(app.TemplateRect) && isvalid(app.TemplateRect)
                delete(app.TemplateRect);
            end
            cla(app.AxAfter); title(app.AxAfter,'After');
            app.ClearTemplateBtn.Enable = 'off';
            app.updateStatus('Template cleared');
        end

        function onSaveBefore(app)
            if isempty(app.Img), uialert(app.UIFigure,'No image to save'); return; end
            [f,p] = uiputfile('before_saved.png','Save before image as');
            if isequal(f,0), return; end
            imwrite(app.Img, fullfile(p,f));
            app.updateStatus(['Saved before -> ' fullfile(p,f)]);
        end

        function onSaveAfter(app)
            if isempty(app.CurrentAfterImage), uialert(app.UIFigure,'No after image to save'); return; end
            [f,p] = uiputfile('after_saved.png','Save after image as');
            if isequal(f,0), return; end
            imwrite(app.CurrentAfterImage, fullfile(p,f));
            app.updateStatus(['Saved after -> ' fullfile(p,f)]);
        end

        function onTMThreshChange(app)
            if isvalid(app.SliderTMThreshold)
                app.TxtTMThresh.Text = sprintf('%.2f', app.SliderTMThreshold.Value);
            end
        end

        function onCannyChange(app)
            if isvalid(app.SliderCannyLow) && isvalid(app.SliderCannyHigh) && isvalid(app.TxtCanny)
                app.TxtCanny.Text = sprintf('L=%.2f H=%.2f', app.SliderCannyLow.Value, app.SliderCannyHigh.Value);
            end
        end

        %% Module visibility & run dispatch
        function onModuleChanged(app)
            module = app.ModuleDrop.Value;

            props = {'SpinnerPyrLevels','BtnPyramids','BtnUpsample','BtnDownsample', ...
                     'ChkUsePyramid','SliderTMThreshold','TxtTMThresh','BtnTemplateMatch','SelectTemplateBtn','ClearTemplateBtn', ...
                     'PopupFilterType','EditWavelengths','EditOrientations','BtnFilterBank','SpinnerFilterShow', ...
                     'PopupEdge','BtnEdge','SliderCannyLow','SliderCannyHigh','TxtCanny', ...
                     'PopupCornerMethod','BtnCorners','SliderHarrisK','SliderHarrisThresh'};
            for k = 1:numel(props)
                p = props{k};
                if isprop(app,p)
                    try app.(p).Visible = 'off'; catch, end
                end
            end

            % Also hide the 'Levels' label (tag 'pyrLab') by default
            lab = findobj(app.ControlsPanel,'Tag','pyrLab');
            if ~isempty(lab)
                try lab.Visible = 'off'; catch, end
            end

            switch module
                case 'Pyramids'
                    if ~isempty(lab)
                        try lab.Visible = 'on'; catch, end
                    end
                    app.SpinnerPyrLevels.Visible = 'on';
                    app.BtnPyramids.Visible = 'on';
                    app.BtnUpsample.Visible = 'on';
                    app.BtnDownsample.Visible = 'on';
                case 'Template Matching'
                    app.SelectTemplateBtn.Visible = 'on';
                    app.ClearTemplateBtn.Visible = 'on';
                    app.ChkUsePyramid.Visible = 'on';
                    app.SliderTMThreshold.Visible = 'on';
                    app.TxtTMThresh.Visible = 'on';
                    app.BtnTemplateMatch.Visible = 'on';
                case 'Filter Banks'
                    app.PopupFilterType.Visible = 'on';
                    % show gabor params by default (they're ignored for others)
                    app.EditWavelengths.Visible = 'on';
                    app.EditOrientations.Visible = 'on';
                    app.SpinnerFilterShow.Visible = 'on';
                    app.BtnFilterBank.Visible = 'on';
                case 'Edge Detection'
                    app.PopupEdge.Visible = 'on';
                    % fixed earlier typo: set Visible correctly
                    app.BtnEdge.Visible = 'on';
                    app.SliderCannyLow.Visible = 'on';
                    app.SliderCannyHigh.Visible = 'on';
                    app.TxtCanny.Visible = 'on';
                case 'Corner Detection'
                    app.PopupCornerMethod.Visible = 'on';
                    app.BtnCorners.Visible = 'on';
                    app.SliderHarrisK.Visible = 'on';
                    app.SliderHarrisThresh.Visible = 'on';
            end

            if isempty(app.Img)
                app.SelectTemplateBtn.Enable = 'off';
                app.ClearTemplateBtn.Enable = 'off';
            else
                if strcmp(module,'Template Matching')
                    app.SelectTemplateBtn.Enable = 'on';
                    if isempty(app.Template)
                        app.ClearTemplateBtn.Enable = 'off';
                    else
                        app.ClearTemplateBtn.Enable = 'on';
                    end
                else
                    app.SelectTemplateBtn.Enable = 'on';
                end
            end

            onEdgeOperatorChanged(app)
        end

        function onRun(app)
            if isempty(app.Img)
                uialert(app.UIFigure,'Load an image first','No image');
                return;
            end
            module = app.ModuleDrop.Value;
            switch module
                case 'Pyramids'
                    onPyramids(app);
                case 'Template Matching'
                    onTemplateMatch(app);
                case 'Filter Banks'
                    onFilterBank(app);
                case 'Edge Detection'
                    onEdge(app);
                case 'Corner Detection'
                    onCorners(app);
                otherwise
                    onPyramids(app);
            end
        end

        function onEdgeOperatorChanged(app)
            if strcmp(app.PopupEdge.Value,'Canny') && strcmp(app.PopupEdge.Visible,'on')
                app.SliderCannyLow.Visible = 'on';
                app.SliderCannyHigh.Visible = 'on';
                app.TxtCanny.Visible = 'on';
            else
                if isvalid(app.SliderCannyLow), app.SliderCannyLow.Visible = 'off'; end
                if isvalid(app.SliderCannyHigh), app.SliderCannyHigh.Visible = 'off'; end
                if isvalid(app.TxtCanny), app.TxtCanny.Visible = 'off'; end
            end
        end


        % Pyramids (show montage)
        function onPyramids(app)
            if isempty(app.Img), uialert(app.UIFigure,'Load an image first'); return; end
            levels = app.SpinnerPyrLevels.Value;
            G = app.buildGaussianPyramid(app.Img, levels);
            mont = app.visualizeGaussianPyramid(G);
            imshow(mont,'Parent',app.AxAfter); title(app.AxAfter,'Gaussian pyramid (levels left->right)');
            app.CurrentAfterImage = mont;
            app.updateStatus(sprintf('Pyramid built (%d levels)',levels));
        end

        function onUpsample(app)
            if isempty(app.Img), uialert(app.UIFigure,'Load image first'); return; end
            % use expandImage for a proper pyramid-style expand
            up = app.expandImage(app.Img);
            imshow(up,'Parent',app.AxAfter);
            app.CurrentAfterImage = up;
            app.updateStatus('Image upsampled (expand) x2');
        end

        function onDownsample(app)
            if isempty(app.Img), uialert(app.UIFigure,'Load image first'); return; end
            % use reduceImage for a proper pyramid-style reduce
            down = app.reduceImage(app.Img);
            imshow(down,'Parent',app.AxAfter);
            app.CurrentAfterImage = down;
            app.updateStatus('Image downsampled (reduce) /2');
        end

        % Template matching (single-scale or pyramid)
        function onTemplateMatch(app)
            if isempty(app.Img) || isempty(app.Template)
                uialert(app.UIFigure,'Load image and select template first','Missing data');
                return;
            end
            thresh = app.SliderTMThreshold.Value;
            usePyr = app.ChkUsePyramid.Value;
            im = app.Img;
            tmpl = app.Template;
            if usePyr
                levels = app.SpinnerPyrLevels.Value;
                matches = app.templateMatchPyramid(im, tmpl, levels, thresh);
            else
                matches = app.templateMatchSingleScale(im, tmpl, thresh);
            end
            imshow(im,'Parent',app.AxAfter); hold(app.AxAfter,'on');
            if isempty(matches)
                app.updateStatus('Template matching: no matches found');
            else
                matches = sortrows(matches, -3);
                N = min(10,size(matches,1));
                for k=1:N
                    rectangle(app.AxAfter,'Position',[matches(k,1), matches(k,2), size(tmpl,2), size(tmpl,1)],'EdgeColor','r','LineWidth',2);
                end
                app.updateStatus(sprintf('Template matching: %d matches (showing %d)', size(matches,1), N));
            end
            hold(app.AxAfter,'off');
            app.CurrentAfterImage = getframe(app.AxAfter).cdata;
        end

        % Filter bank (LM, Gabor, Sobel, BlurCenter)
        function onFilterBank(app)
            if isempty(app.Img), uialert(app.UIFigure,'Load image first'); return; end

            bank = app.PopupFilterType.Value;
            numShow = double(app.SpinnerFilterShow.Value);

            switch bank
                case 'Gabor'
                    try
                        wv = eval(app.EditWavelengths.Value);
                        oris = eval(app.EditOrientations.Value);
                    catch
                        uialert(app.UIFigure,'Invalid Gabor parameters. Use MATLAB syntax: [4 8 16], 0:45:135','Params error');
                        return;
                    end
                    % prefer imgaborfilt if available
                    try
                        resp = app.filterBankGabor(app.Img, wv, oris); % HxWxN
                    catch
                        % fallback to approximate responses if imgaborfilt missing (shouldn't happen often)
                        resp = app.fallbackGaborResponses(app.Img, wv, oris);
                    end

                case 'LM'
                    % LM approximate bank: Gaussians, LoG, oriented derivatives (reasonable approximation)
                    resp = app.filterBankLMapprox(app.Img);

                case 'Sobel'
                    resp = app.filterBankSobel(app.Img);

                case 'BlurCenter'
                    % produce a single response that is the blurred-with-focused-center image (grayscale)
                    respImg = app.filterBankBlurCenter(app.Img);
                    % return as single-channel response for visualization
                    resp = mat2gray(respImg);
                    resp = reshape(resp, size(resp,1), size(resp,2), 1);

                otherwise
                    resp = app.filterBankSobel(app.Img);
            end

            vis = app.visualizeFilterResponses(resp, numShow);
            imshow(vis,'Parent',app.AxAfter); title(app.AxAfter,sprintf('Filter bank: %s (sample)', bank));
            app.CurrentAfterImage = vis;
            % safe query for number of responses
            nresp = size(resp,3);
            app.updateStatus(sprintf('Filter bank run (%s, %d responses)', bank, nresp));
        end

        % Edge detection (focus on top part of image)
        function onEdge(app)
            if isempty(app.Img), uialert(app.UIFigure,'Load image first'); return; end
            op = app.PopupEdge.Value;
            low = app.SliderCannyLow.Value;
            high = app.SliderCannyHigh.Value;
            BW = app.runEdge(app.Img, op, [low high]);
            imshow(BW,'Parent',app.AxAfter); title(app.AxAfter,['Edges: ' op ' ']);
            if islogical(BW)
                app.CurrentAfterImage = uint8(BW)*255;
            else
                app.CurrentAfterImage = im2uint8(mat2gray(BW));
            end
            app.updateStatus(['Edge operator ' op ' applied (top-focused)']);
        end

        % Corners (focus on line intersections instead of circular blobs)
        function onCorners(app)
            if isempty(app.Img), uialert(app.UIFigure,'Load image first'); return; end
            method = app.PopupCornerMethod.Value;
            switch method
                case 'Harris (manual)'
                    % Instead of blob-like corners, detect prominent lines and their intersections
                    % compute intersections (in image coordinates)
                    pts = app.detectLineIntersections(app.ImgGray);
                    imshow(app.Img,'Parent',app.AxAfter); hold(app.AxAfter,'on');
                    if ~isempty(pts)
                        plot(app.AxAfter, pts(:,1), pts(:,2), 'r+','MarkerSize',8,'LineWidth',1.5);
                        app.updateStatus(sprintf('Line intersections: %d points', size(pts,1)));
                    else
                        app.updateStatus('Line intersections: 0 points');
                    end
                    hold(app.AxAfter,'off');
                    app.CurrentAfterImage = getframe(app.AxAfter).cdata;

                case 'Harris built-in'
                    % Use intersections as well (showing strongest)
                    pts = app.detectLineIntersections(app.ImgGray);
                    imshow(app.Img,'Parent',app.AxAfter); hold(app.AxAfter,'on');
                    if ~isempty(pts)
                        % show up to 200 intersections (rare)
                        N = min(200,size(pts,1));
                        plot(app.AxAfter, pts(1:N,1), pts(1:N,2), 'ro','MarkerSize',6,'LineWidth',1);
                    end
                    hold(app.AxAfter,'off');
                    app.updateStatus(sprintf('Line intersection detection: %d points (shown strongest)', size(pts,1)));
                    app.CurrentAfterImage = getframe(app.AxAfter).cdata;

                case 'SURF (scale-inv)'
                    try
                        pts = detectSURFFeatures(app.ImgGray);
                        strongest = pts.selectStrongest(200);
                        coords = strongest.Location;
                        imshow(app.Img,'Parent',app.AxAfter); hold(app.AxAfter,'on');
                        if ~isempty(coords)
                            plot(app.AxAfter, coords(:,1), coords(:,2), 'g.','MarkerSize',8);
                        end
                        hold(app.AxAfter,'off');
                        try
                            totalCount = pts.Count;
                        catch
                            totalCount = size(coords,1);
                        end
                        app.updateStatus(sprintf('detectSURFFeatures: %d points (shown strongest)', totalCount));
                        app.CurrentAfterImage = getframe(app.AxAfter).cdata;
                    catch ME
                        uialert(app.UIFigure,'SURF not available (Computer Vision Toolbox required)','Toolbox missing');
                        app.updateStatus('SURF not available');
                    end
            end
        end


        function G = buildGaussianPyramid(app, I, levels)
            if size(I,3)==3, Ig = im2double(rgb2gray(I)); else Ig = im2double(I); end
            G = cell(levels,1); G{1} = Ig;
            for L=2:levels
                blurred = imgaussfilt(G{L-1}, 1.0);
                G{L} = imresize(blurred, 0.5, 'bilinear');
            end
        end

        function L = buildLaplacianPyramid(app, G)
            levels = numel(G); L = cell(levels,1);
            for i=1:levels-1
                up = imresize(G{i+1}, size(G{i}),'bilinear');
                L{i} = G{i} - up;
            end
            L{levels} = G{levels};
        end

        function mont = visualizeGaussianPyramid(app, G)
            levels = numel(G);
            thumbs = cell(levels,1);
            for i=1:levels
                thumbs{i} = im2uint8(mat2gray(G{i}));
                if size(thumbs{i},3)==1, thumbs{i} = repmat(thumbs{i},[1 1 3]); end
            end
            totalW = sum(cellfun(@(x) size(x,2), thumbs));
            H = max(cellfun(@(x) size(x,1), thumbs));
            mont = uint8(255*ones(H, totalW, 3));
            x = 1;
            for i=1:levels
                imr = thumbs{i}; w = size(imr,2);
                mont(1:size(imr,1), x:x+w-1, :) = imr;
                x = x + w;
            end
        end

        function mont = visualizePyramidLaplacian(app, L)
            levels = numel(L);
            thumbs = cell(levels,1);
            for i=1:levels
                t = abs(L{i}); thumbs{i} = im2uint8(mat2gray(t));
                if size(thumbs{i},3)==1, thumbs{i} = repmat(thumbs{i},[1 1 3]); end
            end
            totalW = sum(cellfun(@(x) size(x,2), thumbs));
            H = max(cellfun(@(x) size(x,1), thumbs));
            mont = uint8(255*ones(H, totalW, 3));
            x = 1;
            for i=1:levels
                imr = thumbs{i}; w = size(imr,2);
                mont(1:size(imr,1), x:x+w-1, :) = imr;
                x = x + w;
            end
        end

        function matches = templateMatchSingleScale(app, I, template, thresh)
            if size(I,3)==3, I = im2double(rgb2gray(I)); else I = im2double(I); end
            if size(template,3)==3, template = im2double(rgb2gray(template)); else template = im2double(template); end
            C = normxcorr2(template, I);
            mval = max(C(:));
            if isempty(mval) || mval==0
                matches = [];
                return;
            end
            mask = (C >= thresh*mval) & imregionalmax(C);
            [r,c] = find(mask);
            matches = [];
            for k=1:numel(r)
                y = r(k) - size(template,1) + 1;
                x = c(k) - size(template,2) + 1;
                matches(end+1,:) = [x,y,C(r(k),c(k))]; %#ok<AGROW>
            end
        end

        function finalMatches = templateMatchPyramid(app, Iorig, tmplorig, levels, thresh)
            % Coarse-to-fine pyramid matching. returns Nx3 [x y score]
            if size(Iorig,3)==3, IorigGray = im2double(rgb2gray(Iorig)); else IorigGray = im2double(Iorig); end
            if size(tmplorig,3)==3, tmplGray = im2double(rgb2gray(tmplorig)); else tmplGray = im2double(tmplorig); end

            G = app.buildGaussianPyramid(IorigGray, levels);
            candidates = [];
            % start at coarsest
            for L = levels:-1:1
                curI = G{L};
                scale = size(curI,1)/size(G{1},1);
                curT = imresize(tmplGray, scale, 'bilinear');
                C = normxcorr2(curT, curI);
                mval = max(C(:));
                if isempty(mval) || mval==0, continue; end
                mask = (C >= thresh*mval) & imregionalmax(C);
                [r,c] = find(mask);
                for k=1:numel(r)
                    y = r(k) - size(curT,1) + 1;
                    x = c(k) - size(curT,2) + 1;
                    x_full = round(x / scale);
                    y_full = round(y / scale);
                    score = C(r(k),c(k));
                    candidates(end+1,:) = [x_full, y_full, score]; %#ok<AGROW>
                end
            end
            if isempty(candidates), finalMatches = []; return; end
            candidates = sortrows(candidates, -3);
            final = [];
            taken = false(size(candidates,1),1);
            rdist = round(max(size(tmplorig,1), size(tmplorig,2))/2);
            for i=1:size(candidates,1)
                if taken(i), continue; end
                base = candidates(i,:);
                final(end+1,:) = base; %#ok<AGROW>
                d = sqrt((candidates(:,1)-base(1)).^2 + (candidates(:,2)-base(2)).^2);
                taken = taken | (d < rdist);
            end
            finalMatches = final;
        end

        function responses = filterBankGabor(app, I, wavelengths, orientations)
            if size(I,3)==3, Igray = im2single(rgb2gray(I)); else Igray = im2single(I); end
            g = gabor(wavelengths, orientations);
            responses = imgaborfilt(Igray, g); % HxWxN
        end

        function resp = fallbackGaborResponses(app, I, wavelengths, orientations)
            % Keep a small fallback in case imgaborfilt missing — produces plausible responses
            if size(I,3)==3, Igray = im2double(rgb2gray(I)); else Igray = im2double(I); end
            resp = [];
            for wi = 1:numel(wavelengths)
                s = max(0.5, wavelengths(wi)/4);
                g = imgaussfilt(Igray, s);
                resp = cat(3, resp, mat2gray(g));
                for th = orientations
                    sx = [-1 0 1; -2 0 2; -1 0 1];
                    k = imrotate(sx, th, 'crop');
                    r = imfilter(g, k, 'replicate');
                    resp = cat(3, resp, mat2gray(abs(r)));
                end
            end
            if isempty(resp)
                resp = repmat(mat2gray(Igray),[1 1 1]);
            end
        end

        function resp = filterBankLMapprox(app, I)
            % LM approximate: Gaussians (3 scales), LoG (3 scales), oriented derivatives at 4 orientations.
            if size(I,3)==3, Igray = im2double(rgb2gray(I)); else Igray = im2double(I); end
            scales = [1 2 4];
            orientations = [0 45 90 135];
            resp = [];
            % Gaussian blur responses
            for s = scales
                g = imgaussfilt(Igray, s);
                resp = cat(3, resp, mat2gray(g));
            end
            % LoG responses
            for s = scales
                h = fspecial('log', max(3,ceil(6*s)), s);
                l = imfilter(Igray, h, 'replicate');
                resp = cat(3, resp, mat2gray(l));
            end
            % Oriented derivatives (approx)
            for s = scales
                base = imgaussfilt(Igray, s);
                for th = orientations
                    kernel = imrotate([-1 0 1; -2 0 2; -1 0 1], th, 'crop');
                    or = imfilter(base, kernel, 'replicate');
                    resp = cat(3, resp, mat2gray(abs(or)));
                end
            end
        end

        function resp = filterBankSobel(app, I)
            % Sobel filter bank: Sx, Sy and magnitude and direction maps
            if size(I,3)==3, Igray = im2double(rgb2gray(I)); else Igray = im2double(I); end
            Sx = imfilter(Igray, [-1 0 1; -2 0 2; -1 0 1], 'replicate');
            Sy = imfilter(Igray, [-1 -2 -1; 0 0 0; 1 2 1], 'replicate');
            mag = sqrt(Sx.^2 + Sy.^2);
            ang = atan2(Sy, Sx);
            resp = cat(3, mat2gray(Sx), mat2gray(Sy), mat2gray(mag), mat2gray(ang));
        end

        function vis = visualizeFilterResponses(app, resp, numShow)
            nf = size(resp,3);
            numShow = min(numShow, nf);
            rows = ceil(sqrt(numShow)); cols = ceil(numShow/rows);
            tileH = floor(400/rows); tileW = floor(400/cols);
            vis = uint8(255*ones(rows*tileH, cols*tileW, 3));
            idx = 1;
            for r=1:rows
                for c=1:cols
                    if idx<=numShow
                        imr = mat2gray(resp(:,:,idx));
                        imr = imresize(im2uint8(imr), [tileH tileW]);
                        vis((r-1)*tileH+1:r*tileH, (c-1)*tileW+1:c*tileW, :) = repmat(imr,[1 1 3]);
                    end
                    idx = idx + 1;
                end
            end
        end

        function BW = runEdge(app, I, operator, cannyParams)
            % Focus edges on the top part of the image (top 40%)
            if size(I,3)==3, IgFull = im2double(rgb2gray(I)); else IgFull = im2double(I); end
            [Hrows, Wcols] = size(IgFull);
            topFrac = 0.60; % top 40% focused
            topRows = max(1, round(Hrows * topFrac));
            IgTop = IgFull(1:topRows, :);

            op = lower(operator);
            switch op
                case 'canny'
                    if nargin>=4 && ~isempty(cannyParams)
                        BWtop = edge(IgTop,'Canny',cannyParams);
                    else
                        BWtop = edge(IgTop,'Canny');
                    end
                case 'sobel'
                    BWtop = edge(IgTop,'Sobel');
                case 'prewitt'
                    BWtop = edge(IgTop,'Prewitt');
                case 'log'
                    BWtop = edge(IgTop,'log');
                case 'dog'
                    % DoG on top region jf
                    s1 = 1.0; s2 = 2.0;
                    g1 = imgaussfilt(IgTop, s1);
                    g2 = imgaussfilt(IgTop, s2);
                    dog = g1 - g2;
                    t = graythresh(mat2gray(dog));
                    BWtop = imbinarize(mat2gray(dog), t);
                otherwise
                    BWtop = edge(IgTop,'Canny');
            end

            % assemble full-size BW (false below topRows)
            BW = false(Hrows, Wcols);
            BW(1:topRows, :) = BWtop;
        end

        function corners = harrisCorners(app, I, k, sigma, thresh)
            if size(I,3)==3, I = rgb2gray(I); end
            I = im2double(I);
            fx = [-1 0 1; -1 0 1; -1 0 1]; fy = fx';
            Ix = imfilter(I, fx, 'replicate'); Iy = imfilter(I, fy, 'replicate');
            Ix2 = imgaussfilt(Ix.^2, sigma); Iy2 = imgaussfilt(Iy.^2, sigma); Ixy = imgaussfilt(Ix.*Iy, sigma);
            R = (Ix2.*Iy2 - Ixy.^2) - k*(Ix2 + Iy2).^2;
            R = (R - min(R(:))) / (max(R(:))-min(R(:)) + eps);
            mask = (R > thresh) & imregionalmax(R);
            [y,x] = find(mask);
            corners = [x,y,R(sub2ind(size(R),y,x))];
        end

        function imgReduced = reduceImage(app, I)
            % Proper pyramid-style reduce: blur then downsample by 2
            if size(I,3)==3
                out = zeros(round(size(I,1)/2), round(size(I,2)/2), 3);
                for c=1:3
                    ch = im2double(I(:,:,c));
                    chb = imgaussfilt(ch, 1.0);
                    out(:,:,c) = imresize(chb, 0.5, 'bilinear');
                end
                imgReduced = im2uint8(mat2gray(out));
            else
                ch = im2double(I);
                chb = imgaussfilt(ch, 1.0);
                imgReduced = im2uint8(imresize(chb, 0.5, 'bilinear'));
            end
        end

        function imgExpanded = expandImage(app, I)
            % Proper pyramid-style expand: upsample by 2 then blur
            if size(I,3)==3
                out = zeros(size(I,1)*2, size(I,2)*2, 3);
                for c=1:3
                    ch = im2double(I(:,:,c));
                    up = imresize(ch, 2, 'bilinear');
                    out(:,:,c) = imgaussfilt(up, 1.0);
                end
                imgExpanded = im2uint8(mat2gray(out));
            else
                ch = im2double(I);
                up = imresize(ch, 2, 'bilinear');
                imgExpanded = im2uint8(imgaussfilt(up, 1.0));
            end
        end

        function resp = filterBankBlurCenter(app, I)
            % create blurred image where edges are blurred and middle remains focused
            % returns a grayscale result (double 0..1)
            if size(I,3)==3
                Igray = im2double(rgb2gray(I));
            else
                Igray = im2double(I);
            end
            [H,W] = size(Igray);
            % gaussian-blur of whole image
            sigmaBlur = max(1, round(min(H,W)/80)); % adaptive sigma
            blurred = imgaussfilt(Igray, sigmaBlur);

            % radial weight map: 1 at center (keep), 0 at borders (blur)
            [X,Y] = meshgrid(1:W,1:H);
            cx = (W+1)/2; cy = (H+1)/2;
            maxR = sqrt(cx^2 + cy^2);
            R = sqrt((X-cx).^2 + (Y-cy).^2) / maxR; % 0..1
            % create smooth transition (center weight near 1)
            falloff = 2.5; % controls transition steepness
            w = exp(-(R.^2)*falloff);
            % combine: center keeps original, edges take blurred
            resp = w .* Igray + (1 - w) .* blurred;
            resp = mat2gray(resp);
        end

        function pts = detectLineIntersections(app, Igray)
            % Detect prominent lines via Hough transform and compute intersections
            % Igray expected double grayscale (0..1)
            if size(Igray,3)~=1, Igray = im2double(rgb2gray(Igray)); end
            BW = edge(Igray,'Canny');
            % Hough transform
            [H,theta,rho] = hough(BW);
            peaks = houghpeaks(H, 12, 'Threshold', ceil(0.3*max(H(:))));
            if isempty(peaks)
                pts = [];
                return;
            end
            lines = houghlines(BW, theta, rho, peaks, 'FillGap', 10, 'MinLength', 20);
            nL = numel(lines);
            if nL < 2
                pts = [];
                return;
            end
            intersections = [];
            for i=1:nL-1
                for j=i+1:nL
                    % each line has point1 and point2 (x,y)
                    L1 = [lines(i).point1; lines(i).point2]; % [x1 y1; x2 y2]
                    L2 = [lines(j).point1; lines(j).point2];
                    [xi, yi, ok] = app.lineIntersection(L1(1,:), L1(2,:), L2(1,:), L2(2,:));
                    if ok
                        % Only keep intersections within image bounds
                        [Himg, Wimg] = size(Igray);
                        if xi >= 1 && xi <= Wimg && yi >= 1 && yi <= Himg
                            intersections(end+1,:) = [xi, yi]; %#ok<AGROW>
                        end
                    end
                end
            end
            if isempty(intersections)
                pts = [];
            else
                % remove duplicates (close points) without using pdist2
                n = size(intersections,1);
                keep = true(n,1);
                for i=1:n
                    if ~keep(i), continue; end
                    for j=i+1:n
                        if ~keep(j), continue; end
                        if sqrt((intersections(i,1)-intersections(j,1))^2 + (intersections(i,2)-intersections(j,2))^2) < 5
                            keep(j) = false;
                        end
                    end
                end
                pts = intersections(keep,:);
            end
        end

        function [xi, yi, ok] = lineIntersection(app, p1, p2, p3, p4)
            % compute intersection of lines (p1->p2) and (p3->p4)
            % p are 1x2 [x y]
            x1 = p1(1); y1 = p1(2);
            x2 = p2(1); y2 = p2(2);
            x3 = p3(1); y3 = p3(2);
            x4 = p4(1); y4 = p4(2);
            denom = (x1-x2)*(y3-y4) - (y1-y2)*(x3-x4);
            if abs(denom) < 1e-6
                xi = NaN; yi = NaN; ok = false;
                return;
            end
            xi = ((x1*y2 - y1*x2)*(x3 - x4) - (x1 - x2)*(x3*y4 - y3*x4)) / denom;
            yi = ((x1*y2 - y1*x2)*(y3 - y4) - (y1 - y2)*(x3*y4 - y3*x4)) / denom;
            ok = true;
        end

        function updateStatus(app, txt)
            app.StatusLabel.Text = ['Status: ' txt];
            drawnow;
        end
    end
end
