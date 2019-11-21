% List of open inputs
% fMRI model specification: Directory - cfg_files
% fMRI model specification: Scans - cfg_files
% fMRI model specification: Onsets - cfg_entry
% fMRI model specification: Onsets - cfg_entry
% fMRI model specification: Onsets - cfg_entry
% fMRI model specification: Onsets - cfg_entry
clear all; %#ok<CLALL>
clc;

% Base directory
baseDir = '/Users/miso/Documents/Experiments/Rankin/Magnum2/JasonBatch/';
% Get subject folders
sbjs = dir([baseDir 'Subjects/0*']);

% Calculate number of runs
nrun = length(sbjs); 
jobfile = {[baseDir 'localizerDesignMatMaker_job.m']};
jobs = repmat(jobfile, 1, nrun);
inputs = cell(6, nrun);
toRemove = {};

for crun = 1:nrun
    try
        % Get directories
        sbjName = sbjs(crun).name;
        sbjDir = [baseDir 'Subjects/' sbjName '/'];
        
        % Get preprocessed localizer file
        locFile = [sbjDir 'swa' sbjName '_loc.nii'];
        
        % Check if localizer exists
        if ~isfile(locFile)
            warning([sbjName ' is missing preprocessed localizer file, ' ...
                'skipping.']);
            toRemove = [toRemove crun];  %#ok<*AGROW>
            continue
        end
        
        % Get trial file
        trialFile = [baseDir 'Subjects/BehavioralDataFromLoc/s' ...
            sbjName(1:3) '_r1_' sbjName(4:numel(sbjName)) ...
            '_ProjImagLoc.mat'];
        
        % Check if trial file exists
        if ~isfile(trialFile)
            warning([sbjName ' is missing trial file, skipping.']);
            toRemove = [toRemove crun];
            continue
        end
        
        % Set directory for design matrix
        inputs{1, crun} = cellstr(sbjDir);
        
        % Get localizer run info
        tmp = niftiinfo(locFile);
        
        % Fill cell array with slices, note only 1 session is assumed
        slices = strcat(repmat({[locFile ',']}, tmp.ImageSize(4), 1), ...
            num2str([1:tmp.ImageSize(4)]')); %#ok<NBRAK>
        slices = strrep(slices, ' ', '');

        % Set scans
        inputs{2, crun} = cellstr(slices);
        
        % Load trial file
        load(trialFile)
        trialData = struct2table(trialInfo.trial);
        
        % Get block info
        blockChange = arrayfun(@(x) find(trialData.blknum == x, 1), ...
            unique(trialData.blknum));
        blockCat = trialData.cat(blockChange);
        blockOnset = floor(blockChange/2);
        
        % Populate Face onsets
        inputs{3, crun} = blockOnset(contains(blockCat, 'F'))';
        
        % Populate Object onsets
        inputs{4, crun} = blockOnset(contains(blockCat, 'O'))';
        
        % Populate Body onsets
        inputs{5, crun} = blockOnset(contains(blockCat, 'B'))';
        
        % Populate Scrambled onsets
        inputs{6, crun} = blockOnset(contains(blockCat, 'S'))';

    catch
        warning(['Subject ' sbjName ' skipped due to unknown error.']);
        toRemove = [toRemove crun]; 
    end
end

% Remove runs that failed to acquire inputs
inputs(:, [toRemove{:}]) = [];
jobs(:, [toRemove{:}]) = [];

% Print
fprintf(['Running batch on ' num2str(length(jobs)) ' subjects.\n']);

% Run
spm('defaults', 'FMRI');
spm_jobman('run', jobs, inputs{:});

% Print skipped subjects
fprintf('Subjects skipped\n');
fprintf('%s\n', sbjs([toRemove{:}], :).name);
