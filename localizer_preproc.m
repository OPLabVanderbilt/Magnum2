% List of open inputs
% Slice Timing: Session - cfg_files
% Slice Timing: Number of Slices - cfg_entry
% Slice Timing: TA - cfg_entry
% Slice Timing: Slice order - cfg_entry
% Coregister: Estimate & Reslice: Reference Image - cfg_files
% Normalise: Write: Deformation Field - cfg_files
clear all; %#ok<CLALL>
clc;

% Overwrite?
overwrite = true;

% Base directory
baseDir = '/Users/miso/Documents/Experiments/Rankin/Magnum2/JasonBatch/';
% Get subject folders
sbjs = dir([baseDir 'Subjects/0*']);

% Calculate number of runs
nrun = length(sbjs); 
jobfile = {[baseDir 'localizer_preproc_job.m']};
jobs = repmat(jobfile, 1, nrun);
inputs = cell(6, nrun);
toRemove = {};

% Loop through participants
for crun = 1:nrun
    try 
        % Get directories
        sbjName = sbjs(crun).name;
        sbjDir = [baseDir 'Subjects/' sbjName '/'];
        strucFolder = 'structural/';
        
        % Change to other name if necessary
        if ~exist([sbjDir '/' strucFolder], 'dir')
            strucFolder = 'old_structural/';
        end
        
        % Check if this participant has been completed
        if exist([sbjDir '/swa' sbjName '_loc.nii'], 'file') && ~overwrite
            warning([sbjName ' is complete, not overwriting'])
            toRemove = [toRemove crun];
            continue
        end
        
        % Get localizer
        localizer = [sbjDir sbjName '_loc.nii'];
       
        % Check if localizer exists
        if ~isfile(localizer)
            warning([sbjName ' is missing localizer file, skipping.']);
            toRemove = [toRemove crun];  %#ok<*AGROW>
            continue
        end
        
        % Add structural scan for coregistration
        structural = [sbjDir strucFolder sbjName '_SS_struct.nii'];
        
        % Add skull stripped deformation file
        defMap = [sbjDir strucFolder 'y_' sbjName '_SS_struct.nii'];
        
        % Check if deformation file and sturctural file exists
        if ~isfile(defMap) || ~isfile(structural)
            warning([sbjName ' is missing a skull-stripped file, ' ...
                'looking for original files.']);
            
            % Get original deformation map instead
            defMap = [sbjDir strucFolder 'y_' sbjName '_struct.nii'];
            
            % Check if original deformation map exists
            if ~isfile(defMap)
                warning([sbjName ' is missing deformation map, skipping.']);
                toRemove = [toRemove crun];
                continue
            else % Original deformation exists, need to replace structural
                % Get original structural file
                structural = [sbjDir strucFolder sbjName '_struct.nii'];
                
                % Check if original structural file exists
                if ~isfile(structural)
                    warning([sbjName ' is missing original structural ' ...
                        'file']);
                    toRemove = [toRemove crun];
                    continue
                end
                fprintf('Using non-skull stripped files\n');
            end
        end
        
        % Get localizer run info
        tmp = niftiinfo(localizer);
        
        % Fill cell array with slices, note only 1 session is assumed
        slices = strcat(repmat({[localizer ',']}, tmp.ImageSize(4), 1), ...
            num2str([1:tmp.ImageSize(4)]')); %#ok<NBRAK>
        slices = strrep(slices, ' ', '');

        inputs{1, crun} = cellstr(slices);

        % Add number of slices per session
        inputs{2, crun} = tmp.ImageSize(3);
        
        % Add TA, assumes TR of 2
        inputs{3, crun} = 2 - (2 / tmp.ImageSize(3));
        
        % Add slice order
        inputs{4, crun} = [1:2:tmp.ImageSize(3) 2:2:tmp.ImageSize(3)];

        % Add structural file
        inputs{5, crun} = cellstr(structural);
        
        % TODO: Add Deformation field
        inputs{6, crun} = cellstr(defMap);

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
