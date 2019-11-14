% List of open inputs
% Slice Timing: Session - cfg_files
% Slice Timing: Number of Slices - cfg_entry
% Slice Timing: TA - cfg_entry
% Slice Timing: Slice order - cfg_entry
% Coregister: Estimate & Reslice: Reference Image - cfg_files
clear all; %#ok<CLALL>
clc;

% Overwrite?
overwrite = false;

% Base directory
baseDir = '/Users/Wasabi/Experiments_Wasabi/Rankin/Magnum/RestingJason/';
% Get subject folders
sbjs = dir([baseDir 'Subjects/0*']);

% Calculate number of runs
nrun = length(sbjs); 
jobfile = {[baseDir 'restingO_preproc_job.m']};
jobs = repmat(jobfile, 1, nrun);
inputs = cell(5, nrun);
toRemove = {};
for crun = 1:nrun
    try 
        % Get resting state nifti
        sbjName = sbjs(crun).name;
        sbjDir = [baseDir 'Subjects/' sbjName];
        resting = [sbjDir '/' sbjName '_resting.nii'];
        tmp = niftiinfo(resting);

        % Check if last output already exists
        if (isfile([sbjDir '/swa' sbjName '_resting.nii']) && ~overwrite)
            warning([sbjName ' is already processed, skipping.']);
            toRemove = [toRemove crun]; %#ok<*AGROW>
            continue
        end
        
        % Fill cell array with slices, note only 1 session is assumed
        slices = strcat(repmat({[resting ',']}, tmp.ImageSize(4), 1), ...
            num2str([1:tmp.ImageSize(4)]')); %#ok<NBRAK>
        slices = strrep(slices, ' ', '');

        inputs{1, crun} = cellstr(slices);

        % Add number of slices per session
        inputs{2, crun} = tmp.ImageSize(3);
        
        % Add TA, assumes TR of 2
        inputs{3, crun} = 2 - (2 / tmp.ImageSize(3));
        
        % Add slice order
        inputs{4, crun} = [1:2:tmp.ImageSize(3) 2:2:tmp.ImageSize(3)];

        % Add structural scan for coregistration
        structural = [sbjDir '/' sbjName '_struct.nii'];
        
        % Check structural exists
        if ~isfile(structural)
            warning([sbjName ' is missing structural file, skipping.']);
            toRemove = [toRemove crun]; 
            continue
        end
        inputs{5, crun} = cellstr(structural);

    catch
        warning(['Subject ' sbjName ' skipped']);
        toRemove = [toRemove crun]; 
    end
end

% Remove runs that failed to acquire inputs
inputs(:, [toRemove{:}]) = [];
jobs(:, [toRemove{:}]) = [];

% Run batch
spm('defaults', 'FMRI');
spm_jobman('run', jobs, inputs{:});

% Print skipped subjects
fprintf('Subjects skipped\n');
fprintf('%s\n', sbjs([toRemove{:}], :).name);