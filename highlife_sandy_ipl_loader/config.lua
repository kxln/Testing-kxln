--[[ IPL Loader
True = Enables MLO
False = Disables MLO

Additional Explanation:
- When you activate the MLOs, the script loads the MLO along with custom occlusions specifically designed for it.  
- When you deactivate the MLO, we add a blocker and full occlusions on the respective building(s).  

The occlusions will help you achieve a more stable game with FPS improvements.
]]

config = {                      -- This config enables or disables Mlo IPL
    ["Sandy_CarDealer"] = false,  -- Albany Car Dealer
    ["Sandy_LiquorBar"] = true, -- LiquorBar / The Rusty Tap
    ["Sandy_House"] = false,     -- All Houses Interiors
    ["Sandy_Motel"] = false,     -- Vanilla Motel
    ["Sandy_Burgershot"] = true,     -- Burgershot
}
--[[ Entityset Loader
True = Enables Props in houses
False = Disables Props in houses

This config enables or disables mapping props in houses
]]
entityset_config = {
    --[[
############# IMPORTANT #############
MLOs are currently not correctly configured to remove mapping, so please leave the value set to true. We will communicate an update soon.
]]
    ["Sandy_House"] = false, -- true or false
}