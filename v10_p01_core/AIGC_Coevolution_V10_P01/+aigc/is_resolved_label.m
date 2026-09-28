function tf = is_resolved_label(label)
%IS_RESOLVED_LABEL True only for certified equilibrium or stable cycle.
label = string(label);
tf = contains(label,'equilibrium') | label=="stable_cycle";
end
