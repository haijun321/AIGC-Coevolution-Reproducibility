function [Efix,capacityError] = match_fixed_E(targetCapacity,p,mode)
%MATCH_FIXED_E Find a fixed E in [0,1] matching a target AIGC multiplier.
if ~isfinite(targetCapacity)
    error('targetCapacity must be finite.');
end
lo=0; hi=1;
mLo=aigc.aigc_multiplier(lo,p,mode);
mHi=aigc.aigc_multiplier(hi,p,mode);
if targetCapacity<=mLo
    Efix=lo;
elseif targetCapacity>=mHi
    Efix=hi;
else
    for it=1:70
        mid=(lo+hi)/2;
        mMid=aigc.aigc_multiplier(mid,p,mode);
        if mMid<targetCapacity, lo=mid; else, hi=mid; end
    end
    Efix=(lo+hi)/2;
end
capacityError=aigc.aigc_multiplier(Efix,p,mode)-targetCapacity;
end
