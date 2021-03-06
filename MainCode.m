%% MainCode.m
% Main loop of the cell deformer tracking code.  Designed to input .avi 
% video files and track cells through the cell deformer device.  Designed
% to run multiple videos with minimal user interaction.

% Code from Dr. Amy Rowat's Lab, UCLA Department of Integrative Biology and
% Physiology
% Code originally by Bino Varghese (October 2011)
% Updated by David Hoelzle (January 2013)
% Updated by Sam Bruce, Ajay Gopinath, and Mike Scott (July 2013)

% Inputs
%   - .avi files are selected using a GUI
%   - The video names should include, anywhere in the name, the following:
%   1) "devNx10" where N is constriction width / template size to use
%       ex. "dev5x10..."
%   2) "Mfps", where M is the frame rate in frames per second
%       ex. "1200fps..."
%       Example of a properly formatted video name:
%       'dev5x10_1200fps_48hrppb_glass_4psi_20x_0.6ms_p12_041'

% Outputs
%   - An excel file with 5 sheets at the specified compiledDataPath
%       1) Total transit time (ms) and unconstricted area (pixels)
%       2) Transit time data (ms)
%       3) Area information at each constriction (pixels)
%       4) Approximate diameter at each constriction (pixels), calculated
%       as the average of major and minor axis of the cell
%       5) Eccentricity of each cell at each constriction

% Functions called
%   - PromptForVideos   (opens a GUI to load videos)
%   - MakeWaypoints     (Determines the constriction regions)
%   - CellDetection     (Filters the video frames to isolate the cells)
%   - CellTracking      (Labels and tracks cells through the device)
%   - progressbar       (Gives an indication of how much time is left)

% Updated 7/2013 by Mike
%       - Cut out the preprocessing 50 frames (required editing indicies of
%       the call for CellDetection
%       - Rearranged and commented the code to make it clearer
%       - Added the template.  Now MakeWaypoints is automatic and no
%       longer requires defining the cropping and constriction regions
%       - Eliminated redundant inputs and outputs from functions
%       - Eliminated 'segments', nobody used them
% Updated 7/16/2013 by Ajay
%       - separated all logic for prompting/selection of video files to
%       process into function PromptForVideos
%       - improved extraction of frame rates and template sizes from video
%       names by using regular expressions instead of ad-hoc parsing
%       - cleaned up any remaining legacy code and comments
%       - added better output of debugging information
%dbstop in MainCode at 147;
close all
clear variables
clc

addpath(genpath(fullfile(pwd, '/Helpers')));

%% Initializations
% Allocates an array for the data
numDataCols = 9;
lonelyCompiledData = zeros(1, numDataCols, 4);
pairedCompiledData = zeros(1, numDataCols, 4);

% Checks to see if Excel sheets or CSV files will be the output medium
% If an error is thrown when trying to initialize the Excel server, Excel
% is not available and CSV should be used instead
try
    actxserver ('Excel.Application'); 
    shouldUseExcel = true;
catch
    shouldUseExcel = false;
end

% Initializes a progress bar
progressbar('Overall', 'Cell detection', 'Cell tracking');

%% Load video files and prepare any metadata
[pathNames, videoNames] = PromptForVideos('F:\Ajay\Microfluidics\Mock');

% Checks to make sure at least one video was selected for processing
if(isempty(videoNames{1}))
    disp('No videos selected.');
    close all;
    return;
end

% Extracts the template size and frame rates from the video name.
%   The video names should include, anywhere in the name, the following:
%   1) "devNx10" where N is constriction width / template size to use
%       ex. "dev5x10..."
%   2) "Mfps", where M is the frame rate in frames per second
%       ex. "1200fps..."
% Example of properly formatted video names:
% 'dev5x10_1200fps_48hrppb_glass_4psi_20x_0.6ms_p12_041'

% for i = 1:length(videoNames)
%     videoName = videoNames{i};
%     [j,k] = regexp(videoName, 'dev\d*x'); % store start/end indices of template size
%     [m, n] = regexp(videoName, '\d*fps'); % store start/end indices of frame rate
%     templateSize = videoName((j+3):(k-1)); % removes 'dev' at the start, and 'x' at the end
%     frameRate = videoName(m:(n-3)); % removes 'fps'  at the end
%     
%     templateSizes(i) = str2double(templateSize);
%     frameRates(i) = str2double(frameRate);
% end

% TEMPORARILY USED TO PROCESS OLD VIDEO NAMES HERE: Y:\Kendra\HL60 Cell Line\120000 - Amy Rowat Data_hl60_cells\120223 hl60\HL60\d0\6psi 5um
% To use with normal videos, comment the for loop below and uncomment the for loop immediately above
for i = 1:length(videoNames)
    videoName = sscanf(videoNames{i},'%s');
    [j,k] = regexp(videoName, 'psi\d*um'); % store start/end indices of template size
    [m, n] = regexp(videoName, '\d*fps'); % store start/end indices of frame rate
    templateSize = videoName((j+3):(k-2)); % removes 'dev' at the start, and 'x' at the end
    frameRate = videoName(m:(n-3)); % removes 'fps'  at the end
    
    templateSizes(i) = str2double(templateSize);
    frameRates(i) = str2double(frameRate);
end

tStart = tic;

% Create the folder in which to store the output data
% The output folder name is a subfolder in the folder where the first videos
% were selected. The folder name contains the time at which processing is
% started.
outputFolderName = fullfile(pathNames{1}, ['processed_EVERYFR_', datestr(now, 'mm-dd-YY_HH-MM')]);
if ~(exist(outputFolderName, 'file') == 7)
    mkdir(outputFolderName);
end

lastPathName = pathNames{i};

%% Initialize cell data containers
% Initialize cell array cellData to store the cell data
% of each cell at every frame between the start and end lines
% The data for the stored cells are referenced as: 
%   cellData{lane#}{cellID}
cellData = cell(1, 16);
cellPerimsData = cell(1, 16);
for i = 1:16
    cellData{i} = {};
    cellPerimsData{i} = {};
    cellPerimsData{i}{1} = {};
end

%% Iterates through videos to filter, analyze, and output the compiled data
for i = 1:length(videoNames)
    % Initializations
    currPathName = pathNames{i};
    outputFilename = fullfile(outputFolderName, regexprep(currPathName, '[^a-zA-Z_0-9-]', '~'));
    currVideoName = videoNames{i};
    currVideo = VideoReader(fullfile(currPathName, currVideoName));
    startFrame = 1;
    endFrame = currVideo.NumberOfFrames;
    
    disp(['==Video ', num2str(i), '==']);
    
    % Calls the MakeWaypoints function to define the constriction region.
    % This function draws a template with a line across each constriction;
    % these lines are used in calculating the transit time
    [mask, lineTemplate, xOffset] = MakeWaypoints(currVideo, 5);%templateSizes(i));
    
    % Calls CellDetection to filter the images and store them in
    % 'processedFrames'.  These stored image are binary and should
    % (hopefully) only have the cells in them
    [processedFrames] = CellDetection(currVideo, startFrame, endFrame, currPathName, currVideoName, mask);
    
    % Calls CellTrackingEveryFrame to track the detected cells.
    %[lonelyData, pairedData] = 
    numFrames = (endFrame-startFrame+1);
    [cellData, cellPerimsData] = CellTrackingEveryFrame(numFrames, lineTemplate, processedFrames, xOffset, cellData, cellPerimsData);

    progressbar((i/(size(videoNames,2))), 0, 0)
    clear processedFrames;
    
    nameIdx = i+5;
    eval(sprintf('cellData%d = cellData', nameIdx));
    eval(sprintf('cellPerimsData%d = cellPerimsData', nameIdx));
    clear cellData; clear cellPerimsData;
    
    save([outputFilename, '_cellData', num2str(nameIdx), '.mat'], sprintf('cellData%d', nameIdx));
    save([outputFilename, '_cellPerims', num2str(nameIdx), '.mat'], sprintf('cellPerimsData%d', nameIdx));    
    
    eval(sprintf('clear cellData%d', nameIdx));
    eval(sprintf('clear cellPerimsData%d', nameIdx));
    
    cellData = cell(1, 16);
    cellPerimsData = cell(1, 16);
    for jj = 1:16
        cellData{jj} = {};
        cellPerimsData{jj} = {};
        cellPerimsData{jj}{1} = {};
    end
end

%% Output debugging information
totalTime = toc(tStart);
avgTimePerVideo = totalTime/length(videoNames);

disp(sprintf('\n\n==========='));
disp(['Total time to analyze ', num2str(length(videoNames)), ' video(s): ', num2str(totalTime), ' secs']);
disp(['Average time per video: ', num2str(avgTimePerVideo), ' secs']);
disp(sprintf('\nOutputting metadata...'));

runOutputPaths = unique(pathNames);
for i = 1:length(runOutputPaths)
    runOutputFile = fopen(fullfile(runOutputPaths{i}, 'process_log_EVERYFR.txt'), 'wt');
    vidIndices = strcmp(runOutputPaths{i}, pathNames);
    vidsProcessed = videoNames(vidIndices);
    
    fprintf(runOutputFile, '%s\n\n', 'The following files were processed from this folder:');
    fprintf(runOutputFile, '%s\n', '============');
    for j = 1:length(vidsProcessed)
        fprintf(runOutputFile, '%s\n', vidsProcessed{j});
    end
    fprintf(runOutputFile, '%s\n\n', '============');
    
    fprintf(runOutputFile, '%s%s\n', 'Processing was finished at: ', datestr(now, 'mm-dd-YY HH:MM:SS'));
    fprintf(runOutputFile, '%s%s\n', 'Output files are located at: ', outputFolderName);
    
    fclose(runOutputFile);
end

disp('Done.');