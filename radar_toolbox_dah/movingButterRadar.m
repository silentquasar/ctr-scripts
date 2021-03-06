function fCube = movingButterRadar(Cube,windowSize,filterType)
% fCube = movingAverageRadar(Cube,windowSize,filterType)
%
% This function inputs a radar Cube (as created by ReadBin, etc.) and 
% 	performs a lowpass filter on the time series of rotations. In order to
% 	maintain the data structure and save space, the output Cube is the same
% 	as the input, but with the Cube.data variable replaced. Note that any
% 	NaN in the raw time series will result in all NaNs in the filtered time
% 	series.
% 
% Subscripts: cartCube.m
% 
% INPUT:
% 	Cube		=	Radar Cube structure (as created by ReadBin.m, etc.)
% 	windowSize 	=	Filter window size (in rotations, not seconds; e.g. 45 for 1 min means)
% 	filterType 	= 	Type of filter [string]. Use 'filter' for simple moving average;
% 						use 'filtfilt' for double moving average with no phase shift.
% OUTPUT:
% 	fCube 		= 	Radar Cube structure with 'data' field replaced with filtered data


fCube = Cube;

if ~isfield(fCube,'xdom')
    Cube = cartCube(Cube);
    fCube = cartCube(fCube);
end
fCube.data = fCube.data*0;

fprintf('Filtering %s in parallel ...',Cube.header.file)
str = '';
if size(Cube.data,3)<windowSize
    fprintf('Data length (%d) too short for window used (%d).\n',size(Cube.data,3),windowSize)
    fCube.data = NaN;
    return
end
fs = 1./nanmean(diff(Cube.time(1,:)));
fc = 1./windowSize;
fn = 2*fc/fs;
[b,a] = butter(9,fn);
if size(Cube.data,3)>3*windowSize
    for i = 1:size(Cube.data,1)

        for dels = 1:length(str);fprintf('\b');end
        str = sprintf(' %d/%d ranges done.',i,size(Cube.data,1));
        fprintf('%s',str);

        tmpSliceIn = squeeze(Cube.data(i,:,:));
        tmpSliceOut = tmpSliceIn;
        parfor j = 1:size(Cube.data,2)
    %         eval(sprintf('fCube.data(i,j,:) = uint8(%s(ones(1,windowSize)/windowSize,1,double(squeeze(Cube.data(i,j,:)))));',filterType))
            if strcmp(filterType,'filtfilt')
%                 tmpSliceOut(j,:) = uint8(filtfilt(ones(1,windowSize)/windowSize,1,double(squeeze(tmpSliceIn(j,:)))));
                tmpSliceOut(j,:) = uint8(filtfilt(b,a,double(squeeze(tmpSliceIn(j,:)))));
            elseif strcmp(filterType,'filt')
                tmpSliceOut(j,:) = uint8(filter(ones(1,windowSize)/windowSize,1,double(squeeze(tmpSliceIn(j,:)))));
            end
        end
        if strcmp(filterType,'filtfilt')
            fCube.data(i,:,:) = tmpSliceOut;
        elseif strcmp(filterType,'filt')
            fCube.data(i,:,ceil(windowSize/2):size(Cube.data,3)-floor(windowSize/2)) = tmpSliceOut(i,:,windowSize:end);
        end
    end
    fprintf(' Done.\n')
    
else
    
    if strcmp(filterType,'filtfilt')
        fprintf(' Cube too small for filtfilt. Using basic filter. ')
    end
    
    for i = 1:size(Cube.data,1)
        for dels = 1:length(str);fprintf('\b');end
        str = sprintf(' %d/%d ranges done.',i,size(Cube.data,1));
        fprintf('%s',str);

        tmpSliceIn = squeeze(Cube.data(i,:,:));
        tmpSliceOut = tmpSliceIn;
        parfor j = 1:size(Cube.data,2)
    %         eval(sprintf('fCube.data(i,j,:) = uint8(%s(ones(1,windowSize)/windowSize,1,double(squeeze(Cube.data(i,j,:)))));',filterType))
            if strcmp(filterType,'filtfilt')
                tmpSliceOut(j,:) = uint8(filter(ones(1,windowSize)/windowSize,1,double(squeeze(tmpSliceIn(j,:)))));
            elseif strcmp(filterType,'filt')
                tmpSliceOut(j,:) = uint8(filter(ones(1,windowSize)/windowSize,1,double(squeeze(tmpSliceIn(j,:)))));
            end
        end
        fCube.data(i,:,ceil(windowSize/2):size(Cube.data,3)-floor(windowSize/2)) = tmpSliceOut(:,windowSize:end);
    end
    fprintf(' Done.\n')
end

fCube.windowSize = windowSize;