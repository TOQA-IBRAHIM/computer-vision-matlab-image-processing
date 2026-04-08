function UltimateShapeRecognitionApp_Final_v3
% =====================================================
% SHAPE RECOGNITION SYSTEM (INTERACTIVE VERSION)
% =====================================================

%% ===============================
% CREATE GUI
% ===============================
fig = uifigure('Name','Shape Recognition System','Position',[100 100 980 670]);

ax = uiaxes(fig,'Position',[40 120 650 500]);
axis(ax,'image'); axis(ax,'off');

uploadBtn = uibutton(fig,'Text','1. Upload Image',...
    'Position',[740 520 180 45]);

detectBtn = uibutton(fig,'Text','2. Detect Shapes',...
    'Position',[740 465 180 45],...
    'BackgroundColor',[0.2 0.6 1],...
    'FontColor','white','FontWeight','bold',...
    'Enable','off');

statusLabel = uilabel(fig,...
    'Position',[740 425 180 30],...
    'Text','Status: Idle',...
    'HorizontalAlignment','center',...
    'FontWeight','bold');

%% ===============================
% INTERACTIVE CONTROLS
% ===============================
uilabel(fig,'Text','Circularity Min','Position',[720 380 100 22]);
minCircSpinner = uispinner(fig,...
    'Position',[830 380 80 22],...
    'Limits',[0 1],'Value',0.58,'Step',0.01);

uilabel(fig,'Text','Circularity Max','Position',[720 350 100 22]);
maxCircSpinner = uispinner(fig,...
    'Position',[830 350 80 22],...
    'Limits',[0 2],'Value',1.03,'Step',0.01);

uilabel(fig,'Text','Display Shapes','Position',[740 315 120 22],...
    'FontWeight','bold');

cbTriangle  = uicheckbox(fig,'Text','Triangle','Position',[740 290 120 20],'Value',true);
cbSquare    = uicheckbox(fig,'Text','Square','Position',[740 270 120 20],'Value',true);
cbRectangle = uicheckbox(fig,'Text','Rectangle','Position',[740 250 120 20],'Value',true);
cbCircle    = uicheckbox(fig,'Text','Circle','Position',[740 230 120 20],'Value',true);
cbPolygon   = uicheckbox(fig,'Text','Other Polygons','Position',[740 210 140 20],'Value',true);

%% ===============================
% DATA STORAGE
% ===============================
data.img = [];
data.ax = ax;
data.status = statusLabel;

data.minCircSpinner = minCircSpinner;
data.maxCircSpinner = maxCircSpinner;

data.cbTriangle  = cbTriangle;
data.cbSquare    = cbSquare;
data.cbRectangle = cbRectangle;
data.cbCircle    = cbCircle;
data.cbPolygon   = cbPolygon;

guidata(fig,data);

%% ===============================
% CALLBACKS
% ===============================
uploadBtn.ButtonPushedFcn = @(~,~) uploadImage(fig,detectBtn);
detectBtn.ButtonPushedFcn = @(~,~) detectShapes(fig);

end

%% =====================================================
% UPLOAD IMAGE
% =====================================================
function uploadImage(fig,detectBtn)
data = guidata(fig);

[file,path] = uigetfile({'*.jpg;*.png;*.bmp;*.jpeg'},'Select Image');
if isequal(file,0), return; end

data.img = imread(fullfile(path,file));
imshow(data.img,'Parent',data.ax);
title(data.ax,'Image Loaded');

detectBtn.Enable = 'on';
data.status.Text = "Status: Image Ready";

guidata(fig,data);
end

%% =====================================================
% DETECT SHAPES
% =====================================================
function detectShapes(fig)
data = guidata(fig);
if isempty(data.img)
    uialert(fig,'Upload an image first','Error');
    return;
end

minCirc = data.minCircSpinner.Value;
maxCirc = data.maxCircSpinner.Value;

showTriangle  = data.cbTriangle.Value;
showSquare    = data.cbSquare.Value;
showRectangle = data.cbRectangle.Value;
showCircle    = data.cbCircle.Value;
showPolygon   = data.cbPolygon.Value;

img = data.img;
if size(img,3)==3
    gray = rgb2gray(img);
else
    gray = img;
end

%% --- PREPROCESSING ---
bw = imbinarize(imgaussfilt(gray,0.5));
if bw(1,1)==1 && bw(1,end)==1
    bw = ~bw;
end
bw = imfill(bw,'holes');
bw = bwareaopen(bw,500);

[B,L] = bwboundaries(bw,'noholes');
stats = regionprops(L,'Area','Perimeter','Centroid','Extent','Solidity');

imshow(img,'Parent',data.ax); hold(data.ax,'on');
count = 0;

%% --- LOOP ---
for i = 1:length(stats)
    boundary = B{i};
    A = stats(i).Area;
    P = stats(i).Perimeter;
    circ = (4*pi*A)/(P^2);
    ext = stats(i).Extent;
    sol = stats(i).Solidity;

    % Simplify polygon
    tol = 0.03 * P;
    simp = simplePolygon(boundary,tol);
    numV = size(simp,1) - 1;

    % Roughness
    d = diff(simp,1,1);
    simpP = sum(sqrt(sum(d.^2,2)));
    roughness = P / simpP;

    shapeLabel = "Unknown";
    isNonShape = false;

    % Global filters
    if sol < 0.80 || circ < minCirc || circ > maxCirc
        isNonShape = true;
        shapeLabel = "non shape";
    end

    if ~isNonShape
        if numV == 3
            shapeLabel = "Triangle";
        elseif numV == 4
            if roughness > 1.06
                isNonShape = true;
            elseif ext < 0.85
                shapeLabel = "Trapezoid";
            else
                pts = simp(1:4,:);
                r = min(norm(pts(1,:)-pts(2,:)),norm(pts(2,:)-pts(3,:))) / ...
                    max(norm(pts(1,:)-pts(2,:)),norm(pts(2,:)-pts(3,:)));
                if r > 0.85
                    shapeLabel = "Square";
                else
                    shapeLabel = "Rectangle";
                end
            end
        elseif numV == 5
            shapeLabel = "Pentagon";
        elseif numV == 6
            if circ > 0.85
                shapeLabel = "Hexagon";
            else
                shapeLabel = "Semi-Circle";
            end
        elseif numV == 7
            shapeLabel = "Heptagon";

            elseif circ > 0.88 && circ <0.99 && numV > 6
            shapeLabel = "Octagon"; % Specifically catch the Octagon
        else
            if circ > 0.99
                shapeLabel = "Circle";
            else
                shapeLabel = "Polygon";
            end
        end
    end

    % Shape checkbox filter
    switch shapeLabel
        case "Triangle"
            if ~showTriangle, isNonShape = true; end
        case "Square"
            if ~showSquare, isNonShape = true; end
        case "Rectangle"
            if ~showRectangle, isNonShape = true; end
        case "Circle"
            if ~showCircle, isNonShape = true; end
        otherwise
            if ~showPolygon, isNonShape = true; end
    end

    % Display
    if ~isNonShape
        plot(data.ax,boundary(:,2),boundary(:,1),'g','LineWidth',3);
        text(data.ax,stats(i).Centroid(1),stats(i).Centroid(2),shapeLabel,...
            'Color','white','FontWeight','bold','FontSize',12,...
            'BackgroundColor','black','HorizontalAlignment','center');
        count = count + 1;
    else
        
        % Display non-shapes in Red with a "non shape" label
        plot(data.ax, boundary(:,2), boundary(:,1), 'r', 'LineWidth', 2);
        text(data.ax, stats(i).Centroid(1), stats(i).Centroid(2), "non shape",...
            'Color', 'yellow', 'FontWeight', 'bold', 'FontSize', 10,...
            'BackgroundColor', 'red', 'HorizontalAlignment', 'center');
 
    end
end

hold(data.ax,'off');
data.status.Text = sprintf("Status: %d Shapes Detected",count);
end

%% =====================================================
% HELPERS
% =====================================================
function simp = simplePolygon(P,tol)
if size(P,1)<3, simp=P; return; end
dmax=0; idx=0; N=size(P,1);
for i=2:N-1
    d=perpDist(P(i,:),P(1,:),P(N,:));
    if d>dmax, idx=i; dmax=d; end
end
if dmax>tol
    s1=simplePolygon(P(1:idx,:),tol);
    s2=simplePolygon(P(idx:N,:),tol);
    simp=[s1(1:end-1,:);s2];
else
    simp=[P(1,:);P(N,:)];
end
end

function d = perpDist(p,a,b)
num = abs((b(2)-a(2))*p(1)-(b(1)-a(1))*p(2)+b(1)*a(2)-b(2)*a(1));
den = hypot(b(2)-a(2),b(1)-a(1));
if den==0, d=hypot(p(1)-a(1),p(2)-a(2));
else, d=num/den; end
end