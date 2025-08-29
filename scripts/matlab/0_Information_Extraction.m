function adultsInfoTable = Information_Extraction(filename)
% mergeEEGData Reads and merges EEG information from an Excel file.
%
%   mergedTable = mergeEEGData(filename) reads data from two sheets in the
%   specified Excel file:
%       - "adults info": Expected to have subject details and the "Bad Electrodes" column.
%       - "Adult EEG Analysis": Expected to have the "Electrodes Removed" column.
%
%   The function selects only the required columns, cleans the data by removing
%   rows with missing "Subject Number" values, merges the two tables using an 
%   inner join (only matching subjects are kept), and then for each subject, it 
%   combines the electrode removal lists (from "Electrodes Removed" and 
%   "Bad Electrodes") into a new column named "Ch_Remove". The output, mergedTable,
%   contains all the columns from the "adults info" sheet (plus "Electrodes Removed"
%   from the second sheet) and the processed "Ch_Remove" column.
%
%   Example:
%       mergedTable = mergeEEGData('yourExcelFile.xlsx');

    %% Define sheet names
    sheet1 = '071023-ON';
    

    %% Step 1: Read the first sheet ("adults info") with only the specified columns
    opts1 = detectImportOptions(filename, 'Sheet', sheet1, 'PreserveVariableNames', true);
    adultsInfoTable = readtable(filename, opts1);

    %% Step 6: Combine electrode removal lists for each subject
    nSubjects = height(adultsInfoTable);
    Ch_Remove = cell(nSubjects, 1);
    
    for i = 1:nSubjects
        % Get the electrode removal information as strings  
        beStr = adultsInfoTable.('Bad Electrodes'){i};
        
        % Process "Electrodes Removed" - split by comma and trim spaces
        if isempty(beStr) || strcmpi(strtrim(beStr), 'none')
            erList = {};
        else
            erList = strtrim(strsplit(beStr, ','));
        end
        
        
        % Combine the two lists and remove duplicates and empty entries
        combList = [erList];
        combList = combList(~cellfun(@isempty, combList));
        
        % Save the combined list for the current subject
        Ch_Remove{i} = combList;
    end
    
    %% Add the combined electrode list as a new column to the merged table
    adultsInfoTable.Ch_Remove = Ch_Remove;
end
