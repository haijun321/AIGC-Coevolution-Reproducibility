function ensure_dir(pathName)
if ~exist(pathName,'dir'), mkdir(pathName); end
end
