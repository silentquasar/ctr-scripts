%% Load local vars, if any
if exist('localvars.m', 'file')
    localvars;
else
    savePath = fullfile('C:','Data','CTR','floodFront');
    scrDir = fullfile('C:','Data','CTR','ctr-scripts');
%     cubeDir = fullfile('D:','DAQ-data','processed');
    cubeDir = fullfile('D:','Data','CTR','DAQ-data','processed');
    ebbNum = 45; % 74: 2017-June-22 0600
end

%% LABEL
saveFilePrefix = 'plumeFront';

%% PREP
addpath(genpath(scrDir))
doDebug = false;

%% TIDE HOUR INFO
[uTide,dnTide] = railroadBridgeCurrentLocal;
dnMaxFlood = tideHrMaxEbb2dn(5,dnTide,uTide);
    
%% CHOOSE THE TIME SPAN
%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Earliest max ebb in June is #45
if exist('thisFloodMax', 'var'), lastFloodMax = thisFloodMax; else, lastFloodMax = -1; end
thisFloodMax = dnMaxFlood(ebbNum);
%%%%%%%%%%%%%%%%%%%%%%%%%%
disp(datestr(thisFloodMax))

deltaDn = 15/60/24;
% dnVec = (thisFloodMax - 3.5/24)  :  deltaDn  : (thisFloodMax + 3.5/24);
dnVec = (thisFloodMax - 3/24)  :  deltaDn  : (thisFloodMax + 2/24);

clear cubeNamesAll
tic
for i = 1:length(dnVec)
    cubeNamesAll{i} = cubeNameFromTime(dnVec(i),cubeDir);
end
cubeNamesAll(cellfun(@isempty,cubeNamesAll)) = [];
toc
cubeName = unique(cubeNamesAll);
% files = getFiles(cubeDir);

%% INITIALIZE SPATIAL ARRAYS
sampleTime = datenum([2017 06 09 21 23 41]);
sampleCubeName = cubeNameFromTime(sampleTime,cubeDir);
load(sampleCubeName,'Azi','Rg','results','timeInt','timex');
if ~exist('timex','var') || isempty(timex)
    load(sampleCubeName,'data')
    timex = mean(data,3);
end
% Rectify to x-y

[AZI,RG] = meshgrid(mod(90-Azi-results.heading,360),Rg);

[xrad,yrad] = pol2cart(AZI*pi/180,RG);
xutm = xrad + results.XOrigin;
yutm = yrad + results.YOrigin;
[lat,lon] = UTMtoll(yutm,xutm,18);

% Choose azimuthal swath
% aziSwath = 190:.5:345;
aziSwath = horzcat([190:0.5:359.5],[0:0.5:180]);

aziIdx = interp1(AZI(1,:),1:length(Azi),aziSwath,'nearest');

for i = 1:numel(aziIdx)
    foo(i) = Azi(aziIdx(i));
end

% Choose range decimation
rgDecim = 5;
rgIdx = 1:5:length(Rg);

% Generate subimage coordinates
subRg  = Rg(rgIdx);
subAzi = Azi(aziIdx);
subLon = lon(rgIdx,aziIdx);
subLat = lat(rgIdx,aziIdx);
sampleIm  = uint8(timex(rgIdx,aziIdx));

%%% Debug %%%
if doDebug
dbFig(1) = figure;
    hp = pcolor(subLon,subLat,sampleIm);
        shading flat
        axis image
        colormap(hot)
        caxis([0 220])
        aspectRatio = (max(lon(:))-min(lon(:)))/(max(lat(:))-min(lat(:)));
        daspect([aspectRatio,1,1])
dbFig(2) = figure;
    hp = imagesc(sampleIm);
        colormap(hot)
        caxis([0 220])
end
%%% /Debug %%%


%% LOOP THRU FILES

clear tx
itx = 1;
% waitfor(msgbox('WARNING: Reset to for i = 1:...'));
for i = 1:length(cubeName)
    fprintf('%d of %d.',i,length(cubeName))
    load(cubeName{i},'timeInt','timex','header')
    if header.rotations > 64
        fprintf('Long run. Rot:')
        % Deal with long run
        mat = matfile(cubeName{i});
        rotTimes = epoch2Matlab(mean(timeInt));
        dnIdx = find(strcmp(cubeName{i},cubeNamesAll(:)));  % I think this is always just i
        rotIdx = interp1(rotTimes(32:end-32),32:header.rotations-32,dnVec(dnIdx),'nearest','extrap');
        rotIdx = unique(rotIdx);
        fdata = mean(mat.data(:, :, rotIdx-31:rotIdx+32), 3);
        for j = rotIdx
            fprintf('%d. ', j)
            fprintf('%s ', datestr(dnVec(dnIdx)));
            thisFrame = fdata(rgIdx,aziIdx);
            testFig = figure('position',[0 0 500 800]);
                imagesc(bfWrapper(double(thisFrame)));
                title('Left click to continue. Right click to reject.')
            [~,~,button] = ginput(1);
            delete(testFig)
            if button==1
                
                thisTime = epoch2Matlab(mean(timeInt(:,j)));
                
                curveDone = false;
                while ~curveDone
                    thisCurve = img2curve(uint8(thisFrame));
                    checkFig = figure('position',[0 0 1280 720]);
                        imagesc(bfWrapper(double(thisFrame)))
                        hold on
                        plot(thisCurve.x,thisCurve.y,'-r','linewidth',1.5)
                    title('Happy with this curve? LMB=yes; RMB=try again')
                    [~,~,button] = ginput(1);
                    close(checkFig)
                    if button==1
                        curveDone = true;
                    end
                end
                       
                for ip = 1:length(thisCurve.x)
                    thisCurve.lon(ip) = subLon(round(thisCurve.y(ip)),round(thisCurve.x(ip)));
                    thisCurve.lat(ip) = subLat(round(thisCurve.y(ip)),round(thisCurve.x(ip)));
                end
                %%%%%%%%%%%%%

                txNow.dn  = thisTime;
                txNow.lon = smooth(thisCurve.lon,5,'rlowess');
                txNow.lat = smooth(thisCurve.lat,5,'rlowess');

                showFig = figure('position',[0 0 1280 720]);
                    subplot(211)
                    pcolor(subLon,subLat,bfWrapper(double(thisFrame)))
                        shading flat
                        axis image
                    subplot(212)
                    hold on
                    pcolor(subLon,subLat,bfWrapper(double(thisFrame)))
                        shading flat
                        axis image
                    plot(txNow.lon,txNow.lat,'-r','linewidth',1.5)
                title('Click to continue')
                ginput(1);
                close(showFig);
                
                %%%%%%%%%%%%%

                tx(itx) = txNow;
                itx = itx + 1;
            end
        end
    else
        thisFrame = timex(rgIdx,aziIdx);
        testFig = figure('position',[0 0 500 800]);
            imagesc(bfWrapper(double(thisFrame)));
            title('Left click to continue. Right click to reject.')
        [~,~,button] = ginput(1);
        delete(testFig)
        if button==1
            thisTime = epoch2Matlab(mean(timeInt(:)));
            
            curveDone = false;
            while ~curveDone
                thisCurve = img2curve(uint8(thisFrame));
                checkFig = figure('position',[0 0 1280 720]);
                    imagesc(bfWrapper(double(thisFrame)))
                    hold on
                    plot(thisCurve.x,thisCurve.y,'-r','linewidth',1.5)
                title('Happy with this curve? LMB=yes; RMB=try again')
                [~,~,button] = ginput(1);
                close(checkFig)
                if button==1
                    curveDone = true;
                end
            end
                  
            for ip = 1:length(thisCurve.x)
                thisCurve.lon(ip) = subLon(round(thisCurve.y(ip)),round(thisCurve.x(ip)));
                thisCurve.lat(ip) = subLat(round(thisCurve.y(ip)),round(thisCurve.x(ip)));
            end
            %%%%%%%%%%%%%
            
            txNow.dn  = thisTime;
            txNow.lon = smooth(thisCurve.lon,5,'rlowess');
            txNow.lat = smooth(thisCurve.lat,5,'rlowess');
            
            showFig = figure('position',[0 0 1280 720]);
                    subplot(211)
                    pcolor(subLon,subLat,bfWrapper(double(thisFrame)))
                        shading flat
                        axis image
                    subplot(212)
                    hold on
                    pcolor(subLon,subLat,bfWrapper(double(thisFrame)))
                        shading flat
                        axis image
                    plot(txNow.lon,txNow.lat,'-r','linewidth',1.5)
                title('Click to continue')
                ginput(1);
                close(showFig);
                
            %%%%%%%%%%%%%
            
            tx(itx) = txNow;
            itx = itx + 1;
        end
        
    end
    fprintf('\n')
end


showFig = figure('position',[0 0 1280 720]);
    hp = pcolor(subLon,subLat,sampleIm);
        shading flat
        axis image
        colormap(hot)
        caxis([0 220])
        aspectRatio = (max(lon(:))-min(lon(:)))/(max(lat(:))-min(lat(:)));
        daspect([aspectRatio,1,1])
   hold on
   if ~exist('tx','var') || isempty(tx)
       title('No radar runs for this tide. Click to continue')
       ginput(1);
       close(showFig)
       return
   else
       for i = 1:length(tx)
           plot(tx(i).lon,tx(i).lat,'-c','linewidth',1.5)
       end
       title('Click to continue')
       ginput(1);
       close(showFig);
   end


%%
front = tx;
%%
for i = 1:length(front)
    front(i).tideHr = tideHourMaxEbb(front(i).dn,dnTide,uTide,true);
end

saveName = sprintf('%s_%s_to_%s',saveFilePrefix,datestr(tx(1).dn,'yyyymmddTHHMMSSZ'),datestr(tx(end).dn,'yyyymmddTHHMMSSZ'));
if ~exist(savePath,'dir');mkdir(savePath);end
if exist(fullfile(savePath,saveName),'file');disp('File to save exists. Do so manually.\n');keyboard;end
save(fullfile(savePath,saveName),'-v7.3','front')
fprintf('Front time series saved to: %s\n',fullfile(savePath,saveName))


