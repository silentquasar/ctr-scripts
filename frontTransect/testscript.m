addpath(genpath(fileparts(pwd)))
% cubeDir = 'E:\DAQ-data\';
cubeDir = 'C:\Users\radaruser\Desktop\honegger-temp\tmpData-front\';

files = getFiles(cubeDir);

cubeName = [files(1).folder,files(1).name];

load(cubeName,'Rg','Azi','timex','timeInt','results')
if ~exist('timex','var') || isempty(timex)
    load(cubeName,'data')
    timex = mean(data,3);
end

%% Rectify to x-y
[AZI,RG] = meshgrid(90-Azi-results.heading,Rg);
[xrad,yrad] = pol2cart(AZI*pi/180,RG);
xutm = xrad + results.XOrigin;
yutm = yrad + results.YOrigin;
[lat,lon] = UTMtoll(yutm,xutm,18);

%% Create transect waypoints
clickFig = figure;
    hp = pcolor(lon,lat,timex);
        shading interp
        colormap(hot)
        caxis([0 225])
[lonwp,latwp] = ginput(2);

%% Convert waypoints into transect
[yutmwp,xutmwp] = lltoUTM(latwp,lonwp);
xwp = xutmwp - results.XOrigin;
ywp = yutmwp - results.YOrigin;
s = hypot(diff(xwp),diff(ywp));
stx = 0:10:s;
xtx = interp1([0 s],xwp,stx);
ytx = interp1([0 s],ywp,stx);

txFig = figure;
    hp = pcolor(xrad,yrad,timex);
        shading interp
        colormap(hot)
        caxis([0 225])
    hold on
    plot(xtx,ytx,'.c')

%% Convert transect points to polar
[thtx,rgtx] = cart2pol(xtx,ytx);
azitx = mod(90-thtx*180/pi-results.heading,360);

polfig = figure;
    hp = imagesc(Azi,Rg,timex);
    colormap(hot)
    caxis([0 225])
    hold on
    plot(azitx,rgtx,'.c')
    
%% Create gridded interpolant
minRange = find(diff(Rg),1,'first');
Rg_grid = Rg(minRange:end);


[AZI_grid,RG_grid] = ndgrid(Azi,Rg_grid);
gInt = griddedInterpolant(AZI_grid,RG_grid,single(timex(minRange:end,:)'));

%% Interpolate to transect
Itx = gInt(azitx,rgtx);

txPlot = figure;
    hp = plot(stx,Itx,'-k');
    
%% Loop thru files

Itx = [];%nan(length(files),length(stx));
dn = [];%nan(length(files),1);
for i = 1:length(files)
    fprintf('%d of %d.',i,length(files))
    load([files(i).folder,files(i).name],'timeInt','timex','header')
    if header.rotations > 64
        fprintf('Long run.Rot:')
        % Deal with long run
        load([files(i).folder,files(i).name],'data')
        fdata = movmean(data,32,3);
        for j = 32:64:header.rotations-32
            fprintf('%d.',j)
            thisFrame = fdata(minRange:end,:,j);
            dn = [dn epoch2Matlab(timeInt(1,j))];
            gInt.Values = single(thisFrame');
            Itx = [Itx;gInt(azitx,rgtx)];
        end
    else
        dn = [dn epoch2Matlab(mean(timeInt(:)))];
        
        gInt.Values = single(timex(minRange:end,:)');
        Itx = [Itx;gInt(azitx,rgtx)];
    end
    fprintf('\n')
end
midNum = fix(length(files)/2);
load([files(fix(length(files)/2)).folder,files(fix(length(files)/2)).name])

%% Plot stack

stackFig = figure;
    hp = pcolor(stx,dn,bfWrapper(double(Itx)));
        shading interp
        datetick('y','keeplimits')
    
%% Convert to image

[grd.stx,grd.dn] = ndgrid(stx,dn);
gInt = griddedInterpolant(grd.stx,grd.dn,Itx');
[reg.stx,reg.dn] = meshgrid(stx,dn(1):1/60/24:dn(end));
reg.Itx = gInt(reg.stx,reg.dn);

imFig = figure;
    imagesc(reg.stx(1,:),reg.dn(:,1),reg.Itx)
    axis xy

%% Frangi filter

im = uint8(flipud(reg.Itx));
im = uint8(bfWrapper(double(im)));
opts.BlackWhite = false;
opts.FrangiScaleRange = [1 4];
opts.FrangiScaleRatio = 1;
[Iout,scale,direction] = FrangiFilter2D(single(im),opts);
figure;imshow(Iout);

% figure;imshow(Iout>0.5)


%% Image processing start:


im = flipud(reg.Itx);
im = uint8(bfWrapper(double(im)));

% Ridge
    blksze = 6; thresh = .2;
    [normim, mask] = ridgesegment(im, blksze, thresh);
    show(normim,1);

    % Determine ridge orientations
    [orientim, reliability, coherence] = ridgeorient(normim, 1, 3,3);
    figure;imagesc(reliability)
    
    plotridgeorient(orientim, 5, im, 2)
    show(reliability,6)
    
% Determine ridge frequency values across the image
    blksze = 20; 
    [freq, medfreq] = ridgefreq(normim, mask, orientim, blksze, 5, 5, 50);
    show(freq,3) 
% Actually I find the median frequency value used across the whole
    % fingerprint gives a more satisfactory result...    
    freq = medfreq.*mask;
    
    % Now apply filters to enhance the ridge pattern
    newim = ridgefilter(normim, orientim, freq, 0.5, 0.5, 1);
    show(newim,4);
    
    % Binarise, ridge/valley threshold is 0
    binim = newim > 0;
    show(binim,5);
    
    
    % Display binary image for where the mask values are one and where
    % the orientation reliability is greater than 0.5
    show(binim.*mask.*(reliability>0.6), 7)
%%
im2edge = uint8(flipud(reg.Itx));
im2edge = uint8(bfWrapper(double(im2edge)));
% edgeim = edge(reg.Itx,'canny',[.05 .1],2);
edgeim = edge(im2edge,'canny',[.05 .2],2);

figure;imshow(im2edge)


imFig1 = figure;
    imshow(edgeim);

% edgelink
[edgelist,labelededgeim] = edgelink(edgeim,300);

imFig2 = figure;
    drawedgelist(edgelist,size(im),1,'rand',2);