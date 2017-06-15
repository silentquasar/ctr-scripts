function cube2timex(cubeFile,timexFile)

% User options: leave empty [] for Matlab auto-sets
colorAxLimits           = [0 220];
axisLimits              = [-6 6 -6 6]; % Full In kilometers
% axisLimits              = [-3 3 -3 1]; % Zoom In kilometers
% radialFalloffHeading    = 90; % Heading to use for empirical range falloff
% falloffSmoothingScale   = 100; % Smoothing scale for empirical falloff so that fronts, etc., get averaged out
plottingDecimation      = [5 1]; % For faster plotting, make this [2 1] or higher

% User overrides: leave empty [] otherwise
userHeading             = 281;                      % Use this heading instead of results.heading
userOriginXY            = [0 0];                    % Use this origin for meter-unit scale
userOriginLonLat        = [-72.343472 41.271747];   % Use these lat-lon origin coords

% Implement user overrides
if ~isempty(userHeading)
    heading = userHeading;
else
    heading = results.heading;
end
if ~isempty(userOriginXY)
    x0 = userOriginXY(1);
    y0 = userOriginXY(2);
else
    x0 = results.XOrigin;
    y0 = results.YOrigin;
end
if ~isempty(userOriginLonLat)
    lon0 = userOriginLonLat(1);
    lat0 = userOriginLonLat(2);
else
    [lat0,lon0] = UTMtoll(results.YOrigin,results.XOrigin,str2double(results.UTMZone(1:2)));
end


% Load radar data
load(cubeFile,'Azi','Rg','results','data','timeInt')
% Convert to world coordinates
[AZI,RG] = meshgrid(Azi,Rg);
TH = pi/180*(90-AZI-heading);
[xdom,ydom] = pol2cart(TH,RG);
xdom = xdom + x0;
ydom = ydom + y0;
% Compute timex
timex = mean(data,3);

nowTime = epoch2Matlab(mean(timeInt(:))); % UTC

% Load tidal data
% Times are UTC, currents are m/s 
[yCurrent.RB dnCurrent.RB] = railroadBridgeCurrent; % Railroad Bridge 
dirEbb.RB = 198; %deg True
dirFlood.RB = 0; %deg True
latCurrent.RB = 41.3167; %N
lonCurrent.RB = 72.3462; %W

[yCurrent.SMR dnCurrent.SMR] = sixMileReefCurrent; % Six Mile Reef 
dirEbb.SMR = 40; %deg True
dirFlood.SMR = 235; %deg True
latCurrent.SMR = 41.1805; %N
lonCurrent.SMR = 72.4483; %W

[yCurrent.CP dnCurrent.CP] = cornfieldPointCurrent; % Cornfield Point 
dirEbb.CP = 94; %deg True
dirFlood.CP= 256; %deg True
latCurrent.CP = 41.215; %N
lonCurrent.CP = 72.3733; %W

% Elevation (no longer using...)
% [yElev.SB dnElev.SB] = railroadBridgeElevation; % Saybrook Points (UTC)


% Load mooring data
moor = load('casts_deploy_lisbuoys_065781_20170519_1302.mat');
[moorN moorE] = lltoUTM(moor.latcast, moor.loncast);
[radN radE] = lltoUTM(userOriginLonLat(2), userOriginLonLat(1));
moorX = moorE - radE;
moorY = moorN - radN; 
% moor2 = load('nav_ctriv_deploy_may2017.mat'); %the other file... 
   
% Load wind data from wind station file
[dnWind,magWind,dirWind] = loadWindStation('SABC3.csv', nowTime); 

% Load discharge data from USGS file
[dnDischarge,rawDischarge,trDischarge] = loadDischarge('CTdischarge_Site01193050.txt');

% Plot!
% setup
fig = figure('visible','on');
fig.PaperUnits = 'inches';
fig.PaperPosition = [0 0 12.8 7.2];
fig.Units = 'pixels';
fig.Position = [0 0 1280 720];
axRad = axes('position',[-0.1081    0.1167    0.7750    0.8150]);
axTide = axes('position',[0.5419    0.7269    0.4200    0.2053],'fontsize',8);
axWind = axes('position',[0.6696    0.4000    0.1544    0.2547],'fontsize',8);
axDischarge = axes('position',[0.5452    0.1358    0.4169    0.2011],'fontsize',8);

% radar subplot 
set(fig,'currentaxes',axRad)
di = plottingDecimation(1);
dj = plottingDecimation(2);
pcolor(xdom(1:di:end,1:dj:end)/1e3,ydom(1:di:end,1:dj:end)/1e3,timex(1:di:end,1:dj:end));
hold on
shading interp
axis image
colormap(hot)
if ~isempty(axisLimits)
axis(axisLimits)
end
if ~isempty(colorAxLimits)
caxis(colorAxLimits)
end
grid on
axRad.XTick = axRad.XTick(1):0.5:axRad.XTick(end);
axRad.YTick = axRad.YTick(1):0.5:axRad.YTick(end);
xlabel('[km]','fontsize',14,'interpreter','latex')
ylabel('[km]','fontsize',14,'interpreter','latex')
axRad.TickLabelInterpreter = 'latex';
runLength = timeInt(end,end)-timeInt(1,1);
titleLine1 = sprintf('\\makebox[4in][c]{Lynde Point X-band Radar: %2.1f min Exposure}',runLength/60);
titleLine2 = sprintf('\\makebox[4in][c]{%s UTC (%s EDT)}',datestr(epoch2Matlab(mean(timeInt(:))),'yyyy-mmm-dd HH:MM:SS'),datestr(epoch2Matlab(mean(timeInt(:)))-4/24,'HH:MM:SS'));
% titleLine2 = sprintf('\\makebox[4in][c]{%s UTC (%s EDT)}',datestr(nowTime+4/24,'yyyy-mmm-dd HH:MM:SS'),datestr(nowTime,'HH:MM:SS'));
title({titleLine1,titleLine2},...
'fontsize',14,'interpreter','latex');
%add mooring plots
plot(moorX/1000,moorY/1000,'^c','linewidth',1.5,'markersize',8.5,'MarkerFaceColor','none') 


% Tide plot
set(fig,'currentaxes',axTide)
cla(axTide)
hold(axTide,'on')
h1=plot([nowTime-2 nowTime+2],[0 0],'-','color',[.75 .75 .75]);
h2=plot([nowTime nowTime],[-10 10],'-','color',[.5 .5 .5],'linewidth',2);
xlim([nowTime-1 nowTime+1])
set(axTide,'xtick',fix([nowTime-1:nowTime+1]))
set(axTide,'xticklabel','')
datetick('x','mmm-dd','keeplimits','keepticks')    
hy1 = ylabel('Current [m/s]','fontsize',11,'interpreter','latex');
tmp1 = get(hy1,'position');
set(hy1,'position',[tmp1(1)+1/50 tmp1(2:3)])
ylim([-2.1 2.1])
title([datestr(nowTime,'HH:MM:SS'),' UTC'],'fontsize',14,'interpreter','latex')
axTide.TickLabelInterpreter = 'latex';
    
% current in sound (Cornfield Point "CP")
    h3=area(dnCurrent.CP,yCurrent.CP,'facecolor','green');
    alpha(0.25)
    
% current in river (railroad bridge "RB")
    h4=area(dnCurrent.RB,yCurrent.RB,'facecolor','blue');
    
legend([h3 h4],{'Sound','River'})

% yyaxis right %elevation
%     plot(dnElev.SB,yElev.SB-(2.925-2.368),'-k','linewidth',1) % converting from MLLW (2.368m) to MSL (2.925) ref to NAVD
%     hy2 = ylabel('Elevation [m]','fontsize',11,'interpreter','latex');
%     tmp2 = get(hy2,'position');
%     set(hy2,'position',[tmp2(1)-1/90 tmp2(2:3)])
%     set(gca,'ycolor','black')


% Wind plot
set(fig,'currentaxes',axWind);
cla(axWind)
% Create Circle
th = 0:0.01:3*pi;
xcircle = cos(th);
ycircle = sin(th);
plot(axWind,xcircle,ycircle,'-k','linewidth',1.25);hold on
% plot(axWind,.75*xcircle,.75*ycircle,'-','color',[.5 .5 .5],'linewidth',1.25)
axis image;axis([-1.05 1.05 -1.05 1.05])
[uWind vWind] = pol2cart((90-dirWind)*pi/180, 1); 
arrow([uWind vWind],[0 0],'baseangle',45,'width',magWind,'tipangle',25,'facecolor','red','edgecolor','red');
[uText vText] = pol2cart((90-180-dirWind)*pi/180,0.25); %position text off tip of arrow
text(uText,vText,[num2str(magWind),' m/s'],'horizontalalignment','center','interpreter','latex')
set(axWind,'xtick',[],'ytick',[],'xcolor','w','ycolor','w')
title('Wind','fontsize',14,'interpreter','latex')

% Discharge plot
set(fig,'currentaxes',axDischarge)
cla(axDischarge)
hold(axDischarge,'on')
% plot(dnDischarge,rawDischarge,'-k','linewidth',2) % plots raw discharge
plot(dnDischarge(~isnan(trDischarge)),trDischarge(~isnan(trDischarge)),'-k','linewidth',2)
plot([nowTime nowTime],[min(rawDischarge)-3000 max(rawDischarge)+3000],'-','color',[.5 .5 .5],'linewidth',2)
xlim([nowTime-4 nowTime+4])
ylim([min(rawDischarge)-3000 max(rawDischarge)+3000])
set(axDischarge,'xtick',fix([nowTime-4:nowTime+4]))
datetick('x','mmm-dd','keeplimits','keepticks')    
hy1 = ylabel('Discharge [ft$^3$/s]','fontsize',11,'interpreter','latex');
% tmp1 = get(hy1,'position');
% set(hy1,'position',[tmp1(1)+1/50 tmp1(2:3)])
box on
title('Discharge','fontsize',14,'interpreter','latex')
 


% save and close current figure
print(fig,'-dpng','-r100',timexFile)
close(fig)