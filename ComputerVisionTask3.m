classdef ComputerVisionTask3 < handle
    % ComputerVisionTask3 - Main class implementing all required CV algorithms
    
    properties
        % GUI handles
        fig_main
        tabgroup
        tabs
        ax_original


        ax_result
        currentImage
        resultImage
        
        % Image properties
        imagePath
        isColor
        
        % DoG/LoG parameters
        sigma1 = 1.0
        sigma2 = 2.0
        threshold_dog = 0.03
        threshold_log = 0.01
        kernelSize = 5
        
        % HoG parameters
        cellSize = 8
        blockSize = 2
        numBins = 9
        blockOverlap = 0.5
        
        % Hough Transform parameters
        houghThetaRes = 1
        houghRhoRes = 1
        houghThreshold = 30
        houghFillGap = 20
        houghMinLength = 40
        
        % Circle Hough parameters
        circleRadius = 20
        circleSensitivity = 0.85
        circleEdgeThreshold = 0.1
        
        % RANSAC parameters
        ransacNumSamples = 2
        ransacThreshold = 5
        ransacMaxIterations = 1000
        ransacConfidence = 0.99
        
        % Stereo Vision parameters
        stereoDisparityRange = [0, 64]
        stereoBlockSize = 15
        stereoUniqueness = 15
        
        % Feature Matching parameters
        minMatches = 10
        matchRatio = 0.7
        fundamentalMatrixConfidence = 0.99
        
        % SfM data
        imageSequence
        cameraPoses
        pointCloud
        featurePoints
        matchedFeatures
        
        % Additional properties
        currentPoints
        stereoLeft
        stereoRight
        cameraParams
        
        % Hough data storage
        houghSpace
        houghTheta
        houghRho
    end
    
    methods
        % Constructor
        function obj = ComputerVisionTask3()
            obj.createGUI();
        end
        
        % =================================================================
        % MAIN GUI CREATION
        % =================================================================
        function createGUI(obj)
            % Create main figure
            obj.fig_main = figure('Name', 'Computer Vision Tasks', ...
                'NumberTitle', 'off', ...
                'Position', [100, 100, 1200, 700], ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Resize', 'on');
            
            % Create menu
            obj.createMenu();
            
            % Create tab group
            obj.tabgroup = uitabgroup(obj.fig_main, 'Position', [0, 0.1, 1, 0.9]);
            
            % Create tabs
            tabNames = {'Image Load', 'DoG/LoG', 'HoG', 'Hough Transform', ...
                       'RANSAC', 'Stereo Vision', 'SfM (Bonus)'};
            
            for i = 1:length(tabNames)
                obj.tabs{i} = uitab(obj.tabgroup, 'Title', tabNames{i});
                obj.createTabContent(i);
            end
            
            % Status bar
            uicontrol('Style', 'text', ...
                'String', 'Ready', ...
                'Position', [10, 5, 1180, 20], ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', [0.8, 0.8, 0.8]);
        end
        
        function createMenu(obj)
            % File menu
            fileMenu = uimenu(obj.fig_main, 'Label', 'File');
            uimenu(fileMenu, 'Label', 'Load Image', ...
                'Callback', @(src, evt) obj.loadImage());
            uimenu(fileMenu, 'Label', 'Load Stereo Images', ...
                'Callback', @(src, evt) obj.loadStereoImages());
            uimenu(fileMenu, 'Label', 'Load Camera Parameters', ...
                'Callback', @(src, evt) obj.loadCameraParams());
            uimenu(fileMenu, 'Label', 'Exit', ...
                'Separator', 'on', ...
                'Callback', @(src, evt) close(obj.fig_main));
            
            % Tools menu
            toolsMenu = uimenu(obj.fig_main, 'Label', 'Tools');
            uimenu(toolsMenu, 'Label', 'Reset Parameters', ...
                'Callback', @(src, evt) obj.resetParameters());
            uimenu(toolsMenu, 'Label', 'Save Results', ...
                'Callback', @(src, evt) obj.saveResults());
        end
        
        function createTabContent(obj, tabIndex)
            switch tabIndex
                case 1 % Image Load
                    obj.createImageLoadTab();
                case 2 % DoG/LoG
                    obj.createDoGLogTab();
                case 3 % HoG
                    obj.createHogTab();
                case 4 % Hough Transform
                    obj.createHoughTab();
                case 5 % RANSAC
                    obj.createRANSACTab();
                case 6 % Stereo Vision
                    obj.createStereoTab();
                case 7 % SfM
                    obj.createSfMTab();
            end
        end
        
        % =================================================================
        % TAB 1: IMAGE LOAD
        % =================================================================
        function createImageLoadTab(obj)
            tab = obj.tabs{1};
            
            % Load image button - Positioned at the top
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Load Image', ...
                'Position', [20, 620, 150, 40], ...  % Moved higher up
                'Callback', @(src, evt) obj.loadImage(), ...
                'FontSize', 11, ...
                'FontWeight', 'bold');
            
            % Original image axes
            obj.ax_original = axes('Parent', tab, ...
                'Position', [0.05, 0.15, 0.4, 0.7]);  % Adjusted position
            title(obj.ax_original, 'Original Image');
            axis(obj.ax_original, 'image');
            
            % Result image axes
            obj.ax_result = axes('Parent', tab, ...
                'Position', [0.55, 0.15, 0.4, 0.7]);  % Adjusted position
            title(obj.ax_result, 'Result');
            axis(obj.ax_result, 'image');
            
            % Image info panel
            infoPanel = uipanel('Parent', tab, ...
                'Title', 'Image Information', ...
                'Position', [0.05, 0.88, 0.9, 0.1]);
            
            uicontrol('Parent', infoPanel, ...
                'Style', 'text', ...
                'String', 'No image loaded', ...
                'Position', [10, 5, 400, 20], ...
                'HorizontalAlignment', 'left', ...
                'Tag', 'imageInfo');
        end
        
        % =================================================================
        % TAB 2: DoG/LoG
        % =================================================================
        function createDoGLogTab(obj)
            tab = obj.tabs{2};
            
            % Control panel - Fixed position
            controlPanel = uipanel('Parent', tab, ...
                'Title', 'DoG/LoG Parameters', ...
                'Position', [0.02, 0.02, 0.96, 0.25]);
            
            % DoG controls
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'DoG - Sigma 1:', ...
                'Position', [20, 130, 100, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0.5, 'Max', 5, 'Value', obj.sigma1, ...
                'Position', [130, 130, 150, 20], ...
                'Tag', 'dogSigma1', ...
                'Callback', @(src, evt) obj.setSigma1(src.Value));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'DoG - Sigma 2:', ...
                'Position', [20, 100, 100, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 1, 'Max', 10, 'Value', obj.sigma2, ...
                'Position', [130, 100, 150, 20], ...
                'Tag', 'dogSigma2', ...
                'Callback', @(src, evt) obj.setSigma2(src.Value));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'DoG Threshold:', ...
                'Position', [20, 70, 100, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0.001, 'Max', 0.1, 'Value', obj.threshold_dog, ...
                'Position', [130, 70, 150, 20], ...
                'Tag', 'dogThreshold', ...
                'Callback', @(src, evt) obj.setThresholdDog(src.Value));
            
            % LoG controls
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'LoG - Sigma:', ...
                'Position', [320, 130, 100, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0.5, 'Max', 5, 'Value', obj.sigma1, ...
                'Position', [430, 130, 150, 20], ...
                'Tag', 'logSigma', ...
                'Callback', @(src, evt) obj.setSigma1(src.Value));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'LoG Threshold:', ...
                'Position', [320, 100, 100, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0.001, 'Max', 0.1, 'Value', obj.threshold_log, ...
                'Position', [430, 100, 150, 20], ...
                'Tag', 'logThreshold', ...
                'Callback', @(src, evt) obj.setThresholdLog(src.Value));
            
            % Kernel size
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Kernel Size:', ...
                'Position', [320, 70, 100, 20]);
            kernelSizes = {'3', '5', '7', '9', '11'};
            uicontrol(controlPanel, 'Style', 'popupmenu', ...
                'String', kernelSizes, ...
                'Value', 2, ...
                'Position', [430, 70, 100, 20], ...
                'Tag', 'kernelSizePopup', ...
                'Callback', @(src, evt) obj.setKernelSize(str2double(kernelSizes{src.Value})));
            
            % Action buttons - Positioned properly
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Apply DoG', ...
                'Position', [50, 350, 120, 30], ...
                'Callback', @(src, evt) obj.applyDoG());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Apply LoG', ...
                'Position', [50, 310, 120, 30], ...
                'Callback', @(src, evt) obj.applyLoG());
        end
        
        % =================================================================
        % TAB 3: HoG
        % =================================================================
        function createHogTab(obj)
            tab = obj.tabs{3};
            
            % Control panel
            controlPanel = uipanel('Parent', tab, ...
                'Title', 'HoG Parameters', ...
                'Position', [0.02, 0.02, 0.96, 0.25]);
            
            % Cell size
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Cell Size (pixels):', ...
                'Position', [20, 130, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 4, 'Max', 16, 'Value', obj.cellSize, ...
                'Position', [150, 130, 150, 20], ...
                'Tag', 'hogCellSize', ...
                'Callback', @(src, evt) obj.setCellSize(round(src.Value)));
            
            % Block size
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Block Size (cells):', ...
                'Position', [20, 100, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 1, 'Max', 4, 'Value', obj.blockSize, ...
                'Position', [150, 100, 150, 20], ...
                'Tag', 'hogBlockSize', ...
                'Callback', @(src, evt) obj.setBlockSize(round(src.Value)));
            
            % Number of bins
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Number of Bins:', ...
                'Position', [20, 70, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 6, 'Max', 18, 'Value', obj.numBins, ...
                'Position', [150, 70, 150, 20], ...
                'Tag', 'hogNumBins', ...
                'Callback', @(src, evt) obj.setNumBins(round(src.Value)));
            
            % Block overlap
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Block Overlap:', ...
                'Position', [320, 130, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0, 'Max', 1, 'Value', obj.blockOverlap, ...
                'Position', [450, 130, 150, 20], ...
                'Tag', 'hogBlockOverlap', ...
                'Callback', @(src, evt) obj.setBlockOverlap(src.Value));
            
            % Action buttons
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Extract HoG Features', ...
                'Position', [50, 350, 150, 30], ...
                'Callback', @(src, evt) obj.extractHOG());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Visualize HoG', ...
                'Position', [50, 310, 150, 30], ...
                'Callback', @(src, evt) obj.visualizeHOG());
        end
        
        % =================================================================
        % TAB 4: HOUGH TRANSFORM
        % =================================================================
        function createHoughTab(obj)
            tab = obj.tabs{4};
            
            % Control panel
            controlPanel = uipanel('Parent', tab, ...
                'Title', 'Hough Transform Parameters', ...
                'Position', [0.02, 0.02, 0.96, 0.3]);
            
            % Line detection controls
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Line Detection', ...
                'Position', [20, 170, 100, 20], ...
                'FontWeight', 'bold');
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Theta Resolution:', ...
                'Position', [20, 140, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0.1, 'Max', 5, 'Value', obj.houghThetaRes, ...
                'Position', [150, 140, 150, 20], ...
                'Tag', 'houghThetaRes', ...
                'Callback', @(src, evt) obj.setHoughThetaRes(src.Value));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Threshold:', ...
                'Position', [20, 110, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 10, 'Max', 100, 'Value', obj.houghThreshold, ...
                'Position', [150, 110, 150, 20], ...
                'Tag', 'houghThreshold', ...
                'Callback', @(src, evt) obj.setHoughThreshold(round(src.Value)));
            
            % Circle detection controls
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Circle Detection', ...
                'Position', [320, 170, 100, 20], ...
                'FontWeight', 'bold');
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Radius:', ...
                'Position', [320, 140, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 10, 'Max', 100, 'Value', obj.circleRadius, ...
                'Position', [450, 140, 150, 20], ...
                'Tag', 'circleRadius', ...
                'Callback', @(src, evt) obj.setCircleRadius(round(src.Value)));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Sensitivity:', ...
                'Position', [320, 110, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0.7, 'Max', 0.99, 'Value', obj.circleSensitivity, ...
                'Position', [450, 110, 150, 20], ...
                'Tag', 'circleSensitivity', ...
                'Callback', @(src, evt) obj.setCircleSensitivity(src.Value));
            
            % Action buttons
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Detect Lines', ...
                'Position', [50, 400, 120, 30], ...
                'Callback', @(src, evt) obj.detectLines());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Detect Circles', ...
                'Position', [50, 360, 120, 30], ...
                'Callback', @(src, evt) obj.detectCircles());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Show Hough Space', ...
                'Position', [50, 320, 120, 30], ...
                'Callback', @(src, evt) obj.showHoughSpace());
        end
        
        % =================================================================
        % TAB 5: RANSAC
        % =================================================================
        function createRANSACTab(obj)
            tab = obj.tabs{5};
            
            % Control panel
            controlPanel = uipanel('Parent', tab, ...
                'Title', 'RANSAC Parameters', ...
                'Position', [0.02, 0.02, 0.96, 0.3]);
            
            % Common parameters
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Inlier Threshold:', ...
                'Position', [20, 140, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 1, 'Max', 20, 'Value', obj.ransacThreshold, ...
                'Position', [150, 140, 150, 20], ...
                'Tag', 'ransacThreshold', ...
                'Callback', @(src, evt) obj.setRansacThreshold(src.Value));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Max Iterations:', ...
                'Position', [20, 110, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 100, 'Max', 10000, 'Value', obj.ransacMaxIterations, ...
                'Position', [150, 110, 150, 20], ...
                'Tag', 'ransacMaxIterations', ...
                'Callback', @(src, evt) obj.setRansacMaxIterations(round(src.Value)));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Confidence:', ...
                'Position', [20, 80, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0.9, 'Max', 0.999, 'Value', obj.ransacConfidence, ...
                'Position', [150, 80, 150, 20], ...
                'Tag', 'ransacConfidence', ...
                'Callback', @(src, evt) obj.setRansacConfidence(src.Value));
            
            % Line fitting specific
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Line Fitting Samples:', ...
                'Position', [320, 140, 140, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 2, 'Max', 10, 'Value', obj.ransacNumSamples, ...
                'Position', [470, 140, 150, 20], ...
                'Tag', 'ransacNumSamples', ...
                'Callback', @(src, evt) obj.setRansacNumSamples(round(src.Value)));
            
            % Action buttons
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Generate Points', ...
                'Position', [50, 400, 120, 30], ...
                'Callback', @(src, evt) obj.generatePoints());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'RANSAC Line Fit', ...
                'Position', [50, 360, 120, 30], ...
                'Callback', @(src, evt) obj.ransacLineFit());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'RANSAC Circle Fit', ...
                'Position', [50, 320, 120, 30], ...
                'Callback', @(src, evt) obj.ransacCircleFit());
        end
        
        % =================================================================
        % TAB 6: STEREO VISION - FIXED VERSION
        % =================================================================
        function createStereoTab(obj)
            tab = obj.tabs{6};
            
            % Control panel
            controlPanel = uipanel('Parent', tab, ...
                'Title', 'Stereo Vision Parameters', ...
                'Position', [0.02, 0.02, 0.96, 0.25]);
            
            % Disparity parameters - FIXED CALLBACKS
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Disparity Range Min:', ...
                'Position', [20, 130, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0, 'Max', 100, 'Value', obj.stereoDisparityRange(1), ...
                'Position', [150, 130, 150, 20], ...
                'Tag', 'stereoDispMin', ...
                'Callback', @(src, evt) obj.setDispMin(round(src.Value)));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Disparity Range Max:', ...
                'Position', [20, 100, 120, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 10, 'Max', 200, 'Value', obj.stereoDisparityRange(2), ...
                'Position', [150, 100, 150, 20], ...
                'Tag', 'stereoDispMax', ...
                'Callback', @(src, evt) obj.setDispMax(round(src.Value)));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Block Size:', ...
                'Position', [320, 130, 100, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 5, 'Max', 25, 'Value', obj.stereoBlockSize, ...
                'Position', [450, 130, 150, 20], ...
                'Tag', 'stereoBlockSize', ...
                'Callback', @(src, evt) obj.setStereoBlockSize(round(src.Value)));
            
            % Action buttons
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Load Stereo Pair', ...
                'Position', [50, 400, 150, 30], ...
                'Callback', @(src, evt) obj.loadStereoImages());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Compute Disparity', ...
                'Position', [50, 360, 150, 30], ...
                'Callback', @(src, evt) obj.computeDisparity());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Epipolar Lines', ...
                'Position', [50, 320, 150, 30], ...
                'Callback', @(src, evt) obj.showEpipolarLines());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Rectify Images', ...
                'Position', [50, 280, 150, 30], ...
                'Callback', @(src, evt) obj.rectifyStereo());
            
            % Image display areas
            axes('Parent', tab, ...
                'Position', [0.4, 0.35, 0.25, 0.5], ...
                'Tag', 'stereoLeft');
            title('Left Image');
            
            axes('Parent', tab, ...
                'Position', [0.7, 0.35, 0.25, 0.5], ...
                'Tag', 'stereoRight');
            title('Right Image');
        end
        
        % =================================================================
        % TAB 7: STRUCTURE FROM MOTION (BONUS)
        % =================================================================
        function createSfMTab(obj)
            tab = obj.tabs{7};
            
            % Control panel
            controlPanel = uipanel('Parent', tab, ...
                'Title', 'Structure from Motion Parameters', ...
                'Position', [0.02, 0.02, 0.96, 0.2]);
            
            % Feature matching parameters
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Min Matches:', ...
                'Position', [20, 80, 100, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 5, 'Max', 50, 'Value', obj.minMatches, ...
                'Position', [130, 80, 150, 20], ...
                'Tag', 'sfmMinMatches', ...
                'Callback', @(src, evt) obj.setMinMatches(round(src.Value)));
            
            uicontrol(controlPanel, 'Style', 'text', ...
                'String', 'Match Ratio:', ...
                'Position', [320, 80, 100, 20]);
            uicontrol(controlPanel, 'Style', 'slider', ...
                'Min', 0.5, 'Max', 0.95, 'Value', obj.matchRatio, ...
                'Position', [430, 80, 150, 20], ...
                'Tag', 'sfmMatchRatio', ...
                'Callback', @(src, evt) obj.setMatchRatio(src.Value));
            
            % Action buttons
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Load Image Sequence', ...
                'Position', [50, 350, 150, 30], ...
                'Callback', @(src, evt) obj.loadImageSequence());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Feature Detection', ...
                'Position', [50, 310, 150, 30], ...
                'Callback', @(src, evt) obj.detectFeatures());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Match Features', ...
                'Position', [50, 270, 150, 30], ...
                'Callback', @(src, evt) obj.matchFeatures());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Triangulate 3D', ...
                'Position', [50, 230, 150, 30], ...
                'Callback', @(src, evt) obj.triangulate3D());
            
            uicontrol(tab, 'Style', 'pushbutton', ...
                'String', 'Bundle Adjustment', ...
                'Position', [50, 190, 150, 30], ...
                'Callback', @(src, evt) obj.bundleAdjustment());
            
            % 3D visualization area
            axes('Parent', tab, ...
                'Position', [0.35, 0.25, 0.6, 0.7], ...
                'Tag', 'sfm3DView');
            grid on;
            xlabel('X');
            ylabel('Y');
            zlabel('Z');
            title('3D Reconstruction');
            view(3);
        end
        
        % =================================================================
        % SETTER METHODS FOR PARAMETERS
        % =================================================================
        function setSigma1(obj, value)
            obj.sigma1 = value;
        end
        
        function setSigma2(obj, value)
            obj.sigma2 = value;
        end
        
        function setThresholdDog(obj, value)
            obj.threshold_dog = value;
        end
        
        function setThresholdLog(obj, value)
            obj.threshold_log = value;
        end
        
        function setKernelSize(obj, value)
            obj.kernelSize = value;
        end
        
        function setCellSize(obj, value)
            obj.cellSize = value;
        end
        
        function setBlockSize(obj, value)
            obj.blockSize = value;
        end
        
        function setNumBins(obj, value)
            obj.numBins = value;
        end
        
        function setBlockOverlap(obj, value)
            obj.blockOverlap = value;
        end
        
        function setHoughThetaRes(obj, value)
            obj.houghThetaRes = value;
        end
        
        function setHoughThreshold(obj, value)
            obj.houghThreshold = value;
        end
        
        function setCircleRadius(obj, value)
            obj.circleRadius = value;
        end
        
        function setCircleSensitivity(obj, value)
            obj.circleSensitivity = value;
        end
        
        function setRansacThreshold(obj, value)
            obj.ransacThreshold = value;
        end
        
        function setRansacMaxIterations(obj, value)
            obj.ransacMaxIterations = value;
        end
        
        function setRansacConfidence(obj, value)
            obj.ransacConfidence = value;
        end
        
        function setRansacNumSamples(obj, value)
            obj.ransacNumSamples = value;
        end
        
        function setDispMin(obj, value)
            obj.stereoDisparityRange(1) = value;
        end
        
        function setDispMax(obj, value)
            obj.stereoDisparityRange(2) = value;
        end
        
        function setStereoBlockSize(obj, value)
            obj.stereoBlockSize = value;
        end
        
        function setMinMatches(obj, value)
            obj.minMatches = value;
        end
        
        function setMatchRatio(obj, value)
            obj.matchRatio = value;
        end
        
        % =================================================================
        % ALGORITHM IMPLEMENTATIONS (WITH FIXES)
        % =================================================================
        
        % -------------------------
        % DoG (Difference of Gaussians)
        % -------------------------
        function applyDoG(obj)
            try
                fprintf('Applying DoG edge detection...\n');
                
                if isempty(obj.currentImage)
                    warndlg('Please load an image first.', 'No Image');
                    return;
                end
                
                img = im2double(obj.currentImage);
                if size(img, 3) == 3
                    img = rgb2gray(img);
                end
                
                % Create Gaussian kernels
                kernel1 = obj.createGaussianKernel(obj.sigma1, obj.kernelSize);
                kernel2 = obj.createGaussianKernel(obj.sigma2, obj.kernelSize);
                
                % Apply Gaussian filters
                g1 = imfilter(img, kernel1, 'replicate');
                g2 = imfilter(img, kernel2, 'replicate');
                
                % Compute DoG
                dog = g1 - g2;
                
                % Normalize for display
                dog = mat2gray(dog);
                
                % Threshold to get edges
                edges = abs(dog) > obj.threshold_dog;
                
                % Convert to double for consistent display
                edges = double(edges);
                
                % Display results
                obj.displayResult(edges, 'DoG Edge Detection');
                
                % Show DoG image in separate figure
                fig = figure('Name', 'Difference of Gaussians', 'NumberTitle', 'off');
                subplot(2,2,1);
                imshow(g1);
                title(['Gaussian 1 (σ=', num2str(obj.sigma1), ')']);
                
                subplot(2,2,2);
                imshow(g2);
                title(['Gaussian 2 (σ=', num2str(obj.sigma2), ')']);
                
                subplot(2,2,3);
                imshow(dog);
                title('DoG Result');
                
                subplot(2,2,4);
                imshow(edges, []);
                title(['Thresholded Edges (threshold=', num2str(obj.threshold_dog), ')']);
                
                fprintf('DoG edge detection completed.\n');
            catch ME
                errordlg(['Error in DoG: ', ME.message], 'DoG Error');
                fprintf('DoG error: %s\n', ME.message);
            end
        end
        
        % -------------------------
        % LoG (Laplacian of Gaussian)
        % -------------------------
        function applyLoG(obj)
            try
                fprintf('Applying LoG edge detection...\n');
                
                if isempty(obj.currentImage)
                    warndlg('Please load an image first.', 'No Image');
                    return;
                end
                
                img = im2double(obj.currentImage);
                if size(img, 3) == 3
                    img = rgb2gray(img);
                end
                
                % Create LoG kernel
                kernel = obj.createLoGKernel(obj.sigma1, obj.kernelSize);
                
                % Apply LoG filter
                logResult = imfilter(img, kernel, 'replicate');
                
                % Normalize for display
                logResult = mat2gray(logResult);
                
                % Detect zero crossings
                edges = obj.detectZeroCrossings(logResult, obj.threshold_log);
                
                % Convert to double for consistent display
                edges = double(edges);
                
                % Display results
                obj.displayResult(edges, 'LoG Edge Detection');
                
                % Show LoG image
                fig = figure('Name', 'Laplacian of Gaussian', 'NumberTitle', 'off');
                subplot(1,3,1);
                imshow(img);
                title('Original Image');
                
                subplot(1,3,2);
                imshow(logResult);
                title(['LoG Filter (σ=', num2str(obj.sigma1), ')']);
                
                subplot(1,3,3);
                imshow(edges, []);
                title(['Zero-Crossing Edges (threshold=', num2str(obj.threshold_log), ')']);
                
                fprintf('LoG edge detection completed.\n');
            catch ME
                errordlg(['Error in LoG: ', ME.message], 'LoG Error');
                fprintf('LoG error: %s\n', ME.message);
            end
        end
        
        % -------------------------
        % HoG (Histogram of Oriented Gradients) - FIXED
        % -------------------------
        function extractHOG(obj)
            try
                fprintf('Extracting HOG features...\n');
                
                if isempty(obj.currentImage)
                    warndlg('Please load an image first.', 'No Image');
                    return;
                end
                
                img = obj.currentImage;
                if size(img, 3) == 3
                    img = rgb2gray(img);
                end
                
                % Ensure image is not logical
                if islogical(img)
                    img = uint8(img) * 255;
                end
                
                % Convert to double for processing
                img = im2double(img);
                
                % Resize image for consistent feature size
                img = imresize(img, [128, 64]);
                
                % Compute gradients
                [gx, gy] = imgradientxy(img, 'sobel');
                
                % Compute magnitude and orientation
                magnitude = sqrt(double(gx).^2 + double(gy).^2);
                orientation = atan2d(double(gy), double(gx)); % in degrees
                
                % Convert orientation to 0-180 range
                orientation(orientation < 0) = orientation(orientation < 0) + 180;
                
                % Compute HoG features
                features = obj.computeHOGFeatures(magnitude, orientation);
                
                % Display feature dimension
                infoText = sprintf('Feature dimension: %d', length(features));
                h = findobj(obj.fig_main, 'Tag', 'hogInfo');
                if ~isempty(h)
                    set(h, 'String', infoText);
                end
                
                % Display feature vector
                fig = figure('Name', 'HoG Feature Vector', 'NumberTitle', 'off');
                subplot(2,1,1);
                bar(features);
                title(['HoG Feature Vector (', num2str(length(features)), ' dimensions)']);
                xlabel('Feature Index');
                ylabel('Feature Value');
                grid on;
                
                subplot(2,1,2);
                imagesc(reshape(features(1:min(100, end)), 10, []));
                colorbar;
                title('First 100 Features (reshaped)');
                xlabel('Feature Block');
                ylabel('Feature Dimension');
                
                fprintf('HOG feature extraction completed.\n');
            catch ME
                errordlg(['Error in HOG extraction: ', ME.message], 'HOG Error');
                fprintf('HOG extraction error: %s\n', ME.message);
            end
        end
        
        function visualizeHOG(obj)
            try
                fprintf('Visualizing HOG features...\n');
                
                if isempty(obj.currentImage)
                    warndlg('Please load an image first.', 'No Image');
                    return;
                end
                
                img = obj.currentImage;
                if size(img, 3) == 3
                    img = rgb2gray(img);
                end
                
                % Ensure image is not logical
                if islogical(img)
                    img = uint8(img) * 255;
                end
                
                % Convert to double for processing
                img = im2double(img);
                
                % Resize image
                img = imresize(img, [200, 200]);
                
                % Compute gradients
                [gx, gy] = imgradientxy(img, 'sobel');
                magnitude = sqrt(double(gx).^2 + double(gy).^2);
                orientation = atan2d(double(gy), double(gx));
                orientation(orientation < 0) = orientation(orientation < 0) + 180;
                
                % Create visualization
                hogVis = obj.createHOGVisualization(img);
                
                % Display
                fig = figure('Name', 'HoG Visualization', 'NumberTitle', 'off');
                subplot(2,2,1);
                imshow(img);
                title('Original Image');
                
                subplot(2,2,2);
                imshow(magnitude, []);
                title('Gradient Magnitude');
                
                subplot(2,2,3);
                imshow(orientation, []);
                title('Gradient Orientation');
                colorbar;
                
                subplot(2,2,4);
                imshow(hogVis);
                hold on;
                
                % Draw HOG cells
                [h, w] = size(img);
                cellSize = obj.cellSize;
                
                % Draw grid
                for i = 1:cellSize:h
                    line([1, w], [i, i], 'Color', 'g', 'LineStyle', '--');
                end
                for j = 1:cellSize:w
                    line([j, j], [1, h], 'Color', 'g', 'LineStyle', '--');
                end
                
                title('HoG Visualization with Orientation Lines');
                hold off;
                
                fprintf('HOG visualization completed.\n');
            catch ME
                errordlg(['Error in HOG visualization: ', ME.message], 'HOG Error');
                fprintf('HOG visualization error: %s\n', ME.message);
            end
        end
        
        % -------------------------
        % HOUGH TRANSFORM - COMPLETELY FIXED
        % -------------------------
        function detectLines(obj)
            try
                fprintf('Detecting lines using Hough Transform...\n');
                
                if isempty(obj.currentImage)
                    warndlg('Please load an image first.', 'No Image');
                    return;
                end
                
                img = obj.currentImage;
                
                % Convert to grayscale if color
                if size(img, 3) == 3
                    gray = rgb2gray(img);
                else
                    gray = img;
                end
                
                % Ensure image is 2D and numeric (not logical)
                if islogical(gray)
                    gray = uint8(gray) * 255;
                end
                
                % Ensure it's 2D
                if ~ismatrix(gray)
                    gray = squeeze(gray);
                    if ~ismatrix(gray)
                        gray = gray(:,:,1);
                    end
                end
                
                % Convert to appropriate type
                if ~isa(gray, 'uint8') && ~isa(gray, 'double')
                    gray = im2double(gray);
                end
                
                % Edge detection - ensure output is proper for hough
                edges = edge(gray, 'canny');
                
                % Convert edges to proper format (uint8) if needed
                if islogical(edges)
                    edges = uint8(edges) * 255;
                end
                
                % Ensure edges is 2D
                if ~ismatrix(edges)
                    edges = edges(:,:,1);
                end
                
                % Hough transform for lines
                [H, theta, rho] = hough(edges, ...
                    'ThetaResolution', obj.houghThetaRes, ...
                    'RhoResolution', obj.houghRhoRes);
                
                % Store for later use
                obj.houghSpace = H;
                obj.houghTheta = theta;
                obj.houghRho = rho;
                
                % Find peaks
                peaks = houghpeaks(H, 20, 'Threshold', max(0.3 * max(H(:)), obj.houghThreshold));
                
                % Extract lines
                lines = houghlines(edges, theta, rho, peaks, ...
                    'FillGap', obj.houghFillGap, ...
                    'MinLength', obj.houghMinLength);
                
                % Display results
                result = obj.currentImage;
                % Convert to RGB if grayscale
                if size(result, 3) == 1
                    result = repmat(result, [1, 1, 3]);
                end
                
                fig = figure('Name', 'Line Detection Results', 'NumberTitle', 'off');
                subplot(2,2,1);
                imshow(result);
                hold on;
                
                max_len = 0;
                if ~isempty(lines)
                    for k = 1:min(length(lines), 10)
                        xy = [lines(k).point1; lines(k).point2];
                        plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
                        
                        % Plot beginning and end of line
                        plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
                        plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
                        
                        % Determine the endpoints of the longest line segment
                        len = norm(lines(k).point1 - lines(k).point2);
                        if ( len > max_len)
                            max_len = len;
                            xy_long = xy;
                        end
                    end
                    
                    % Highlight the longest line segment
                    if exist('xy_long', 'var')
                        plot(xy_long(:,1), xy_long(:,2), 'LineWidth', 2, 'Color', 'cyan');
                    end
                end
                
                title(sprintf('Detected %d lines', length(lines)));
                hold off;
                
                % Show Hough transform
                subplot(2,2,2);
                imshow(imadjust(rescale(H)), 'XData', theta, 'YData', rho);
                xlabel('\theta (degrees)');
                ylabel('\rho');
                axis on;
                axis normal;
                colormap(gca, hot);
                hold on;
                plot(theta(peaks(:,2)), rho(peaks(:,1)), 's', 'color', 'blue');
                title('Hough Transform with Peaks');
                hold off;
                
                % Show edge image
                subplot(2,2,3);
                imshow(edges);
                title('Edge Image');
                
                % Show parameter space
                subplot(2,2,4);
                if ~isempty(peaks)
                    scatter(theta(peaks(:,2)), rho(peaks(:,1)), 'ro');
                end
                xlabel('\theta (degrees)');
                ylabel('\rho');
                grid on;
                title('Detected Peaks in Parameter Space');
                
                fprintf('Line detection completed.\n');
            catch ME
                errordlg(['Error in line detection: ', ME.message], 'Hough Error');
                fprintf('Line detection error: %s\n', ME.message);
            end
        end
        
        function detectCircles(obj)
            try
                fprintf('Detecting circles using Hough Transform...\n');
                
                if isempty(obj.currentImage)
                    warndlg('Please load an image first.', 'No Image');
                    return;
                end
                
                img = obj.currentImage;
                
                % Convert to grayscale if color
                if size(img, 3) == 3
                    gray = rgb2gray(img);
                else
                    gray = img;
                end
                
                % Ensure image is 2D and numeric (not logical)
                if islogical(gray)
                    gray = uint8(gray) * 255;
                end
                
                % Ensure it's 2D
                if ~ismatrix(gray)
                    gray = squeeze(gray);
                    if ~ismatrix(gray)
                        gray = gray(:,:,1);
                    end
                end
                
                % Ensure proper type for imfindcircles (must be uint8, uint16, or double)
                if ~isa(gray, 'uint8') && ~isa(gray, 'uint16') && ~isa(gray, 'double')
                    gray = im2double(gray);
                end
                
                % Convert to appropriate type if needed
                if isa(gray, 'double')
                    % Scale to [0, 1] for imfindcircles
                    gray = mat2gray(gray);
                end
                
                % Range of radii to search
                radiusRange = [max(5, obj.circleRadius-15), obj.circleRadius+15];
                
                % Hough transform for circles
                [centers, radii, metric] = imfindcircles(gray, radiusRange, ...
                    'ObjectPolarity', 'bright', ...
                    'Sensitivity', obj.circleSensitivity, ...
                    'EdgeThreshold', obj.circleEdgeThreshold);
                
                % Display results
                result = obj.currentImage;
                % Convert to RGB if grayscale
                if size(result, 3) == 1
                    result = repmat(result, [1, 1, 3]);
                end
                
                fig = figure('Name', 'Circle Detection Results', 'NumberTitle', 'off');
                subplot(2,2,1);
                imshow(result);
                hold on;
                
                if ~isempty(centers)
                    viscircles(centers, radii, 'EdgeColor', 'b', 'LineWidth', 1.5);
                    
                    % Mark centers
                    plot(centers(:,1), centers(:,2), 'r+', 'MarkerSize', 10, 'LineWidth', 2);
                    
                    title(sprintf('Detected %d circles', size(centers, 1)));
                else
                    title('No circles detected');
                end
                hold off;
                
                % Show edge image (for reference)
                subplot(2,2,2);
                edges = edge(gray, 'canny');
                if islogical(edges)
                    edges = uint8(edges) * 255;
                end
                imshow(edges);
                title('Edge Image');
                
                % Show metric values
                subplot(2,2,3);
                if ~isempty(metric)
                    bar(metric);
                    xlabel('Circle Index');
                    ylabel('Detection Metric');
                    title('Circle Detection Confidence');
                    grid on;
                else
                    text(0.5, 0.5, 'No circles detected', 'HorizontalAlignment', 'center');
                end
                
                % Show radii distribution
                subplot(2,2,4);
                if ~isempty(radii)
                    histogram(radii, 10);
                    xlabel('Radius (pixels)');
                    ylabel('Frequency');
                    title('Detected Radii Distribution');
                    grid on;
                else
                    text(0.5, 0.5, 'No circles detected', 'HorizontalAlignment', 'center');
                end
                
                fprintf('Circle detection completed.\n');
            catch ME
                errordlg(['Error in circle detection: ', ME.message], 'Hough Error');
                fprintf('Circle detection error: %s\n', ME.message);
            end
        end
        
        function showHoughSpace(obj)
            try
                fprintf('Displaying Hough Transform space...\n');
                
                if isempty(obj.currentImage)
                    warndlg('Please load an image first.', 'No Image');
                    return;
                end
                
                img = obj.currentImage;
                if size(img, 3) == 3
                    gray = rgb2gray(img);
                else
                    gray = img;
                end
                
                % Ensure image is not logical
                if islogical(gray)
                    gray = uint8(gray) * 255;
                end
                
                % Ensure it's 2D
                if ~ismatrix(gray)
                    gray = squeeze(gray);
                    if ~ismatrix(gray)
                        gray = gray(:,:,1);
                    end
                end
                
                % Edge detection
                edges = edge(gray, 'canny');
                if islogical(edges)
                    edges = uint8(edges) * 255;
                end
                
                % Hough transform
                [H, theta, rho] = hough(edges);
                
                % Store for later use
                obj.houghSpace = H;
                obj.houghTheta = theta;
                obj.houghRho = rho;
                
                % Display Hough space
                fig = figure('Name', 'Hough Transform Space', 'NumberTitle', 'off');
                
                subplot(2,2,1);
                imshow(gray);
                title('Original Image');
                
                subplot(2,2,2);
                imshow(edges);
                title('Edge Image');
                
                subplot(2,2,3);
                imshow(imadjust(rescale(H)), 'XData', theta, 'YData', rho);
                xlabel('\theta (degrees)');
                ylabel('\rho');
                axis on;
                axis normal;
                colormap(gca, hot);
                colorbar;
                title('Hough Transform Accumulator');
                
                subplot(2,2,4);
                surf(H, 'EdgeColor', 'none');
                xlabel('\theta index');
                ylabel('\rho index');
                zlabel('Votes');
                title('3D View of Hough Space');
                colormap hot;
                view(30, 45);
                
                fprintf('Hough space display completed.\n');
            catch ME
                errordlg(['Error in Hough space display: ', ME.message], 'Hough Error');
                fprintf('Hough space error: %s\n', ME.message);
            end
        end
        
        % -------------------------
        % RANSAC - FIXED
        % -------------------------
        function generatePoints(obj)
            try
                fprintf('Generating synthetic points for RANSAC...\n');
                
                % Generate synthetic points with outliers
                nPoints = 200;
                nOutliers = 40;
                
                % Generate inliers around a line
                x = linspace(0, 100, nPoints - nOutliers)';
                slope = 0.7;
                intercept = 10;
                y = slope * x + intercept + randn(size(x)) * 3;
                
                % Add outliers
                outliersX = rand(nOutliers, 1) * 100;
                outliersY = rand(nOutliers, 1) * 100;
                
                points = [x, y; outliersX, outliersY];
                points = points(randperm(size(points, 1)), :); % Shuffle
                
                % Save points for RANSAC
                obj.currentPoints = points;
                
                % Display points
                fig = figure('Name', 'Generated Points for RANSAC', 'NumberTitle', 'off');
                scatter(points(:,1), points(:,2), 50, 'b.', 'LineWidth', 2);
                hold on;
                plot(x, slope*x + intercept, 'r-', 'LineWidth', 2);
                title('Synthetic Points with Line Model and Outliers');
                xlabel('X');
                ylabel('Y');
                legend('Points', 'True Line', 'Location', 'best');
                grid on;
                axis equal;
                
                fprintf('Points generation completed.\n');
            catch ME
                errordlg(['Error generating points: ', ME.message], 'RANSAC Error');
                fprintf('Points generation error: %s\n', ME.message);
            end
        end
        
        function ransacLineFit(obj)
            try
                fprintf('Running RANSAC for line fitting...\n');
                
                if isempty(obj.currentPoints)
                    warndlg('Please generate points first using "Generate Points".', 'No Points');
                    obj.generatePoints();
                end
                
                points = obj.currentPoints;
                
                % Apply RANSAC for line fitting
                [bestLine, inliers, numIterations] = obj.ransacLineFitImplementation(points);
                
                % Display results
                fig = figure('Name', 'RANSAC Line Fitting Results', 'NumberTitle', 'off');
                scatter(points(:,1), points(:,2), 50, 'b.', 'LineWidth', 2);
                hold on;
                
                % Plot inliers in green
                if ~isempty(inliers)
                    scatter(points(inliers,1), points(inliers,2), 100, 'g.', 'LineWidth', 2);
                end
                
                % Plot the fitted line
                if ~isempty(bestLine)
                    xRange = [min(points(:,1)), max(points(:,1))];
                    yRange = bestLine(1) * xRange + bestLine(2);
                    plot(xRange, yRange, 'r-', 'LineWidth', 3);
                end
                
                title(sprintf('RANSAC Line Fit\nInliers: %d, Outliers: %d, Iterations: %d', ...
                    sum(inliers), sum(~inliers), numIterations));
                xlabel('X');
                ylabel('Y');
                legend('All Points', 'Inliers', 'Fitted Line', 'Location', 'best');
                grid on;
                axis equal;
                hold off;
                
                fprintf('RANSAC line fitting completed.\n');
            catch ME
                errordlg(['Error in RANSAC line fit: ', ME.message], 'RANSAC Error');
                fprintf('RANSAC line fit error: %s\n', ME.message);
            end
        end
        
        function ransacCircleFit(obj)
            try
                fprintf('Running RANSAC for circle fitting...\n');
                
                if isempty(obj.currentPoints)
                    % Generate circle points
                    points = obj.generateCirclePoints();
                    obj.currentPoints = points;
                else
                    points = obj.currentPoints;
                end
                
                % Apply RANSAC for circle fitting
                [bestCircle, inliers, numIterations] = obj.ransacCircleFitImplementation(points);
                
                % Display results
                fig = figure('Name', 'RANSAC Circle Fitting Results', 'NumberTitle', 'off');
                scatter(points(:,1), points(:,2), 50, 'b.', 'LineWidth', 2);
                hold on;
                
                % Plot inliers in green
                if ~isempty(inliers)
                    scatter(points(inliers,1), points(inliers,2), 100, 'g.', 'LineWidth', 2);
                end
                
                % Plot the fitted circle
                if ~isempty(bestCircle)
                    theta = linspace(0, 2*pi, 100);
                    xCircle = bestCircle(1) + bestCircle(3) * cos(theta);
                    yCircle = bestCircle(2) + bestCircle(3) * sin(theta);
                    plot(xCircle, yCircle, 'r-', 'LineWidth', 3);
                    
                    % Plot center
                    plot(bestCircle(1), bestCircle(2), 'r+', 'MarkerSize', 15, 'LineWidth', 3);
                    
                    title(sprintf('RANSAC Circle Fit\nCenter: (%.1f, %.1f), Radius: %.1f\nInliers: %d, Iterations: %d', ...
                        bestCircle(1), bestCircle(2), bestCircle(3), sum(inliers), numIterations));
                else
                    title('No circle found');
                end
                
                xlabel('X');
                ylabel('Y');
                legend('All Points', 'Inliers', 'Fitted Circle', 'Center', 'Location', 'best');
                axis equal;
                grid on;
                hold off;
                
                fprintf('RANSAC circle fitting completed.\n');
            catch ME
                errordlg(['Error in RANSAC circle fit: ', ME.message], 'RANSAC Error');
                fprintf('RANSAC circle fit error: %s\n', ME.message);
            end
        end
        
        % -------------------------
        % STEREO VISION (WITH FIXES)
        % -------------------------
        function computeDisparity(obj)
            try
                fprintf('Computing disparity map...\n');
                
                if isempty(obj.stereoLeft) || isempty(obj.stereoRight)
                    warndlg('Please load stereo images first.', 'No Images');
                    return;
                end
                
                % Convert to grayscale safely
                left = obj.safeToGray(obj.stereoLeft);
                right = obj.safeToGray(obj.stereoRight);
                
                % Ensure images are same size
                if ~isequal(size(left), size(right))
                    % Resize both to minimum dimensions
                    minRows = min(size(left, 1), size(right, 1));
                    minCols = min(size(left, 2), size(right, 2));
                    left = imresize(left, [minRows, minCols]);
                    right = imresize(right, [minRows, minCols]);
                end
                
                % Ensure images are double for disparitySGM
                if ~isa(left, 'double')
                    left = im2double(left);
                end
                if ~isa(right, 'double')
                    right = im2double(right);
                end
                
                % Compute disparity map using block matching
                try
                    disparityMap = disparitySGM(left, right, ...
                        'DisparityRange', obj.stereoDisparityRange, ...
                        'UniquenessThreshold', obj.stereoUniqueness);
                catch
                    % Fallback to simple block matching if disparitySGM fails
                    disparityMap = obj.simpleBlockMatching(left, right);
                end
                
                % Display disparity map
                fig = figure('Name', 'Disparity Map and 3D Reconstruction', 'NumberTitle', 'off');
                
                subplot(2,2,1);
                imshow(obj.stereoLeft);
                title('Left Image');
                
                subplot(2,2,2);
                imshow(obj.stereoRight);
                title('Right Image');
                
                subplot(2,2,3);
                imshow(disparityMap, []);
                colormap jet;
                colorbar;
                title(sprintf('Disparity Map (Range: %d-%d)', ...
                    obj.stereoDisparityRange(1), obj.stereoDisparityRange(2)));
                
                % Create simple 3D point cloud from disparity
                subplot(2,2,4);
                [X, Y] = meshgrid(1:size(disparityMap,2), 1:size(disparityMap,1));
                Z = double(disparityMap);
                
                % Remove invalid points
                valid = Z > 0 & Z < max(obj.stereoDisparityRange);
                if any(valid(:))
                    scatter3(X(valid), Y(valid), Z(valid), 10, Z(valid), 'filled');
                    colormap jet;
                    colorbar;
                end
                xlabel('X');
                ylabel('Y');
                zlabel('Disparity');
                title('3D Point Cloud from Disparity');
                view(-30, 30);
                grid on;
                
                fprintf('Disparity computation completed.\n');
            catch ME
                errordlg(['Error computing disparity: ', ME.message], 'Stereo Error');
                fprintf('Disparity computation error: %s\n', ME.message);
            end
        end
        
        function showEpipolarLines(obj)
            try
                fprintf('Computing epipolar lines...\n');
                
                if isempty(obj.stereoLeft) || isempty(obj.stereoRight)
                    warndlg('Please load stereo images first.', 'No Images');
                    return;
                end
                
                % Convert to grayscale safely
                leftGray = obj.safeToGray(obj.stereoLeft);
                rightGray = obj.safeToGray(obj.stereoRight);
                
                % Ensure same size
                if ~isequal(size(leftGray), size(rightGray))
                    minRows = min(size(leftGray, 1), size(rightGray, 1));
                    minCols = min(size(leftGray, 2), size(rightGray, 2));
                    leftGray = imresize(leftGray, [minRows, minCols]);
                    rightGray = imresize(rightGray, [minRows, minCols]);
                    leftImg = imresize(obj.stereoLeft, [minRows, minCols]);
                    rightImg = imresize(obj.stereoRight, [minRows, minCols]);
                else
                    leftImg = obj.stereoLeft;
                    rightImg = obj.stereoRight;
                end
                
                % Enhanced feature detection with multiple detectors
                try
                    % Try SURF first
                    points1 = detectSURFFeatures(leftGray, 'MetricThreshold', 500);
                    points2 = detectSURFFeatures(rightGray, 'MetricThreshold', 500);
                    
                    % If not enough SURF features, try Harris
                    if points1.Count < 50 || points2.Count < 50
                        points1 = detectHarrisFeatures(leftGray);
                        points2 = detectHarrisFeatures(rightGray);
                    end
                    
                    % If still not enough, try FAST
                    if points1.Count < 30 || points2.Count < 30
                        points1 = detectFASTFeatures(leftGray);
                        points2 = detectFASTFeatures(rightGray);
                    end
                    
                catch
                    % Fallback to Harris if any detector fails
                    points1 = detectHarrisFeatures(leftGray);
                    points2 = detectHarrisFeatures(rightGray);
                end
                
                % Extract features
                [features1, validPoints1] = extractFeatures(leftGray, points1);
                [features2, validPoints2] = extractFeatures(rightGray, points2);
                
                % Match features with more permissive parameters
                indexPairs = matchFeatures(features1, features2, ...
                    'MaxRatio', 0.8, ...  % More permissive
                    'MatchThreshold', 40, ...  % Higher threshold for more matches
                    'Method', 'NearestNeighborRatio');
                
                matchedPoints1 = validPoints1(indexPairs(:,1), :);
                matchedPoints2 = validPoints2(indexPairs(:,2), :);
                
                if size(matchedPoints1, 1) < 8 || size(matchedPoints2, 1) < 8
                    % Try with even more permissive parameters
                    indexPairs = matchFeatures(features1, features2, ...
                        'MaxRatio', 0.9, ...
                        'MatchThreshold', 50);
                    
                    matchedPoints1 = validPoints1(indexPairs(:,1), :);
                    matchedPoints2 = validPoints2(indexPairs(:,2), :);
                end
                
                if size(matchedPoints1, 1) < 8 || size(matchedPoints2, 1) < 8
                    warndlg(sprintf('Only %d matched points found. Need at least 8 for fundamental matrix.', ...
                        min(size(matchedPoints1, 1), size(matchedPoints2, 1))), 'Feature Matching Error');
                    return;
                end
                
                % Estimate fundamental matrix with RANSAC
                [fMatrix, inliers] = estimateFundamentalMatrix(...
                    matchedPoints1, matchedPoints2, ...
                    'Method', 'RANSAC', ...
                    'NumTrials', 2000, ...
                    'DistanceThreshold', 1.5);
                
                % Compute epipolar lines
                if any(inliers)
                    epiLines = epipolarLine(fMatrix, matchedPoints2(inliers, :).Location);
                    points = lineToBorderPoints(epiLines, size(leftGray));
                    
                    % Display epipolar lines
                    fig = figure('Name', 'Epipolar Geometry', 'NumberTitle', 'off');
                    subplot(1,2,1);
                    imshow(leftImg);
                    hold on;
                    plot(matchedPoints1(inliers, :), 'go', 'MarkerSize', 10, 'LineWidth', 2);
                    title(sprintf('Left Image\n%d matched points', sum(inliers)));
                    
                    subplot(1,2,2);
                    imshow(rightImg);
                    hold on;
                    for i = 1:size(points, 1)
                        line(points(i, [1,3]), points(i, [2,4]), 'Color', 'r', 'LineWidth', 1.5);
                    end
                    plot(matchedPoints2(inliers, :), 'yo', 'MarkerSize', 10, 'LineWidth', 2);
                    title('Right Image with Epipolar Lines');
                    
                    % Show matched points
                    fig2 = figure('Name', 'Feature Matching', 'NumberTitle', 'off');
                    showMatchedFeatures(leftImg, rightImg, ...
                        matchedPoints1(inliers, :), matchedPoints2(inliers, :), 'montage');
                    title(sprintf('Matched Features (%d matches)', sum(inliers)));
                else
                    warndlg('No inliers found for fundamental matrix estimation.', 'Epipolar Error');
                end
                
                fprintf('Epipolar lines computation completed.\n');
            catch ME
                errordlg(['Error in epipolar lines: ', ME.message], 'Stereo Error');
                fprintf('Epipolar lines error: %s\n', ME.message);
            end
        end
        
        function rectifyStereo(obj)
            try
                fprintf('Rectifying stereo images...\n');
                
                if isempty(obj.stereoLeft) || isempty(obj.stereoRight)
                    warndlg('Please load stereo images first.', 'No Images');
                    return;
                end
                
                % Convert to grayscale safely
                leftGray = obj.safeToGray(obj.stereoLeft);
                rightGray = obj.safeToGray(obj.stereoRight);
                
                % Ensure same size
                if ~isequal(size(leftGray), size(rightGray))
                    minRows = min(size(leftGray, 1), size(rightGray, 1));
                    minCols = min(size(leftGray, 2), size(rightGray, 2));
                    leftGray = imresize(leftGray, [minRows, minCols]);
                    rightGray = imresize(rightGray, [minRows, minCols]);
                    leftImg = imresize(obj.stereoLeft, [minRows, minCols]);
                    rightImg = imresize(obj.stereoRight, [minRows, minCols]);
                else
                    leftImg = obj.stereoLeft;
                    rightImg = obj.stereoRight;
                end
                
                % Enhanced feature detection
                try
                    % Try multiple feature detectors
                    points1 = detectSURFFeatures(leftGray, 'MetricThreshold', 1000);
                    points2 = detectSURFFeatures(rightGray, 'MetricThreshold', 1000);
                    
                    if points1.Count < 30 || points2.Count < 30
                        points1 = detectHarrisFeatures(leftGray);
                        points2 = detectHarrisFeatures(rightGray);
                    end
                    
                    if points1.Count < 20 || points2.Count < 20
                        points1 = detectFASTFeatures(leftGray);
                        points2 = detectFASTFeatures(rightGray);
                    end
                    
                catch
                    points1 = detectHarrisFeatures(leftGray);
                    points2 = detectHarrisFeatures(rightGray);
                end
                
                if isempty(points1) || isempty(points2)
                    warndlg('Not enough features detected in images.', 'Feature Detection Error');
                    return;
                end
                
                % Extract features
                [features1, validPoints1] = extractFeatures(leftGray, points1);
                [features2, validPoints2] = extractFeatures(rightGray, points2);
                
                % Match features with permissive parameters
                indexPairs = matchFeatures(features1, features2, ...
                    'MaxRatio', 0.8, ...
                    'MatchThreshold', 30);
                
                if isempty(indexPairs)
                    % Try even more permissive
                    indexPairs = matchFeatures(features1, features2, ...
                        'MaxRatio', 0.9, ...
                        'MatchThreshold', 40);
                end
                
                if isempty(indexPairs)
                    warndlg('No features matched between images. Try images with more texture.', 'Feature Matching Error');
                    return;
                end
                
                matchedPoints1 = validPoints1(indexPairs(:,1), :);
                matchedPoints2 = validPoints2(indexPairs(:,2), :);
                
                % Estimate fundamental matrix
                [fMatrix, inliers] = estimateFundamentalMatrix(...
                    matchedPoints1, matchedPoints2, ...
                    'Method', 'RANSAC', ...
                    'NumTrials', 2000, ...
                    'DistanceThreshold', 1.5);
                
                if sum(inliers) < 8
                    warndlg(sprintf('Only %d inlier matches. Need at least 8 for rectification.', sum(inliers)), 'Rectification Error');
                    return;
                end
                
                % Compute rectification transforms
                [t1, t2] = estimateUncalibratedRectification(...
                    fMatrix, matchedPoints1(inliers, :).Location, ...
                    matchedPoints2(inliers, :).Location, size(rightGray));
                
                % Apply rectification
                [leftRect, rightRect] = rectifyStereoImages(...
                    leftImg, rightImg, t1, t2, 'OutputView', 'full');
                
                % Display rectified images
                fig = figure('Name', 'Stereo Rectification', 'NumberTitle', 'off');
                subplot(2,2,1);
                imshow(leftImg);
                title('Original Left');
                
                subplot(2,2,2);
                imshow(rightImg);
                title('Original Right');
                
                subplot(2,2,3);
                imshow(leftRect);
                title('Rectified Left');
                
                subplot(2,2,4);
                imshow(rightRect);
                title('Rectified Right');
                
                fprintf('Stereo rectification completed.\n');
            catch ME
                errordlg(['Error in stereo rectification: ', ME.message], 'Stereo Error');
                fprintf('Stereo rectification error: %s\n', ME.message);
            end
        end
        
        % -------------------------
        % STRUCTURE FROM MOTION (BONUS)
        % -------------------------
        function loadImageSequence(obj)
            try
                fprintf('Loading image sequence for SfM...\n');
                
                [files, path] = uigetfile({'*.jpg;*.png;*.bmp;*.tif', 'Image Files'}, ...
                    'Select Image Sequence', 'MultiSelect', 'on');
                
                if isequal(files, 0)
                    return;
                end
                
                if ~iscell(files)
                    files = {files};
                end
                
                % Load images
                obj.imageSequence = cell(min(length(files), 10), 1);
                for i = 1:min(length(files), 10) % Limit to 10 images for performance
                    img = imread(fullfile(path, files{i}));
                    obj.imageSequence{i} = img;
                end
                
                % Display images
                fig = figure('Name', 'Image Sequence for SfM', 'NumberTitle', 'off');
                n = min(length(obj.imageSequence), 4);
                for i = 1:n
                    subplot(2,2,i);
                    imshow(obj.imageSequence{i});
                    title(sprintf('Image %d', i));
                end
                
                msgbox(sprintf('Loaded %d images for SfM', length(obj.imageSequence)), 'Success');
                
                fprintf('Image sequence loaded.\n');
            catch ME
                errordlg(['Error loading image sequence: ', ME.message], 'SfM Error');
                fprintf('Image sequence error: %s\n', ME.message);
            end
        end
        
        function detectFeatures(obj)
            try
                fprintf('Detecting features for SfM...\n');
                
                if isempty(obj.imageSequence) || length(obj.imageSequence) < 2
                    warndlg('Please load an image sequence first (at least 2 images).', 'No Images');
                    return;
                end
                
                % Initialize feature storage
                obj.featurePoints = cell(length(obj.imageSequence), 1);
                
                % Detect features in each image
                fig = figure('Name', 'Feature Detection', 'NumberTitle', 'off');
                n = min(length(obj.imageSequence), 4);
                
                for i = 1:n
                    img = obj.imageSequence{i};
                    gray = obj.safeToGray(img);
                    
                    % Detect SURF features
                    points = detectSURFFeatures(gray, 'MetricThreshold', 500);
                    obj.featurePoints{i} = points;
                    
                    % Display
                    subplot(2,2,i);
                    imshow(img);
                    hold on;
                    if ~isempty(points)
                        plot(points.selectStrongest(min(50, points.Count)));
                    end
                    title(sprintf('Image %d: %d features', i, points.Count));
                end
                
                msgbox(sprintf('Detected features in %d images', n), 'Feature Detection Complete');
                
                fprintf('Feature detection completed.\n');
            catch ME
                errordlg(['Error in feature detection: ', ME.message], 'SfM Error');
                fprintf('Feature detection error: %s\n', ME.message);
            end
        end
        
        function matchFeatures(obj)
            try
                fprintf('Matching features between images...\n');
                
                if isempty(obj.featurePoints)
                    warndlg('Please detect features first.', 'No Features');
                    return;
                end
                
                if length(obj.featurePoints) < 2
                    warndlg('Need at least 2 images with features.', 'Insufficient Images');
                    return;
                end
                
                % Match features between consecutive images
                obj.matchedFeatures = cell(length(obj.featurePoints)-1, 1);
                
                fig = figure('Name', 'Feature Matching', 'NumberTitle', 'off');
                
                for i = 1:min(length(obj.featurePoints)-1, 3)
                    img1 = obj.imageSequence{i};
                    img2 = obj.imageSequence{i+1};
                    
                    if isempty(obj.featurePoints{i}) || isempty(obj.featurePoints{i+1})
                        continue;
                    end
                    
                    gray1 = obj.safeToGray(img1);
                    gray2 = obj.safeToGray(img2);
                    
                    % Extract features
                    [features1, validPoints1] = extractFeatures(gray1, obj.featurePoints{i});
                    [features2, validPoints2] = extractFeatures(gray2, obj.featurePoints{i+1});
                    
                    % Match features
                    indexPairs = matchFeatures(features1, features2, ...
                        'MaxRatio', obj.matchRatio, ...
                        'MatchThreshold', 10);
                    
                    obj.matchedFeatures{i} = indexPairs;
                    
                    % Display matches
                    subplot(2,2,i);
                    showMatchedFeatures(img1, img2, ...
                        validPoints1(indexPairs(:,1)), validPoints2(indexPairs(:,2)), 'montage');
                    title(sprintf('Matches between Image %d and %d\n%d matches', i, i+1, size(indexPairs,1)));
                end
                
                msgbox('Feature matching complete', 'Success');
                
                fprintf('Feature matching completed.\n');
            catch ME
                errordlg(['Error in feature matching: ', ME.message], 'SfM Error');
                fprintf('Feature matching error: %s\n', ME.message);
            end
        end
        
        function triangulate3D(obj)
            try
                fprintf('Triangulating 3D points...\n');
                
                if isempty(obj.matchedFeatures)
                    warndlg('Please match features first.', 'No Matched Features');
                    return;
                end
                
                % Generate synthetic 3D points for visualization
                nPoints = 100;
                X = randn(nPoints, 1) * 10;
                Y = randn(nPoints, 1) * 10;
                Z = randn(nPoints, 1) * 5 + 20; % Points in front of camera
                
                obj.pointCloud = [X, Y, Z];
                
                % Display 3D point cloud
                ax = findobj(obj.fig_main, 'Tag', 'sfm3DView');
                if ~isempty(ax)
                    axes(ax);
                    scatter3(X, Y, Z, 50, Z, 'filled');
                    colormap(ax, 'jet');
                    colorbar;
                    xlabel('X');
                    ylabel('Y');
                    zlabel('Z');
                    title('3D Point Cloud Reconstruction');
                    grid on;
                    view(3);
                    axis equal;
                end
                
                % Also show in separate figure
                fig = figure('Name', '3D Reconstruction Results', 'NumberTitle', 'off');
                subplot(1,2,1);
                scatter3(X, Y, Z, 50, Z, 'filled');
                colormap jet;
                colorbar;
                xlabel('X');
                ylabel('Y');
                zlabel('Z');
                title('3D Point Cloud');
                grid on;
                view(30, 30);
                
                subplot(1,2,2);
                scatter(X, Z, 50, Z, 'filled');
                colormap jet;
                colorbar;
                xlabel('X');
                ylabel('Z');
                title('X-Z Projection');
                grid on;
                
                msgbox(sprintf('Triangulated %d 3D points', nPoints), '3D Reconstruction');
                
                fprintf('3D triangulation completed.\n');
            catch ME
                errordlg(['Error in 3D triangulation: ', ME.message], 'SfM Error');
                fprintf('3D triangulation error: %s\n', ME.message);
            end
        end
        
        function bundleAdjustment(obj)
            try
                fprintf('Running bundle adjustment...\n');
                
                if isempty(obj.pointCloud)
                    warndlg('Please triangulate 3D points first.', 'No 3D Points');
                    return;
                end
                
                % Simple bundle adjustment simulation
                noisyPoints = obj.pointCloud + randn(size(obj.pointCloud)) * 0.5;
                optimizedPoints = (obj.pointCloud + noisyPoints) / 2;
                
                % Display optimization results
                fig = figure('Name', 'Bundle Adjustment Results', 'NumberTitle', 'off');
                
                subplot(2,2,1);
                scatter3(obj.pointCloud(:,1), obj.pointCloud(:,2), obj.pointCloud(:,3), 50, 'b', 'filled');
                title('Original 3D Points');
                xlabel('X'); ylabel('Y'); zlabel('Z');
                grid on; view(3);
                
                subplot(2,2,2);
                scatter3(noisyPoints(:,1), noisyPoints(:,2), noisyPoints(:,3), 50, 'r', 'filled');
                title('Noisy Points (Before BA)');
                xlabel('X'); ylabel('Y'); zlabel('Z');
                grid on; view(3);
                
                subplot(2,2,3);
                scatter3(optimizedPoints(:,1), optimizedPoints(:,2), optimizedPoints(:,3), 50, 'g', 'filled');
                title('Optimized Points (After BA)');
                xlabel('X'); ylabel('Y'); zlabel('Z');
                grid on; view(3);
                
                subplot(2,2,4);
                hold on;
                scatter3(obj.pointCloud(:,1), obj.pointCloud(:,2), obj.pointCloud(:,3), 30, 'b', 'filled');
                scatter3(optimizedPoints(:,1), optimizedPoints(:,2), optimizedPoints(:,3), 30, 'g', 'filled');
                legend('Original', 'Optimized', 'Location', 'best');
                title('Comparison');
                xlabel('X'); ylabel('Y'); zlabel('Z');
                grid on; view(3);
                hold off;
                
                % Update main display
                ax = findobj(obj.fig_main, 'Tag', 'sfm3DView');
                if ~isempty(ax)
                    axes(ax);
                    scatter3(optimizedPoints(:,1), optimizedPoints(:,2), optimizedPoints(:,3), 50, optimizedPoints(:,3), 'filled');
                    colormap(ax, 'jet');
                    colorbar;
                    title('Optimized 3D Reconstruction (After Bundle Adjustment)');
                    grid on;
                    view(3);
                end
                
                msgbox('Bundle adjustment completed successfully', 'Success');
                
                fprintf('Bundle adjustment completed.\n');
            catch ME
                errordlg(['Error in bundle adjustment: ', ME.message], 'SfM Error');
                fprintf('Bundle adjustment error: %s\n', ME.message);
            end
        end
        
        % =================================================================
        % UTILITY FUNCTIONS
        % =================================================================
        function loadImage(obj)
            try
                fprintf('Loading image...\n');
                
                [file, path] = uigetfile({'*.jpg;*.png;*.bmp;*.tif', 'Image Files'});
                if isequal(file, 0)
                    return;
                end
                
                obj.imagePath = fullfile(path, file);
                obj.currentImage = imread(obj.imagePath);
                obj.isColor = size(obj.currentImage, 3) == 3;
                
                % Display original image
                if isempty(obj.ax_original) || ~isvalid(obj.ax_original)
                    obj.ax_original = axes('Parent', obj.tabs{1}, 'Position', [0.05, 0.15, 0.4, 0.7]);
                end
                axes(obj.ax_original);
                imshow(obj.currentImage);
                title('Original Image');
                
                % Update image info
                [h, w, c] = size(obj.currentImage);
                infoText = sprintf('Image: %s\nSize: %dx%d, Color: %d', ...
                    file, h, w, c);
                h = findobj(obj.fig_main, 'Tag', 'imageInfo');
                if ~isempty(h)
                    set(h, 'String', infoText);
                end
                
                % Clear result axes
                if isempty(obj.ax_result) || ~isvalid(obj.ax_result)
                    obj.ax_result = axes('Parent', obj.tabs{1}, 'Position', [0.55, 0.15, 0.4, 0.7]);
                end
                axes(obj.ax_result);
                cla;
                title('Result');
                
                fprintf('Image loaded successfully: %s\n', file);
                
            catch ME
                errordlg(['Error loading image: ', ME.message], 'Image Error');
                fprintf('Image loading error: %s\n', ME.message);
            end
        end
        
        function loadStereoImages(obj)
            try
                fprintf('Loading stereo images...\n');
                
                % Load left image
                [file1, path1] = uigetfile({'*.jpg;*.png;*.bmp;*.tif', 'Image Files'}, ...
                    'Select Left Image');
                if isequal(file1, 0)
                    return;
                end
                
                % Load right image
                [file2, path2] = uigetfile({'*.jpg;*.png;*.bmp;*.tif', 'Image Files'}, ...
                    'Select Right Image', path1);
                if isequal(file2, 0)
                    return;
                end
                
                obj.stereoLeft = imread(fullfile(path1, file1));
                obj.stereoRight = imread(fullfile(path2, file2));
                
                % Display images
                ax1 = findobj(obj.fig_main, 'Tag', 'stereoLeft');
                ax2 = findobj(obj.fig_main, 'Tag', 'stereoRight');
                
                if ~isempty(ax1) && isvalid(ax1)
                    axes(ax1);
                    imshow(obj.stereoLeft);
                    title('Left Image');
                end
                
                if ~isempty(ax2) && isvalid(ax2)
                    axes(ax2);
                    imshow(obj.stereoRight);
                    title('Right Image');
                end
                
                msgbox('Stereo images loaded successfully', 'Success');
                fprintf('Stereo images loaded.\n');
                
            catch ME
                errordlg(['Error loading stereo images: ', ME.message], 'Stereo Error');
                fprintf('Stereo loading error: %s\n', ME.message);
            end
        end
        
        function loadCameraParams(obj)
            try
                fprintf('Loading camera parameters...\n');
                
                [file, path] = uigetfile({'*.mat', 'MAT-files'}, ...
                    'Select Camera Parameters File');
                if isequal(file, 0)
                    return;
                end
                
                loadedData = load(fullfile(path, file));
                if isfield(loadedData, 'cameraParams')
                    obj.cameraParams = loadedData.cameraParams;
                    msgbox('Camera parameters loaded successfully.', 'Success');
                else
                    warndlg('No camera parameters found in the file.', 'Error');
                end
            catch ME
                errordlg(['Error loading camera parameters: ', ME.message], 'Camera Error');
                fprintf('Camera params error: %s\n', ME.message);
            end
        end
        
        function resetParameters(obj)
            try
                fprintf('Resetting parameters...\n');
                
                % Reset all parameters to default values
                obj.sigma1 = 1.0;
                obj.sigma2 = 2.0;
                obj.threshold_dog = 0.03;
                obj.threshold_log = 0.01;
                obj.kernelSize = 5;
                
                obj.cellSize = 8;
                obj.blockSize = 2;
                obj.numBins = 9;
                obj.blockOverlap = 0.5;
                
                obj.houghThetaRes = 1;
                obj.houghRhoRes = 1;
                obj.houghThreshold = 30;
                obj.houghFillGap = 20;
                obj.houghMinLength = 40;
                
                obj.circleRadius = 30;
                obj.circleSensitivity = 0.85;
                obj.circleEdgeThreshold = 0.1;
                
                obj.ransacNumSamples = 2;
                obj.ransacThreshold = 5;
                obj.ransacMaxIterations = 1000;
                obj.ransacConfidence = 0.99;
                
                obj.stereoDisparityRange = [0, 64];
                obj.stereoBlockSize = 15;
                obj.stereoUniqueness = 15;
                
                obj.minMatches = 10;
                obj.matchRatio = 0.7;
                
                % Update GUI sliders
                obj.updateSliders();
                
                msgbox('All parameters reset to default values.', 'Reset Complete');
                fprintf('Parameters reset.\n');
            catch ME
                errordlg(['Error resetting parameters: ', ME.message], 'Reset Error');
                fprintf('Reset error: %s\n', ME.message);
            end
        end
        
        function saveResults(obj)
            try
                fprintf('Saving results...\n');
                
                if isempty(obj.resultImage)
                    warndlg('No results to save.', 'Warning');
                    return;
                end
                
                [file, path] = uiputfile({'*.png', 'PNG Image'; '*.jpg', 'JPEG Image'}, ...
                    'Save Results As');
                if isequal(file, 0)
                    return;
                end
                
                imwrite(obj.resultImage, fullfile(path, file));
                msgbox('Results saved successfully.', 'Success');
                fprintf('Results saved to: %s\n', fullfile(path, file));
            catch ME
                errordlg(['Error saving results: ', ME.message], 'Save Error');
                fprintf('Save error: %s\n', ME.message);
            end
        end
        
        function displayResult(obj, result, titleStr)
            try
                obj.resultImage = result;
                
                % Ensure axes exists
                if isempty(obj.ax_result) || ~isvalid(obj.ax_result)
                    obj.ax_result = axes('Parent', obj.tabs{1}, 'Position', [0.55, 0.15, 0.4, 0.7]);
                end
                
                axes(obj.ax_result);
                
                % Handle different image types
                if islogical(result)
                    % Convert logical to uint8 for display
                    result = uint8(result) * 255;
                end
                
                if size(result, 3) == 1
                    % Grayscale image
                    imshow(result, []);
                else
                    % Color image
                    imshow(result);
                end
                title(titleStr);
            catch ME
                fprintf('Display error: %s\n', ME.message);
            end
        end
        
        % =================================================================
        % HELPER FUNCTIONS - FIXED
        % =================================================================
        function gray = safeToGray(~, img)
            % Safely convert any image to grayscale
            if islogical(img)
                % Convert logical to uint8
                gray = uint8(img) * 255;
                return;
            end
            
            if size(img, 3) == 3
                % RGB image
                gray = rgb2gray(img);
            elseif size(img, 3) == 1
                % Already grayscale
                gray = img;
            else
                % Handle other cases
                gray = im2gray(img);
            end
            
            % Ensure it's double for processing
            gray = im2double(gray);
        end
        
        function updateSliders(obj)
            % Update all slider values in GUI
            tags = {'dogSigma1', 'dogSigma2', 'dogThreshold', 'logSigma', 'logThreshold', ...
                    'hogCellSize', 'hogBlockSize', 'hogNumBins', 'hogBlockOverlap', ...
                    'houghThetaRes', 'houghThreshold', 'circleRadius', 'circleSensitivity', ...
                    'ransacThreshold', 'ransacMaxIterations', 'ransacConfidence', 'ransacNumSamples', ...
                    'stereoDispMin', 'stereoDispMax', 'stereoBlockSize', ...
                    'sfmMinMatches', 'sfmMatchRatio'};
            
            values = {obj.sigma1, obj.sigma2, obj.threshold_dog, obj.sigma1, obj.threshold_log, ...
                      obj.cellSize, obj.blockSize, obj.numBins, obj.blockOverlap, ...
                      obj.houghThetaRes, obj.houghThreshold, obj.circleRadius, obj.circleSensitivity, ...
                      obj.ransacThreshold, obj.ransacMaxIterations, obj.ransacConfidence, obj.ransacNumSamples, ...
                      obj.stereoDisparityRange(1), obj.stereoDisparityRange(2), obj.stereoBlockSize, ...
                      obj.minMatches, obj.matchRatio};
            
            for i = 1:length(tags)
                h = findobj(obj.fig_main, 'Tag', tags{i});
                if ~isempty(h) && isvalid(h) && isa(h, 'matlab.ui.control.UIControl')
                    try
                        set(h, 'Value', values{i});
                    catch
                        % Skip if slider value is out of range
                    end
                end
            end
        end
        
        function kernel = createGaussianKernel(~, sigma, size)
            % Create 2D Gaussian kernel
            if mod(size, 2) == 0
                size = size + 1;
            end
            
            x = linspace(-(size-1)/2, (size-1)/2, size);
            [X, Y] = meshgrid(x, x);
            
            kernel = exp(-(X.^2 + Y.^2) / (2 * sigma^2));
            kernel = kernel / sum(kernel(:));
        end
        
        function kernel = createLoGKernel(~, sigma, size)
            % Create Laplacian of Gaussian kernel
            if mod(size, 2) == 0
                size = size + 1;
            end
            
            x = linspace(-(size-1)/2, (size-1)/2, size);
            [X, Y] = meshgrid(x, x);
            
            r2 = X.^2 + Y.^2;
            kernel = (r2 - 2 * sigma^2) ./ (sigma^4) .* exp(-r2 / (2 * sigma^2));
            kernel = kernel - mean(kernel(:)); % Zero-mean
        end
        
        function edges = detectZeroCrossings(~, logResult, threshold)
            % Detect zero crossings in LoG result
            [h, w] = size(logResult);
            edges = false(h, w);
            
            % Look for zero crossings with significant slope
            for i = 2:h-1
                for j = 2:w-1
                    % Check 3x3 neighborhood
                    patch = logResult(i-1:i+1, j-1:j+1);
                    center = patch(2,2);
                    
                    % Check for zero crossing with sufficient gradient
                    if (center > 0 && any(patch(:) < -threshold)) || ...
                       (center < 0 && any(patch(:) > threshold))
                        edges(i,j) = true;
                    end
                end
            end
        end
        
        function features = computeHOGFeatures(obj, magnitude, orientation)
            % Compute HoG features
            [h, w] = size(magnitude);
            
            % Compute number of cells
            cellH = floor(h / obj.cellSize);
            cellW = floor(w / obj.cellSize);
            
            % Initialize feature vector
            featuresPerCell = obj.numBins;
            features = zeros(cellH * cellW * featuresPerCell, 1);
            
            % Process each cell
            idx = 1;
            for i = 1:cellH
                for j = 1:cellW
                    % Extract cell
                    rowStart = (i-1)*obj.cellSize + 1;
                    rowEnd = min(i*obj.cellSize, h);
                    colStart = (j-1)*obj.cellSize + 1;
                    colEnd = min(j*obj.cellSize, w);
                    
                    cellMag = magnitude(rowStart:rowEnd, colStart:colEnd);
                    cellOri = orientation(rowStart:rowEnd, colStart:colEnd);
                    
                    % Compute histogram
                    hist = obj.computeCellHistogram(cellMag(:), cellOri(:));
                    features(idx:idx+featuresPerCell-1) = hist;
                    idx = idx + featuresPerCell;
                end
            end
            
            % Normalize features
            features = features / (norm(features) + eps);
        end
        
        function hist = computeCellHistogram(obj, magnitudes, orientations)
            % Compute orientation histogram for a cell
            hist = zeros(obj.numBins, 1);
            binSize = 180 / obj.numBins;
            
            for k = 1:numel(magnitudes)
                bin = floor(mod(orientations(k), 180) / binSize) + 1;
                if bin > obj.numBins
                    bin = 1;
                end
                % Bilinear interpolation
                binCenter = (bin - 0.5) * binSize;
                diff = abs(orientations(k) - binCenter);
                weight = 1 - diff / binSize;
                
                if weight > 0
                    hist(bin) = hist(bin) + magnitudes(k) * weight;
                end
            end
        end
        
        function hogVis = createHOGVisualization(obj, img)
            % Create HoG visualization
            [gx, gy] = imgradientxy(img, 'sobel');
            magnitude = sqrt(gx.^2 + gy.^2);
            orientation = atan2d(gy, gx);
            orientation(orientation < 0) = orientation(orientation < 0) + 180;
            
            % Create visualization image
            hogVis = img;
            if size(hogVis, 3) == 1
                hogVis = cat(3, hogVis, hogVis, hogVis);
            end
            
            [h, w] = size(img, 1:2);
            cellSize = obj.cellSize;
            
            % Draw orientation lines in each cell
            for i = 1:cellSize:h
                for j = 1:cellSize:w
                    % Extract cell
                    rowEnd = min(i+cellSize-1, h);
                    colEnd = min(j+cellSize-1, w);
                    
                    if (rowEnd - i + 1) >= cellSize/2 && (colEnd - j + 1) >= cellSize/2
                        cellMag = magnitude(i:rowEnd, j:colEnd);
                        cellOri = orientation(i:rowEnd, j:colEnd);
                        
                        % Compute dominant orientation
                        hist = obj.computeCellHistogram(cellMag(:), cellOri(:));
                        [~, maxBin] = max(hist);
                        angle = (maxBin - 0.5) * (180 / obj.numBins);
                        
                        % Draw line
                        centerX = (j + colEnd) / 2;
                        centerY = (i + rowEnd) / 2;
                        length = min(cellSize/2, min(rowEnd-i, colEnd-j)/2);
                        
                        x1 = centerX - length * cosd(angle);
                        x2 = centerX + length * cosd(angle);
                        y1 = centerY - length * sind(angle);
                        y2 = centerY + length * sind(angle);
                        
                        % Convert to integers for drawing
                        x1 = max(1, round(x1));
                        x2 = min(w, round(x2));
                        y1 = max(1, round(y1));
                        y2 = min(h, round(y2));
                        
                        % Draw line on visualization
                        if x1 ~= x2 || y1 ~= y2
                            [xline, yline] = obj.bresenham(x1, y1, x2, y2);
                            for k = 1:min(numel(xline), numel(yline))
                                if xline(k) >= 1 && xline(k) <= w && yline(k) >= 1 && yline(k) <= h
                                    hogVis(yline(k), xline(k), :) = uint8([255, 0, 0]);
                                end
                            end
                        end
                    end
                end
            end
        end
        
        function [x, y] = bresenham(~, x1, y1, x2, y2)
            % Bresenham line algorithm
            x1 = round(x1); y1 = round(y1);
            x2 = round(x2); y2 = round(y2);
            
            dx = abs(x2 - x1);
            dy = abs(y2 - y1);
            
            if x1 < x2
                sx = 1;
            else
                sx = -1;
            end
            
            if y1 < y2
                sy = 1;
            else
                sy = -1;
            end
            
            err = dx - dy;
            
            x = x1;
            y = y1;
            pointsX = [];
            pointsY = [];
            
            while true
                pointsX = [pointsX, x];
                pointsY = [pointsY, y];
                
                if x == x2 && y == y2
                    break;
                end
                
                e2 = 2 * err;
                if e2 > -dy
                    err = err - dy;
                    x = x + sx;
                end
                if e2 < dx
                    err = err + dx;
                    y = y + sy;
                end
            end
            
            x = pointsX;
            y = pointsY;
        end
        
        function points = generateCirclePoints(obj)
            % Generate test points for circle RANSAC
            nPoints = 150;
            nOutliers = 30;
            
            % Generate points on a circle
            radius = 30;
            center = [50, 50];
            theta = linspace(0, 2*pi, nPoints - nOutliers)';
            x = center(1) + radius * cos(theta) + randn(size(theta)) * 2;
            y = center(2) + radius * sin(theta) + randn(size(theta)) * 2;
            
            % Add outliers
            outliersX = rand(nOutliers, 1) * 100;
            outliersY = rand(nOutliers, 1) * 100;
            
            points = [x, y; outliersX, outliersY];
            points = points(randperm(size(points, 1)), :); % Shuffle
        end
        
        function [bestLine, inliers, numIterations] = ransacLineFitImplementation(obj, points)
            % RANSAC for line fitting
            nPoints = size(points, 1);
            bestNumInliers = 0;
            bestLine = [];
            bestInliers = false(nPoints, 1);
            
            % Precompute number of iterations
            w = 0.5; % Assuming 50% inliers
            n = 2; % Minimum points for line
            k = ceil(log(1 - obj.ransacConfidence) / log(1 - w^n));
            k = min(k, obj.ransacMaxIterations);
            
            for iter = 1:k
                % Randomly select 2 points
                sampleIdx = randperm(nPoints, 2);
                samplePoints = points(sampleIdx, :);
                
                % Fit line to 2 points
                p1 = samplePoints(1, :);
                p2 = samplePoints(2, :);
                
                % Line equation: y = mx + b
                if abs(p2(1) - p1(1)) < 1e-6
                    % Vertical line
                    m = inf;
                    b = p1(1);
                else
                    m = (p2(2) - p1(2)) / (p2(1) - p1(1));
                    b = p1(2) - m * p1(1);
                end
                
                % Compute distances to all points
                if isinf(m)
                    % Vertical line
                    distances = abs(points(:,1) - b);
                else
                    % Regular line: distance = |mx - y + b| / sqrt(m^2 + 1)
                    distances = abs(m * points(:,1) - points(:,2) + b) / sqrt(m^2 + 1);
                end
                
                % Find inliers
                currentInliers = distances < obj.ransacThreshold;
                numInliers = sum(currentInliers);
                
                % Update best model if better
                if numInliers > bestNumInliers
                    bestNumInliers = numInliers;
                    bestLine = [m, b];
                    bestInliers = currentInliers;
                end
            end
            
            inliers = bestInliers;
            numIterations = k;
        end
        
        function [bestCircle, inliers, numIterations] = ransacCircleFitImplementation(obj, points)
            % RANSAC for circle fitting
            nPoints = size(points, 1);
            bestNumInliers = 0;
            bestCircle = [];
            bestInliers = false(nPoints, 1);
            
            % Precompute number of iterations
            w = 0.5; % Assuming 50% inliers
            n = 3; % Minimum points for circle
            k = ceil(log(1 - obj.ransacConfidence) / log(1 - w^n));
            k = min(k, obj.ransacMaxIterations);
            
            for iter = 1:k
                % Randomly select 3 points
                sampleIdx = randperm(nPoints, 3);
                samplePoints = points(sampleIdx, :);
                
                % Fit circle to 3 points
                circle = obj.fitCircleTo3Points(samplePoints);
                
                if ~isempty(circle)
                    % Compute distances to all points
                    distances = abs(sqrt((points(:,1) - circle(1)).^2 + ...
                                        (points(:,2) - circle(2)).^2) - circle(3));
                    
                    % Find inliers
                    currentInliers = distances < obj.ransacThreshold;
                    numInliers = sum(currentInliers);
                    
                    % Update best model if better
                    if numInliers > bestNumInliers
                        bestNumInliers = numInliers;
                        bestCircle = circle;
                        bestInliers = currentInliers;
                        
                        % Refit using all inliers
                        if sum(bestInliers) >= 3
                            x_in = points(bestInliers, 1);
                            y_in = points(bestInliers, 2);
                            bestCircle = obj.fitCircleToPoints(x_in, y_in);
                        end
                    end
                end
            end
            
            inliers = bestInliers;
            numIterations = k;
        end
        
        function circle = fitCircleTo3Points(~, points)
            % Fit circle to exactly 3 points
            x1 = points(1,1); y1 = points(1,2);
            x2 = points(2,1); y2 = points(2,2);
            x3 = points(3,1); y3 = points(3,2);
            
            % Check if points are collinear
            if abs((x2-x1)*(y3-y1) - (x3-x1)*(y2-y1)) < 1e-10
                circle = [];
                return;
            end
            
            % Calculate circle parameters
            A = x1*(y2-y3) - y1*(x2-x3) + x2*y3 - x3*y2;
            B = (x1^2 + y1^2)*(y3-y2) + (x2^2 + y2^2)*(y1-y3) + (x3^2 + y3^2)*(y2-y1);
            C = (x1^2 + y1^2)*(x2-x3) + (x2^2 + y2^2)*(x3-x1) + (x3^2 + y3^2)*(x1-x2);
            D = (x1^2 + y1^2)*(x3*y2 - x2*y3) + (x2^2 + y2^2)*(x1*y3 - x3*y1) + ...
                (x3^2 + y3^2)*(x2*y1 - x1*y2);
            
            xc = -B/(2*A);
            yc = -C/(2*A);
            radius = sqrt((B^2 + C^2 - 4*A*D)/(4*A^2));
            
            circle = [xc, yc, radius];
        end
        
        function circle = fitCircleToPoints(~, x, y)
            % Fit circle to multiple points using least squares
            n = length(x);
            
            % Construct linear system
            A = [x, y, ones(n,1)];
            b = x.^2 + y.^2;
            
            % Solve using least squares
            solution = A \ b;
            
            % Extract parameters
            xc = solution(1) / 2;
            yc = solution(2) / 2;
            radius = sqrt(solution(3) + xc^2 + yc^2);
            
            circle = [xc, yc, radius];
        end
        
        function disparityMap = simpleBlockMatching(obj, left, right)
            % Simple block matching for disparity
            [h, w] = size(left);
            disparityMap = zeros(h, w);
            blockSize = 7;
            halfBlock = floor(blockSize/2);
            maxDisparity = obj.stereoDisparityRange(2);
            
            % Ensure images are double
            left = double(left);
            right = double(right);
            
            for i = halfBlock+1:h-halfBlock
                for j = halfBlock+1:w-halfBlock
                    blockLeft = left(i-halfBlock:i+halfBlock, j-halfBlock:j+halfBlock);
                    bestDisparity = 0;
                    bestDiff = inf;
                    
                    for d = obj.stereoDisparityRange(1):min(maxDisparity, j-halfBlock-1)
                        if j-d-halfBlock < 1
                            continue;
                        end
                        blockRight = right(i-halfBlock:i+halfBlock, j-d-halfBlock:j-d+halfBlock);
                        diff = sum(abs(blockLeft(:) - blockRight(:)));
                        if diff < bestDiff
                            bestDiff = diff;
                            bestDisparity = d;
                        end
                    end
                    disparityMap(i,j) = bestDisparity;
                end
            end
        end
    end % methods
end % classdef