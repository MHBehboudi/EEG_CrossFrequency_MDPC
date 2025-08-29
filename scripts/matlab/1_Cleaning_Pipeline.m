close all
clear all
clc
addpath('C:\eeglab2023.0')

%% Reading the Information For Pre_Processing
mergedTable = Information_Extraction('SpreadSheet_With_Participand_Information.xlsx');

Desired_Extensions = {'.dat'};
Desired_Directory = {};
Source_Folder = 'EEG_Raw_DATA';   
Files_Info = dir(fullfile(Source_Folder, ['**' filesep '*.*']));%Files_Info = dir(fullfile(Source_Folder, '**\\*.*'));
Files_Info = struct2cell(Files_Info)';
Files = cellfun(@(x) isequal(x, 0), Files_Info(:,5));
Files_Names = Files_Info(Files,1);
Desired_Index = contains(Files_Names,Desired_Extensions);
Desired_Files = Files_Names(Desired_Index,:);
Folder_Names = Files_Info(Files,2);
Folder_Names = Folder_Names(Desired_Index,:);
File_Counter = 0;
for Fi = 1: length (Desired_Files)
    Current_Dir = [Folder_Names{Fi} filesep Desired_Files{Fi}];
    File_Counter = File_Counter+1;
    Desired_Directory{File_Counter,1} = Current_Dir;
end


%% Step 3: Check EEG file availability for each subject in mergedTable
nSubjects = height(mergedTable);
EEG_Available = cell(nSubjects, 1);
N_EEG_Files = cell(nSubjects, 1);
mergedTable.N_EEG_Files = zeros(nSubjects,1);
EEG_Files = cell(nSubjects, 1);

for i = 1:nSubjects
    % Convert the subject number to a string (if not already)
    subjStr = string(mergedTable.("Subject Code")(i));
    subjStr
    % Check if any file in Desired_Files contains the subject number as a substring.
    if any(contains(Desired_Directory, subjStr))
        EEG_Available{i} = 'yes';
        N_EEG_Files{i} = sum(contains(Desired_Directory, subjStr));
        EEG_Files{i} = [Desired_Files{contains(Desired_Directory, subjStr)}];
    else
        EEG_Available{i} = 'no';
        EEG_Files{i} = 'none';
    end
end

% Add the EEG_Available column to the merged table
mergedTable.EEG_Available = EEG_Available;
% mergedTable.N_EEG_Files = N_EEG_Files;
mergedTable.EEG_Files = EEG_Files;
%% Step 4: Save the final merged table as an Excel file
outputFileName = 'SPIN_Data_Whole_Sentence_v2.xlsx';
writetable(mergedTable, outputFileName);

% (Optional) Display the first few rows of the final table for verification
disp(head(mergedTable))

clearvars -except Desired_Directory Source_Folder mergedTable outputFileName

subjectYes = string(mergedTable.("Subject Code")(strcmp(mergedTable.EEG_Available, 'yes')));

Filtered_Directory = {};  % Initialize filtered directory cell array

% Loop through each file path in Desired_Directory
for i = 1:length(Desired_Directory)
    currentFile = Desired_Directory{i};
    % Check if any subjectYes string occurs in currentFile
    if any(contains(currentFile, subjectYes))
        Filtered_Directory{end+1,1} = currentFile;
    end
end

%% Display the subject names that have EEG available and the count
yes_idx = strcmp(mergedTable.EEG_Available, 'yes');
subjectYesList = mergedTable.("Subject Code")(yes_idx);
numYes = sum(yes_idx);
%% Identify subjects with EEG available ('yes')
yes_idx = strcmp(mergedTable.EEG_Available, 'yes');
subjectYes = mergedTable.("Subject Code")(yes_idx);
numYes = sum(yes_idx);

Desired_Directory = Filtered_Directory;
clearvars -except Desired_Directory Source_Folder mergedTable outputFileName

% Specify the output file name
% outputFileName = 'Child_8_9_EEG_Data.xlsx';
count = 0;
for Fi = floor(length(Desired_Directory)/2)+1:length(Desired_Directory)
    %% Load EEG file
    eeglab;
    EEG = pop_loadcurry(Desired_Directory{Fi}, 'dataformat', 'auto', 'keystroke', 'on');
    Current_Study = erase(EEG.filename, '.dap');
    Current_Study = regexprep(Current_Study, ' +', '_');
    Output_Folder = 'Source_Folder\Pre_Processed_Whole_Sentence';
    
    %% Compute the raw event log (E_log)
    E = [EEG.event.type];
    E_log = [sum(E == 11), sum(E == 71), sum(E == 12), sum(E == 72)];
    
        %% Compute the raw event log (E_log)
    

    %% Extract subjectID from Current_Study (assumes '011017_1f_SASSI' format)
    parts = split(Current_Study, '_');
    if numel(parts) < 2
       warning('Filename %s does not have the expected format.', EEG.filename);
       continue;
    end
    subjectID = join(parts(1:2), '_');  % e.g., '011017_1f'
    subjectID = char(subjectID);         % Convert to character array
    
    %% Find the corresponding row in mergedTable
    idx = find(contains(mergedTable.("EEG_Files"), subjectID));
    if isempty(idx)
        warning('Subject ID %s not found in mergedTable.', subjectID);
        continue;
    end
    % Counter = mergedTable.N_EEG_Files{idx};
    mergedTable.N_EEG_Files(idx) = mergedTable.N_EEG_Files(idx)+1;
    Current_Variable = ['Condition_Events_', num2str(mergedTable.N_EEG_Files(idx))];
    %% Update mergedTable with the raw event log (Condition_Events)
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable)= cell(height(mergedTable), 1);
    end
    mergedTable.(Current_Variable){idx} = num2str(E_log);
    writetable(mergedTable, outputFileName);
    
    %% Retrieve subject's electrode removal list and update (combine with Channel_Remove)
    if ismember("Ch_Remove", mergedTable.Properties.VariableNames)
         subjectChRemove = mergedTable.Ch_Remove{idx};
    else
         error('The merged table does not contain the column "Ch_Remove".');
    end
    Channel_Remove = {'Trigger', 'VEO', 'HEO', 'CB1', 'CB2'};
    if isempty(subjectChRemove)
        Ch_Remove = Channel_Remove;
    else
        Ch_Remove = cat(2, Channel_Remove, subjectChRemove);
    end
    % (Ch_Remove is now ready to be used in channel rejection)
    
    %% Display current subject info (for verification)
    fprintf('Processing subject: %s\n', subjectID);
    fprintf('Raw Event Log (Condition_Events): [%s]\n', num2str(E_log));
    disp('Electrodes to Remove (Ch_Remove):');
    disp(Ch_Remove);
    
    %% -------------------- Pre-processing Steps -------------------- %%
    
    % 1. Delete time segments (if needed)
    % EEG = erplab_deleteTimeSegments(EEG, 0, 5000, 5000);
    
    Channel_Remove =  {'Trigger', 'VEO', 'HEO', 'CB1', 'CB2'}
    EEG=pop_select(EEG, 'nochannel', Channel_Remove );
    [ALLEEG EEG CURRENTSET]= pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
    [ALLEEG EEG]= eeg_store(ALLEEG, EEG, CURRENTSET);
    EEG1.chanlocs = EEG.chanlocs;

%     if count == 0
%         count = 1;
%         disp('Laplacian PRocess');
%         trodes = {};
%         for site = 1:60
%         trodes{site}=(EEG.chanlocs(site).labels);
%         end;
%         trodes=trodes';
%         M=ExtractMontage('10-5-System_Mastoids_EGI129.csd',trodes);
%         tic
%         [G,H] = GetGH(M);
%         toc
%     end

    E = [EEG.event.type];
    E_log = [sum(E == 11), sum(E == 71), sum(E == 12), sum(E == 72)];
    Current_Variable = ['After_Common_Elec_Rem_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end
    mergedTable.(Current_Variable){idx} = num2str(E_log);
    Current_Variable = ['After_Common_Elec_Rem_Ch_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember((Current_Variable), mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end
 
    mergedTable.(Current_Variable){idx} = length(EEG.chanlocs);

    writetable(mergedTable, outputFileName);

    % 2. Remove channels indicated in Ch_Remove
    if ~isempty(subjectChRemove)
        Ch_Remove = Channel_Remove;

        EEG = pop_select(EEG, 'nochannel', subjectChRemove);
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
        [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
        
        E = [EEG.event.type];
        E_log = [sum(E == 11), sum(E == 71), sum(E == 12), sum(E == 72)];
        if ~ismember("After_Elec_Rem", mergedTable.Properties.VariableNames)
             mergedTable.After_Elec_Rem = cell(height(mergedTable), 1);
        end
    
        if ~ismember("After_Elec_Rem_Ch", mergedTable.Properties.VariableNames)
             mergedTable.After_Elec_Rem_Ch = cell(height(mergedTable), 1);
        end
    
        mergedTable.After_Elec_Rem{idx} = num2str(E_log);
        mergedTable.After_Elec_Rem_Ch{idx} = length(EEG.chanlocs);
    
        writetable(mergedTable, outputFileName);
    end
    % 3. Resample the data
    Resampling_Rate = 128;
    EEG = pop_resample(EEG, Resampling_Rate);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    
    E = [EEG.event.type];
    E_log = [sum(E == 11), sum(E == 71), sum(E == 12), sum(E == 72)];
    Current_Variable = ['Resampling_Rate_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember((Current_Variable), mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end


    mergedTable.(Current_Variable){idx} = Resampling_Rate;
 
    % 4. Filter and Cleanline
    EEG = pop_eegfiltnew(EEG, 1, 50);
%     EEG = pop_cleanline(EEG, 'bandwidth', 2, 'chanlist', 1:length(EEG.chanlocs), ...
%               'computepower', 1, 'linefreqs', 60, 'newversion', 0, 'normSpectrum', 0, ...
%               'p', 0.01, 'pad', 2, 'plotfigures', 0, 'scanforlines', 1, 'sigtype', 'Channels',...
%               'taperbandwidth', 2, 'tau', 100, 'verb', 1, 'winsize', 4, 'winstep', 1);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    
    % 5. Clean raw data and interpolate bad channels
    EEG2 = EEG;
    % Capture the output of the clean_rawdata call as a string.
    % outputStr = evalc("EEG = clean_rawdata(EEG, 'off', 'off', 0.8, 'off', 20, 'off');");
%     [EEG,~,~] = clean_artifacts(EEG, 'ChannelCriterion', 0.70,'LineNoiseCriterion', 'off', 'BurstCriterion', 'off', 'WindowCriterion', 'off');
    outputStr = evalc("[EEG,~,~] = clean_artifacts(EEG, 'ChannelCriterion', '0.6', 'BurstCriterion', 20, 'BurstRejection', 'off','LineNoiseCriterion', 'off',  'WindowCriterion', 'off', 'Highpass', 'off' );");
    % Display the captured output (optional).
    disp(outputStr);
    
    % Use a regular expression to find the percentage.
    tokens = regexp(outputStr, 'Keeping ([\d\.]+)%', 'tokens');
    if ~isempty(tokens)
        keptPercentage = str2double(tokens{1}{1});
        fprintf('Kept Percentage: %.2f%%\n', keptPercentage);
    else
        warning('Could not determine kept percentage from output.');
    end

    Current_Variable = ['Clean_Percent_Keep_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end
    mergedTable.(Current_Variable){idx} = keptPercentage;
    
    writetable(mergedTable, outputFileName);

    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

    E = {EEG.event.type};
%     E_log = [sum(contains(E,  '11')), sum(contains(E,  '71')), sum(contains(E,  '12')),...
%         sum(contains(E,  '72'))];
    E_log = [sum(cellfun(@(c) isequal(c,11), E)), sum(cellfun(@(c) isequal(c,71), E)), sum(cellfun(@(c) isequal(c,12), E)), sum(cellfun(@(c) isequal(c,72), E)) ];
    Current_Variable = ['After_Clean_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end
    mergedTable.(Current_Variable){idx} = num2str(E_log);
    Current_Variable = ['After_Clean_Ch_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end 
    mergedTable.(Current_Variable){idx} = length(EEG.chanlocs);


    writetable(mergedTable, outputFileName);
    EEG = pop_interp(EEG, eeg_mergelocs(EEG1.chanlocs), 'spherical');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    

    E = {EEG.event.type};
%     E_log = [sum(contains(E,  '11')), sum(contains(E,  '71')), sum(contains(E,  '12')),...
%         sum(contains(E,  '72'))];
E_log = [sum(cellfun(@(c) isequal(c,11), E)), sum(cellfun(@(c) isequal(c,71), E)), sum(cellfun(@(c) isequal(c,12), E)), sum(cellfun(@(c) isequal(c,72), E)) ];
    Current_Variable = ['After_interp1_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end
    mergedTable.(Current_Variable){idx} = num2str(E_log);


    Current_Variable = ['After_interp1_Ch_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end      
    mergedTable.(Current_Variable){idx} = length(EEG.chanlocs);

    writetable(mergedTable, outputFileName);
    
    % 7. Run ICA and process with MARA (and record rejection info)
    EEG = pop_runica(EEG, 'extended', 1, 'interupt', 'on');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    
    [ALLEEG, EEG, CURRENTSET] = processMARA(ALLEEG, EEG, CURRENTSET);
    Margin_MARA = 10;
    Rejected_Artifact = find(EEG.reject.gcompreject(1:Margin_MARA) == 1);
    
    Current_Variable = ['Rejected_Artifact_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end
    mergedTable.Rejected_Artifact{idx} = num2str(Rejected_Artifact);
    writetable(mergedTable, outputFileName);
    
    Final_Rejected_Comp = find(EEG.reject.gcompreject(1:Margin_MARA) > 0);
    if ~ismember("Final_Rejected_Comp", mergedTable.Properties.VariableNames)
         mergedTable.Final_Rejected_Comp = cell(height(mergedTable), 1);
    end
    mergedTable.(Current_Variable){idx} = num2str(Final_Rejected_Comp);

    writetable(mergedTable, outputFileName);
    E = {EEG.event.type};
    E_log = [sum(cellfun(@(c) isequal(c,11), E)), sum(cellfun(@(c) isequal(c,71), E)), sum(cellfun(@(c) isequal(c,12), E)), sum(cellfun(@(c) isequal(c,72), E)) ];
    
    Current_Variable = ['After_artrej_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember((Current_Variable), mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end
    mergedTable.(Current_Variable){idx} = num2str(E_log);

    Current_Variable = ['After_artrej_Ch_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end   
    mergedTable.(Current_Variable){idx} = length(EEG.chanlocs);
    

    % 8. Interpolate (using channel locations from a backup, e.g., EEG1)
    EEG = pop_interp(EEG, eeg_mergelocs(EEG1.chanlocs), 'spherical');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    

    % 6. Epoch the data
    Epoching_Codes = {'11','12'};
    Epoching_min = -1.5;
    Epoching_Max = 9;
    EEG = pop_epoch(EEG, Epoching_Codes, [Epoching_min Epoching_Max], ...
          'newname', [Current_Study '_PreEpoch.set'], 'epochinfo', 'yes');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'gui', 'off');
    EEG = eeg_checkset(EEG);
    
    E = {EEG.event.type};
    E_log = [sum(cellfun(@(c) isequal(c,11), E)), sum(cellfun(@(c) isequal(c,71), E)), sum(cellfun(@(c) isequal(c,12), E)), sum(cellfun(@(c) isequal(c,72), E)) ];
    
    Current_Variable = ['After_epoch1_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end
    mergedTable.(Current_Variable){idx} = num2str(E_log);

    Current_Variable = ['After_epoch1_Ch_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end    
    mergedTable.(Current_Variable){idx} = length(EEG.chanlocs);
    
    writetable(mergedTable, outputFileName);
    
    % 9. Re-reference the data
    EEG = pop_reref(EEG, []);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    % 
   

%     for ne = 1:length(EEG.epoch)               % loop through all epochs
%         myEEG = single(EEG.data(:,:,ne));      % reduce data precision to reduce memory demand
%         MyResults = CSD(myEEG,G,H);            % compute CSD for <channels-by-samples> 2-D epoch
%         data(:,:,ne) = MyResults;              % assign data output
%     end
%     EEG.data = data;
%     clear ne myEEG data
%     % 10. (Final) Calculate counts for specific event types

    E = {EEG.event.type};
    E_log = [sum(cellfun(@(c) isequal(c,11), E)), sum(cellfun(@(c) isequal(c,71), E)), sum(cellfun(@(c) isequal(c,12), E)), sum(cellfun(@(c) isequal(c,72), E)) ];
    

    Current_Variable = ['Final_Event_Count_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end
    mergedTable.((Current_Variable)){idx} = num2str(E_log);


    Current_Variable = ['Final_Event_Count_Ch_', num2str(mergedTable.N_EEG_Files(idx))];
    if ~ismember(Current_Variable, mergedTable.Properties.VariableNames)
         mergedTable.(Current_Variable) = cell(height(mergedTable), 1);
    end

    mergedTable.(Current_Variable){idx} = length(EEG.chanlocs);

    writetable(mergedTable, outputFileName);
    
    % Save the processed EEG dataset
    EEG = pop_saveset(EEG, [Output_Folder filesep Current_Study '_PreEpoch.set']);
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    
    close all;
end
