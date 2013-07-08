function debug_processed(keyevt, processed)
    % read in current frame variable in other workspace
    fts = evalin('base','frameToShow');
    
    if strcmp(keyevt, 'rightarrow') == 1
        fts = fts + 1;
    elseif strcmp(keyevt, 'leftarrow') == 1
        fts = fts - 1;
    end
    
    % check boundaries
    if fts <= 1 || fts > size(processed, 3)
        return;
    end
    
    imshow(processed(:,:,fts), 'Border', 'tight');
    
    % assign new value to variable in other workspace
    assignin('base', 'frameToShow', fts);
    
    return;
end