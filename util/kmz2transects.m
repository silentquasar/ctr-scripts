function [whoiTransect, aplTransect, utTransect, fig] = kmz2transects(kmzName)
% kmz2transects 

% created to work with input file kmzName = 'mission planning whoi 2.kmz';
    %   unzips .kmz to .kml
    %   reads in rectangle corners
    %   draws transect through midpoint of rectangles, lengthwise
    %   creates plot

% outputs:
    %    transects are 2xN arrays containing N lat,lon pairs
	%    fig is a figure showing bounding boxes and transects
   
    
% unzip .kmz by putting doc.kml in temp folder
tmpID = randi(1e4,1);
tmpReadFolder = sprintf('tempFolder%05.f-r',tmpID);
    mkdir(tmpReadFolder)
unzip(kmzName,tmpReadFolder) 
kmlDir = dir(fullfile(tmpReadFolder,'*.kml'));
if length(kmlDir)>1
    disp('More than one kml file in this kmz. That''s weird ...')
    error('Check the kmz file. Something is wrong.')
else
    kmlReadFile = kmlDir.name;
end

% now load doc.kml 
kmlContents = kml2struct([tmpReadFolder,'\',kmlReadFile]);

%WHOI 
% access lats and lons for box corners 
% 1 and 5 are repeated. order is starting upper right, clockwise.
whoi.boxLons = kmlContents(3).Lon; whoi.boxLats = kmlContents(3).Lat;
[whoi.boxY whoi.boxX] = ll2UTM(whoi.boxLats,whoi.boxLons);
% find midpoints between corners of rectangle on short leg
whoi.mpA = [(whoi.boxX(4)+whoi.boxX(3))/2, (whoi.boxY(4)+whoi.boxY(3))/2];
whoi.mpB = [(whoi.boxX(1)+whoi.boxX(2))/2, (whoi.boxY(1)+whoi.boxY(2))/2];
% now draw transect between A and B
whoi.xutmwp = [whoi.mpA(1),whoi.mpB(1)];
whoi.yutmwp = [whoi.mpA(2),whoi.mpB(2)];
whoi.xwp = whoi.xutmwp;
whoi.ywp = whoi.yutmwp;
whoi.s = hypot(diff(whoi.xwp),diff(whoi.ywp));
whoi.stx = 0:10:whoi.s;
whoi.xtx = interp1([0 whoi.s],whoi.xwp,whoi.stx);
whoi.ytx = interp1([0 whoi.s],whoi.ywp,whoi.stx);
whoi.Etx = whoi.xtx; 
whoi.Ntx = whoi.ytx;
[whoi.Lattx whoi.Lontx] = UTM2ll(whoi.Ntx, whoi.Etx, 18);

%APL
apl.boxLons = kmlContents(4).Lon; apl.boxLats = kmlContents(4).Lat;
[apl.boxY apl.boxX] = ll2UTM(apl.boxLats,apl.boxLons);
% find midpoints between corners of rectangle on short leg
apl.mpA = [(apl.boxX(4)+apl.boxX(3))/2, (apl.boxY(4)+apl.boxY(3))/2];
apl.mpB = [(apl.boxX(1)+apl.boxX(2))/2, (apl.boxY(1)+apl.boxY(2))/2];
% now draw transect between A and B
apl.xutmwp = [apl.mpA(1),apl.mpB(1)];
apl.yutmwp = [apl.mpA(2),apl.mpB(2)];
apl.xwp = apl.xutmwp;
apl.ywp = apl.yutmwp;
apl.s = hypot(diff(apl.xwp),diff(apl.ywp));
apl.stx = 0:10:apl.s;
apl.xtx = interp1([0 apl.s],apl.xwp,apl.stx);
apl.ytx = interp1([0 apl.s],apl.ywp,apl.stx);
apl.Etx = apl.xtx; 
apl.Ntx = apl.ytx;
[apl.Lattx apl.Lontx] = UTM2ll(apl.Ntx, apl.Etx, 18);


% UT
ut.boxLons = kmlContents(5).Lon; ut.boxLats = kmlContents(5).Lat;
[ut.boxY ut.boxX] = ll2UTM(ut.boxLats,ut.boxLons);
% find midpoints between corners of rectangle on short leg
ut.mpA = [(ut.boxX(4)+ut.boxX(3))/2, (ut.boxY(4)+ut.boxY(3))/2];
ut.mpB = [(ut.boxX(1)+ut.boxX(2))/2, (ut.boxY(1)+ut.boxY(2))/2];
% now draw transect between A and B
ut.xutmwp = [ut.mpA(1),ut.mpB(1)];
ut.yutmwp = [ut.mpA(2),ut.mpB(2)];
ut.xwp = ut.xutmwp;
ut.ywp = ut.yutmwp;
ut.s = hypot(diff(ut.xwp),diff(ut.ywp));
ut.stx = 0:10:ut.s;
ut.xtx = interp1([0 ut.s],ut.xwp,ut.stx);
ut.ytx = interp1([0 ut.s],ut.ywp,ut.stx);
ut.Etx = ut.xtx; 
ut.Ntx = ut.ytx;
[ut.Lattx ut.Lontx] = UTM2ll(ut.Ntx, ut.Etx, 18);


% make final variables
whoiTransect = [whoi.Lattx; whoi.Lontx];
aplTransect = [apl.Lattx; apl.Lontx];
utTransect = [ut.Lattx; ut.Lontx];



fig=figure;
xlabel('lon')
ylabel('lat')
hold on
plot(whoi.boxLons,whoi.boxLats,'-g','linewidth',2)
plot(apl.boxLons,apl.boxLats,'-b','linewidth',2)
plot(ut.boxLons,ut.boxLats,'-r','linewidth',2)

plot(whoiTransect(2,:),whoiTransect(1,:),'-k'); text(whoiTransect(2,end),whoiTransect(1,end),'WHOI');
plot(aplTransect(2,:),aplTransect(1,:),'-k'); text(aplTransect(2,end),aplTransect(1,end),'APL')
plot(utTransect(2,:),utTransect(1,:),'-k'); text(utTransect(2,end),utTransect(1,end),'UT');


% delete temp folder
rmdir(tmpReadFolder,'s')

end
