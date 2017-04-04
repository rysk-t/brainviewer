function brainviewer(imgFile)
% brainviewer    A simple brain image viewer
%
% This program eequires SPM (tested with 12).
%

%% File Dialog
if nargin==0
    [fName, fPath] = uigetfile('*.nii');
    imgFile = [fPath filesep fName];
end

%% Filename
[fPath, fName, fExt] = fileparts(imgFile);
vw.filename = fName;
vw.filepath = fPath;

%% Settings
wndSize = [1024, 768];

%% Init data -------------------------------------------------------------------

%% Brains
vols = load_brain(imgFile);

vw.dat(1).img = vols.voxel;
vw.dat(1).size = size(vols.voxel);
vw.dat(1).xyz = vols.xyz;
vw.dat(1).mat = vols.mat;
vw.dat(1).color = vols.color;
vw.dat(1).alpha = vols.alpha;

%% Crosshair
vw.crosshair.pos = floor(size(vw.dat.img) ./ 2);
vw.crosshair.color = 'r';

%% Selected voxels
vw.select = [];


%% Init UI ---------------------------------------------------------------------
screen = get(0);

hf = figure('Position', [1, screen.ScreenSize(4) - wndSize(2), wndSize(1), wndSize(2)], ...
            'Visible', 'off');

% Canvases
canvas(1).ax = axes('Tag', 'cv1', 'OuterPosition', [0, 0.5, 0.5, 0.5], 'Units', 'normalized');
canvas(2).ax = axes('Tag', 'cv2', 'OuterPosition', [0.5, 0.5, 0.5, 0.5], 'Units', 'normalized');
canvas(3).ax = axes('Tag', 'cv3', 'OuterPosition', [0, 0, 0.5, 0.5], 'Units', 'normalized');
vw.canvas = canvas;

% Context menu
cm = uicontextmenu;
uimenu(cm, 'Tag', 'Select', 'Label', 'Select', 'Callback', @cb_contextmenu);
uimenu(cm, 'Tag', 'Save',   'Label', 'Save',   'Callback', @cb_contextmenu);
vw.contextmenu = cm;

% Init view
vw = init_canvas(vw);


%% Display ---------------------------------------------------------------------
vw = draw_brain(vw);
set(hf, 'Visible', 'on');

guidata(hf, vw);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cb_buttondown(h, c)
% Callback function (ButtonDown)
%

vw = guidata(gcf);
mp = get(get(h, 'Parent'), 'CurrentPoint');
selType = get(gcf, 'SelectionType');

if isequal(selType, 'normal')
    switch get(get(h, 'Parent'), 'Tag')
      case 'cv1'
        vw.crosshair.pos = [mp(1, 1, 1), vw.crosshair.pos(2), mp(1, 2, 1)];
      case 'cv2'
        vw.crosshair.pos = [vw.crosshair.pos(1), mp(1, 1, 1), mp(1, 2, 1)];
      case 'cv3'
        vw.crosshair.pos = [mp(1, 1, 1), mp(1, 2, 1), vw.crosshair.pos(3)];
    end

    vw.crosshair.pos = floor(vw.crosshair.pos);

    % Disp info
    vxcoord = vw.dat(1).mat * [vw.crosshair.pos, 1]';
    fprintf('Voxel index:\t(%d, %d, %d)\n', vw.crosshair.pos(1), vw.crosshair.pos(2), vw.crosshair.pos(3));
    fprintf('Voxel coord:\t(%f, %f, %f)\n', vxcoord(1), vxcoord(2), vxcoord(3));
elseif isequal(selType, 'alt')
end

vw = draw_brain(vw);
guidata(gcf, vw);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cb_contextmenu(h, c)

vw = guidata(gcf);

switch get(h, 'Tag')
  case 'Select'
    ind = length(vw.select) + 1;
    vw.select(ind).pos = vw.crosshair.pos;
    vw.select(ind).color = 'cyan';
    disp('Voxel selected');
  case 'Save'
    voxels = [];
    for i = 1:length(vw.select)
        vxcoord = vw.dat(1).mat * [vw.select(i).pos, 1]';
        
        voxels(i).index = vw.select(i).pos;
        voxels(i).coord = [vxcoord(1), vxcoord(2), vxcoord(3)];
    end

    saveFile = sprintf('%s_voxels.mat', vw.filename);
    save(saveFile, 'voxels');
    fprintf('Saved %s\n', saveFile);
end

vw = draw_brain(vw);
guidata(gcf, vw);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function vw = init_canvas(vw)
% Init canvases
%
for i = 1:3
    secPos = vw.crosshair.pos;
    set(gcf, 'CurrentAxes', vw.canvas(i).ax);
    switch i
      case 1
        % X (L/R) * Z (A/P)
        dispImg = nan(vw.dat.size(1), vw.dat.size(3))';
        aspectRatio = [vw.dat.size(3), vw.dat.size(1), 1];
        chPos = [secPos(1), secPos(3)];
        drawLim.x = [1, vw.dat.size(1)];
        drawLim.y = [1, vw.dat.size(3)];
        label.x = ['R <--> L'];
        label.y = ['I <--> S'];
      case 2
        % Y (A/P) * Z (S/I)
        dispImg = nan(vw.dat.size(2), vw.dat.size(3))';
        aspectRatio = [vw.dat.size(3), vw.dat.size(2), 1];
        chPos = [secPos(2), secPos(3)];
        drawLim.x = [1, vw.dat.size(2)];
        drawLim.y = [1, vw.dat.size(3)];
        label.x = ['A <--> P'];
        label.y = ['I <--> S'];
      case 3
        % X (L/R) * Y (A/P)
        dispImg = nan(vw.dat.size(1), vw.dat.size(2))';
        aspectRatio = [vw.dat.size(2), vw.dat.size(1), 1];
        chPos = [secPos(1), secPos(2)];
        drawLim.x = [1, vw.dat.size(1)];
        drawLim.y = [1, vw.dat.size(2)];
        label.x = ['R <--> L'];
        label.y = ['P <--> A'];
    end

    hold on;
    vw.canvas(i).display = imagesc(dispImg, ...
                                   'ButtonDownFcn', @cb_buttondown, ...
                                   'UIContextMenu', vw.contextmenu);
    vw.canvas(i).crosshair.vertical = plot([chPos(1), chPos(1)], [0, max(vw.dat.size)], 'r'); 
    vw.canvas(i).crosshair.horizontal = plot([0, max(vw.dat.size)], [chPos(2), chPos(2)], 'r'); 
    xlim(drawLim.x);
    ylim(drawLim.y);
    xlabel(label.x);
    ylabel(label.y);
    %axis off;
    set(gca, 'DataAspectRatio', aspectRatio, 'YDir', 'reverse');
    colormap(vw.dat.color);

    % TODO: Fix aspect ratio?
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function vw = draw_brain(vw)
% Display brain images
%

for i = 1:3
    secPos = vw.crosshair.pos;

    switch i
      case 1
        disp(secPos(2))
        dispImg = flip(squeeze(vw.dat.img(:, secPos(2), :))', 2);
        chPos = [secPos(1), secPos(3)];
      case 2
        dispImg = squeeze(vw.dat.img(secPos(1), :, :))';
        chPos = [secPos(2), secPos(3)];
      case 3
        dispImg = flip(squeeze(vw.dat.img(:, :, secPos(3)))', 2);
        chPos = [secPos(1), secPos(2)];
    end

    set(vw.canvas(i).display, 'CData', dispImg);
    set(vw.canvas(i).crosshair.vertical, ...
        'XData', [chPos(1), chPos(1)], ...
        'YData', [0, max(vw.dat.size)]);
    set(vw.canvas(i).crosshair.horizontal, ...
        'XData', [0, max(vw.dat.size)], ...
        'YData', [chPos(2), chPos(2)]);

    % Mark selected voxels
    % TBA
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function vols = load_brain(imgFile)
% Load a brain image
%
[fPath, fName, hoge] = fileparts(imgFile);
fprintf('File Name - %s\n', fName);
fprintf('Location  - %s\n', fPath);

vol = spm_vol(imgFile);
[voxel, xyz] = spm_read_vols(vol);

voxel = permute(voxel, [3, 1, 2]); % RAS (?)

vols.voxel = voxel;
vols.xyz = xyz;
vols.color = 'gray';
vols.alpha = 1;
vols.mat = [vol.mat(:, 3), vol.mat(:, 1), vol.mat(:, 2), vol.mat(:, 4)];
