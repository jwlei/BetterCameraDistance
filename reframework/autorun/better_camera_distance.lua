local GUIID = {
    [45] = true, -- Pop-up Camp Edit GUI010300
    [216] = true, -- Pop-up Camps GUI090303,
    [98] = true -- Binoculars
}

local default_config = {
    version = "3.3",
    enabled = true,
    fixed_mode = false,
    smoothing = {
        enabled = true,
        factor = 0.1 -- Higher = faster transition (0.01 to 0.5 range is good)
    },
    presets = {
        {
            camera_distance = {
                x = { field = 0.0, boss = 0.0, focus = 0.0 },
                y = { field = 0.0, boss = 0.0, focus = 0.0 },
                z = { field = 0.0, boss = 0.0, focus = 0.0 }
            },
            fov = { field = 0.0, boss = 0.0, focus = 0.0 }
        },
        {
            camera_distance = {
                x = { field = 0.0, boss = 0.0, focus = 0.0 },
                y = { field = 0.0, boss = 0.0, focus = 0.0 },
                z = { field = 0.0, boss = 0.0, focus = 0.0 }
            },
            fov = { field = 0.0, boss = 0.0, focus = 0.0 }
        },
        {
            camera_distance = {
                x = { field = 0.0, boss = 0.0, focus = 0.0 },
                y = { field = 0.0, boss = 0.0, focus = 0.0 },
                z = { field = 0.0, boss = 0.0, focus = 0.0 }
            },
            fov = { field = 0.0, boss = 0.0, focus = 0.0 }
        }
    },
    active_preset = 1,
    hotkey = {
        enabled = false,
        key = 0x22,
        ctrl = false,
        alt = false,
        shift = false
    }
}

local configPath = "BetterCameraDistance.json"
local last_key = 0
local config = nil
local original_values = nil
local ignore_fov = false
local is_binding_key = false

local key_names = {
    [0x41] = "A", [0x42] = "B", [0x43] = "C", [0x44] = "D", [0x45] = "E",
    [0x46] = "F", [0x47] = "G", [0x48] = "H", [0x49] = "I", [0x4A] = "J",
    [0x4B] = "K", [0x4C] = "L", [0x4D] = "M", [0x4E] = "N", [0x4F] = "O",
    [0x50] = "P", [0x51] = "Q", [0x52] = "R", [0x53] = "S", [0x54] = "T",
    [0x55] = "U", [0x56] = "V", [0x57] = "W", [0x58] = "X", [0x59] = "Y",
    [0x5A] = "Z", [0x30] = "0", [0x31] = "1", [0x32] = "2", [0x33] = "3",
    [0x34] = "4", [0x35] = "5", [0x36] = "6", [0x37] = "7", [0x38] = "8",
    [0x39] = "9", [0x70] = "F1", [0x71] = "F2", [0x72] = "F3", [0x73] = "F4",
    [0x74] = "F5", [0x75] = "F6", [0x76] = "F7", [0x77] = "F8", [0x78] = "F9",
    [0x79] = "F10", [0x7A] = "F11", [0x7B] = "F12", [0x2D] = "Insert", 
    [0x2E] = "Delete", [0x24] = "Home", [0x23] = "End", [0x21] = "Page Up",
    [0x22] = "Page Down", [0x25] = "Left", [0x26] = "Up", [0x27] = "Right", [0x28] = "Down"
}

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

local easing_functions = {
    -- No easing (instant change)
    function(t)
        return 1.0
    end,
    
    -- Linear easing
    function(t)
        return t
    end,
    
    -- Sine easing (ease in-out)
    function(t)
        return 0.5 * (1 - math.cos(t * math.pi))
    end,
    
    -- Quad easing (ease in-out)
    function(t)
        if t < 0.5 then
            return 2 * t * t
        else
            return 1 - (-2 * t + 2) * (-2 * t + 2) / 2
        end
    end,
    
    -- Cubic easing (ease in-out)
    function(t)
        if t < 0.5 then
            return 4 * t * t * t
        else
            return 1 - (-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2) / 2
        end
    end,
    
    -- Exponential easing (ease in-out)
    function(t)
        if t == 0 then
            return 0
        elseif t == 1 then
            return 1
        elseif t < 0.5 then
            return (2 ^ (20 * t - 10)) / 2
        else
            return (2 - (2 ^ (-20 * t + 10))) / 2
        end
    end,
}

local easing_names = {"Instant", "Linear", "Sine", "Quad", "Cubic", "Exponential"}

local function applyEasing(t)
    -- Use easing type 1 (array index 2) as default if config value is invalid
    local easing_index = (config.easing and config.easing.type) or 2
    -- Clamp to valid range (1-6)
    easing_index = math.max(1, math.min(#easing_functions, easing_index))
    
    -- For "Instant" easing (index 1), just return 1 to complete transition immediately
    if easing_index == 1 then
        return 1.0
    end
    
    -- Otherwise apply the selected easing function
    return easing_functions[easing_index](t)
end

local function getTransitionDuration()
    return (config.easing and config.easing.duration) or 0.3
end

if json ~= nil then
    local file = json.load_file(configPath)
    if file ~= nil then
        if file.version < "3.0" then
            config = deepcopy(default_config)
            json.dump_file(configPath, config)
        elseif file.version ~= default_config.version then
            config = file
            
            for key, value in pairs(default_config) do
                if config[key] == nil then
                    config[key] = deepcopy(value)
                end
            end
            
            config.version = default_config.version
            json.dump_file(configPath, config)
        else
            config = file
        end
    else
        config = deepcopy(default_config)
        json.dump_file(configPath, config)
    end
    
    original_values = deepcopy(config)
else
    config = deepcopy(default_config)
    original_values = deepcopy(default_config)
end
local current_x, current_y, current_z = 0, 0, 0
local last_camera_mode = ""
local current_camera_position

sdk.hook(sdk.find_type_definition("app.mcCam_OfsDistance"):get_method("getTargetOffset()"),
function(args)
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    if config.enabled then
        local x = sdk.get_native_field(retval, sdk.find_type_definition("via.vec3"), "x")
        local y = sdk.get_native_field(retval, sdk.find_type_definition("via.vec3"), "y")
        local z = sdk.get_native_field(retval, sdk.find_type_definition("via.vec3"), "z")

        local camera_manager = sdk.get_managed_singleton("app.CameraManager")
        local player_camera = camera_manager:get_field("_MasterPlCamera")
        if player_camera == nil then
            return retval
        end
        local hunter_character = player_camera:get_field("_OwnerCharacter")
        local hunter = sdk.get_managed_singleton("app.PlayerManager"):getMasterPlayer():get_ContextHolder():get_Hunter()
        local is_aim = hunter:get_IsAim()
        local is_combat_boss = hunter_character:get_IsCombatBoss()

        local target_x, target_y, target_z

        if is_aim then
            target_x = config.presets[config.active_preset].camera_distance.x.focus
            target_y = config.presets[config.active_preset].camera_distance.y.focus
            target_z = config.presets[config.active_preset].camera_distance.z.focus
			current_camera_position = "focus"
        elseif is_combat_boss then
            target_x = config.presets[config.active_preset].camera_distance.x.boss
            target_y = config.presets[config.active_preset].camera_distance.y.boss
            target_z = config.presets[config.active_preset].camera_distance.z.boss
			current_camera_position = "boss"
        else
            target_x = config.presets[config.active_preset].camera_distance.x.field
            target_y = config.presets[config.active_preset].camera_distance.y.field
            target_z = config.presets[config.active_preset].camera_distance.z.field
			current_camera_position = "field"
        end

        -- Initialize current position on first run
        if current_x == 0 and current_y == 0 and current_z == 0 then
            current_x, current_y, current_z = x, y, z
        end
		
		-- Skip smoothing on first frame or when camera mode changes
        if last_camera_mode == "" or last_camera_mode ~= current_camera_position then
            if last_camera_mode == "" then
                -- First time - go directly to target
                current_x = target_x
				current_y = target_y
				current_z = target_z
				
            end
            -- Otherwise, we'll smooth to the new target
        end
        
        last_camera_mode = current_camera_position


	  -- Apply smoothing - move a percentage of remaining distance each frame
			if config.smoothing and config.smoothing.enabled then
				local smoothing_factor = config.smoothing.factor or 0.1
				if last_camera_mode == "boss" and current_camera_mode == "field" then
					current_x = current_x + (target_x - current_x) * smoothing_factor/100
					current_y = current_y + (target_y - current_y) * smoothing_factor/100
					current_z = current_z + (target_z - current_z) * smoothing_factor/100
				else 
					current_x = current_x + (target_x - current_x) * smoothing_factor
					current_y = current_y + (target_y - current_y) * smoothing_factor
					current_z = current_z + (target_z - current_z) * smoothing_factor
				end
			else
				-- No smoothing - instant change
				current_x = target_x
				current_y = target_y
				current_z = target_z
			end
			

        -- Set the calculated smoothed values
        sdk.set_native_field(retval, sdk.find_type_definition("via.vec3"), "x", current_x)
        sdk.set_native_field(retval, sdk.find_type_definition("via.vec3"), "y", current_y)
        sdk.set_native_field(retval, sdk.find_type_definition("via.vec3"), "z", current_z)
    end
    return retval
end
)

-- Update global variables for the smoothing system
local current_fov = 0
local target_fov = 0


-- Update the BeginRendering function for frame-based smoothing
re.on_pre_application_entry("BeginRendering",
function()
    if config.enabled then
        local camera_manager = sdk.get_managed_singleton("app.CameraManager")
        local player_camera = camera_manager:get_field("_MasterPlCamera")
        
        if player_camera == nil then
            return
        end
        local hunter_character = player_camera:get_field("_OwnerCharacter")
        local hunter = sdk.get_managed_singleton("app.PlayerManager"):getMasterPlayer():get_ContextHolder():get_Hunter()
        local is_in_tent = hunter_character:get_IsInTent()
        if is_in_tent or ignore_fov then
            return 
        end
        local is_aim = hunter:get_IsAim()
        local is_combat_boss = hunter_character:get_IsCombatBoss()
        
        local primary_camera = sdk.get_primary_camera()
        local base_fov = primary_camera:get_FOV()
        
        -- Calculate final FOV value based on mode
        local target_fov
        local current_camera_mode
        
        if is_aim then
            target_fov = config.fixed_mode and config.presets[config.active_preset].fov.focus or 
                       (base_fov + config.presets[config.active_preset].fov.focus)
            current_camera_mode = "focus"
        elseif is_combat_boss then
            target_fov = config.fixed_mode and config.presets[config.active_preset].fov.boss or 
                       (base_fov + config.presets[config.active_preset].fov.boss)
            current_camera_mode = "boss"
        else
            target_fov = config.fixed_mode and config.presets[config.active_preset].fov.field or 
                       (base_fov + config.presets[config.active_preset].fov.field)
            current_camera_mode = "field"
        end
        
        -- Initialize current_fov on first run
        if current_fov == 0 then
            current_fov = base_fov
        end
        
        -- Skip smoothing on first frame or when camera mode changes
        if last_camera_mode == "" or last_camera_mode ~= current_camera_mode then
            if last_camera_mode == "" then
                -- First time - go directly to target
                current_fov = target_fov
            end
            -- Otherwise, we'll smooth to the new target
        end
        
        last_camera_mode = current_camera_mode
		
		
        
        -- Apply smoothing - move a percentage of remaining distance each frame
        if config.smoothing and config.smoothing.enabled then
            local smoothing_factor = config.smoothing.factor or 0.1
			if last_camera_mode == "boss" and current_camera_mode == "field" then
				current_fov = current_fov + (target_fov - current_fov) * smoothing_factor/100
            else 
				current_fov = current_fov + (target_fov - current_fov) * smoothing_factor
			end
        else
            -- No smoothing - instant change
            current_fov = target_fov
        end
        
        -- Apply the current FOV
        primary_camera:set_FOV(current_fov)
    end
end)

re.on_draw_ui(function()
    if imgui.tree_node("Better Camera Distance") then
        changed, value = imgui.checkbox("Enabled", config.enabled)
        if changed then
            config.enabled = value
        end

        if config.enabled then
            changed, value = imgui.checkbox("Fixed Camera Mode", config.fixed_mode)
            if imgui.is_item_hovered() then
                imgui.set_tooltip("If enabled, the values will replace the original camera settings. If disabled, the values will be added to the original camera settings.")
            end
            if changed then
                config.fixed_mode = value
            end

            changed, config.active_preset = imgui.combo("Active Preset", config.active_preset, {"Preset 1", "Preset 2", "Preset 3"})
            if imgui.tree_node("Keybind Settings") then
                changed, config.hotkey.enabled = imgui.checkbox("Enable Hotkey", config.hotkey.enabled)
                if is_binding_key then
                    imgui.text("Press a key to bind (ESC to cancel)")
                    if reframework:is_key_down(0x1B) then
                        is_binding_key = false
                    else
                        for key, name in pairs(key_names) do
                            if reframework:is_key_down(key) then
                                config.hotkey.key = key
                                is_binding_key = false
                            end
                        end
                    end
                else
                    if imgui.button("Bind: Current Key: " .. key_names[config.hotkey.key]) then
                        is_binding_key = true
                    end
                end
                changed, config.hotkey.ctrl = imgui.checkbox("Ctrl", config.hotkey.ctrl)
                changed, config.hotkey.alt = imgui.checkbox("Alt", config.hotkey.alt)
                changed, config.hotkey.shift = imgui.checkbox("Shift", config.hotkey.shift)
                imgui.tree_pop()
            end
            if imgui.tree_node("X Component (Horizontal)") then
                imgui.text("Field")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.x.field = imgui.slider_float("X Value", config.presets[config.active_preset].camera_distance.x.field, -20, 20) 
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##field_x") then
                    config.presets[config.active_preset].camera_distance.x.field = original_values.presets[config.active_preset].camera_distance.x.field
                end
                imgui.same_line()
                if imgui.button("Default##field_x") then
                    config.presets[config.active_preset].camera_distance.x.field = default_config.presets[config.active_preset].camera_distance.x.field
                end
                imgui.end_group()
                
                imgui.text("Combat")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.x.boss = imgui.slider_float("X Value##combat_x", config.presets[config.active_preset].camera_distance.x.boss, -20, 20)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##combat_x") then
                    config.presets[config.active_preset].camera_distance.x.boss = original_values.presets[config.active_preset].camera_distance.x.boss
                end
                imgui.same_line()
                if imgui.button("Default##combat_x") then
                    config.presets[config.active_preset].camera_distance.x.boss = default_config.presets[config.active_preset].camera_distance.x.boss
                end
                imgui.end_group()
                
                imgui.text("Focus")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.x.focus = imgui.slider_float("X Value##focus_x", config.presets[config.active_preset].camera_distance.x.focus, -20, 20)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##focus_x") then
                    config.presets[config.active_preset].camera_distance.x.focus = original_values.presets[config.active_preset].camera_distance.x.focus
                end
                imgui.same_line()
                if imgui.button("Default##focus_x") then
                    config.presets[config.active_preset].camera_distance.x.focus = default_config.presets[config.active_preset].camera_distance.x.focus
                end
                imgui.end_group()
                
                imgui.tree_pop()
            end
            
            if imgui.tree_node("Y Component (Vertical)") then
                imgui.text("Field")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.y.field = imgui.slider_float("Y Value##field_y", config.presets[config.active_preset].camera_distance.y.field, -20, 20)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##field_y") then
                    config.presets[config.active_preset].camera_distance.y.field = original_values.presets[config.active_preset].camera_distance.y.field
                end
                imgui.same_line()
                if imgui.button("Default##field_y") then
                    config.presets[config.active_preset].camera_distance.y.field = default_config.presets[config.active_preset].camera_distance.y.field
                end
                imgui.end_group()
                
                imgui.text("Combat")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.y.boss = imgui.slider_float("Y Value##combat_y", config.presets[config.active_preset].camera_distance.y.boss, -20, 20)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##combat_y") then
                    config.presets[config.active_preset].camera_distance.y.boss = original_values.presets[config.active_preset].camera_distance.y.boss
                end
                imgui.same_line()
                if imgui.button("Default##combat_y") then
                    config.presets[config.active_preset].camera_distance.y.boss = default_config.presets[config.active_preset].camera_distance.y.boss
                end
                imgui.end_group()
                
                imgui.text("Focus")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.y.focus = imgui.slider_float("Y Value##focus_y", config.presets[config.active_preset].camera_distance.y.focus, -20, 20)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##focus_y") then
                    config.presets[config.active_preset].camera_distance.y.focus = original_values.presets[config.active_preset].camera_distance.y.focus
                end
                imgui.same_line()
                if imgui.button("Default##focus_y") then
                    config.presets[config.active_preset].camera_distance.y.focus = default_config.presets[config.active_preset].camera_distance.y.focus
                end
                imgui.end_group()
                
                imgui.tree_pop()
            end
            
            if imgui.tree_node("Z Component (Depth)") then
                imgui.text("Field")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.z.field = imgui.slider_float("Z Value##field_z", config.presets[config.active_preset].camera_distance.z.field, -40, 40)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##field_z") then
                    config.presets[config.active_preset].camera_distance.z.field = original_values.presets[config.active_preset].camera_distance.z.field
                end
                imgui.same_line()
                if imgui.button("Default##field_z") then
                    config.presets[config.active_preset].camera_distance.z.field = default_config.presets[config.active_preset].camera_distance.z.field
                end
                imgui.end_group()
                
                imgui.text("Combat")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.z.boss = imgui.slider_float("Z Value##combat_z", config.presets[config.active_preset].camera_distance.z.boss, -40, 40)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##combat_z") then
                    config.presets[config.active_preset].camera_distance.z.boss = original_values.presets[config.active_preset].camera_distance.z.boss
                end
                imgui.same_line()
                if imgui.button("Default##combat_z") then
                    config.presets[config.active_preset].camera_distance.z.boss = default_config.presets[config.active_preset].camera_distance.z.boss
                end
                imgui.end_group()
                
                imgui.text("Focus")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.z.focus = imgui.slider_float("Z Value##focus_z", config.presets[config.active_preset].camera_distance.z.focus, -40, 40)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##focus_z") then
                    config.presets[config.active_preset].camera_distance.z.focus = original_values.presets[config.active_preset].camera_distance.z.focus
                end
                imgui.same_line()
                if imgui.button("Default##focus_z") then
                    config.presets[config.active_preset].camera_distance.z.focus = default_config.presets[config.active_preset].camera_distance.z.focus
                end
                imgui.end_group()
                
                imgui.tree_pop()
            end
            
            if imgui.tree_node("FOV Settings") then
                imgui.text("Field")
                imgui.begin_group()
                changed, config.presets[config.active_preset].fov.field = imgui.slider_float("FOV Value##field_fov", config.presets[config.active_preset].fov.field, -40, 150)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##field_fov") then
                    config.presets[config.active_preset].fov.field = original_values.presets[config.active_preset].fov.field
                end
                imgui.same_line()
                if imgui.button("Default##field_fov") then
                    config.presets[config.active_preset].fov.field = default_config.presets[config.active_preset].fov.field
                end
                imgui.end_group()
                
                imgui.text("Combat")
                imgui.begin_group()
                changed, config.presets[config.active_preset].fov.boss = imgui.slider_float("FOV Value##combat_fov", config.presets[config.active_preset].fov.boss, -40, 150)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##combat_fov") then
                    config.presets[config.active_preset].fov.boss = original_values.presets[config.active_preset].fov.boss
                end
                imgui.same_line()
                if imgui.button("Default##combat_fov") then
                    config.presets[config.active_preset].fov.boss = default_config.presets[config.active_preset].fov.boss
                end
                imgui.end_group()
                
                imgui.text("Focus")
                imgui.begin_group()
                changed, config.presets[config.active_preset].fov.focus = imgui.slider_float("FOV Value##focus_fov", config.presets[config.active_preset].fov.focus, -40, 150)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##focus_fov") then
                    config.presets[config.active_preset].fov.focus = original_values.presets[config.active_preset].fov.focus
                end
                imgui.same_line()
                if imgui.button("Default##focus_fov") then
                    config.presets[config.active_preset].fov.focus = default_config.presets[config.active_preset].fov.focus
                end
                imgui.end_group()
                
                imgui.tree_pop()
            end

            if imgui.tree_node("Camera Smoothing") then
                changed, config.smoothing.enabled = imgui.checkbox("Enable Smoothing", config.smoothing.enabled)
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Enable smooth camera transitions between modes")
                end
                
                if config.smoothing.enabled then
                    changed, config.smoothing.factor = imgui.slider_float("Smoothness Factor", 
                                                    config.smoothing.factor, 0.01, 0.5)
                    if imgui.is_item_hovered() then
                        imgui.set_tooltip("Lower values = smoother but slower transitions\nHigher values = faster transitions")
                    end
                end
                
                imgui.begin_group()
                if imgui.button("Reset##smoothing") then
                    config.smoothing.enabled = original_values.smoothing.enabled
                    config.smoothing.factor = original_values.smoothing.factor
                end
                imgui.same_line()
                if imgui.button("Default##smoothing") then
                    config.smoothing.enabled = default_config.smoothing.enabled
                    config.smoothing.factor = default_config.smoothing.factor
                end
                imgui.end_group()
                
                imgui.tree_pop()
            end
        end
        
        imgui.begin_group()
        if imgui.button("Reset All Settings") then
            config = deepcopy(original_values)
        end
        imgui.same_line()
        if imgui.button("Default All Settings") then
            config = deepcopy(default_config)
        end
        imgui.end_group()

        if imgui.button("Save") then
            json.dump_file(configPath, config)
            original_values = deepcopy(config)
        end
        imgui.tree_pop()
    end
end)

sdk.hook(sdk.find_type_definition("app.OtomoCommonAction.cGrill_MiniGame"):get_method("doUpdate()"),
function(args)
    ignore_fov = true
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    return retval
end
)

sdk.hook(sdk.find_type_definition("app.CameraMainAction.cGrill"):get_method("update()"),
function(args)
    ignore_fov = true
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    return retval
end
)

sdk.hook(sdk.find_type_definition("app.PlayerCommonAction.cUseItemBonfire"):get_method("doEnter()"),
function(args)
    ignore_fov = true
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    return retval
end
)

sdk.hook(sdk.find_type_definition("app.PlayerCommonAction.cUseItemBonfire"):get_method("doExit()"),
function(args)
    ignore_fov = false
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    return retval
end
)

sdk.hook(sdk.find_type_definition("ace.GUIBase`2<app.GUIID.ID,app.GUIFunc.TYPE>"):get_method("toOpen()"),
function(args)
    local gui_base = sdk.to_managed_object(args[2])
    local id = gui_base:get_IDInt()
    if GUIID[id] then
        ignore_fov = true
    end

    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    return retval
end
)

sdk.hook(sdk.find_type_definition("ace.GUIBase`2<app.GUIID.ID,app.GUIFunc.TYPE>"):get_method("toClose()"),
function(args)
    local gui_base = sdk.to_managed_object(args[2])
    local id = gui_base:get_IDInt()
    if GUIID[id] then
        ignore_fov = false
    end
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    return retval
end
)

sdk.hook(sdk.find_type_definition("app.HunterDoll"):get_method("doAwake()"),
function(args)
    ignore_fov = true
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    return retval
end
)

sdk.hook(sdk.find_type_definition("app.HunterDoll"):get_method("doOnDestroy()"),
function(args)
    ignore_fov = false
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    return retval
end
)


re.on_frame(function()
    if config.hotkey.enabled then
        local key = reframework:is_key_down(config.hotkey.key)
        local ctrl = reframework:is_key_down(0x11) or not config.hotkey.ctrl
        local alt = reframework:is_key_down(0x12) or not config.hotkey.alt
        local shift = reframework:is_key_down(0x10) or not config.hotkey.shift
        if reframework:is_key_down(config.hotkey.key) and ctrl and shift and alt and not last_key then
            config.active_preset = (config.active_preset + 1) % 4
        end
        last_key = key
    end
end)

sdk.hook(sdk.find_type_definition("app.mcCam_OfsPitch"):get_method("setParam(System.Single, via.curve.EaseType, app.user_data.CameraAttachParam.cPitchOfsParam.cControlVec3, app.user_data.CameraAttachParam.cPitchOfsParam.cControlFloat, app.user_data.CameraAttachParam.cPitchOfsParam.cControlFloat)"),
function(args)
    local ofs_pitch = sdk.to_managed_object(args[2])
    local offset = sdk.to_float(args[3])
    local control_vec3 = sdk.to_managed_object(args[5])
    local lookup_value = control_vec3:get_field("_LookUp_Value")
    local lookdown_value = control_vec3:get_field("_LookDown_Value")
    local lookup_x = sdk.get_native_field(lookup_value, sdk.find_type_definition("via.vec3"), "x")
    local lookdown_x = sdk.get_native_field(lookdown_value, sdk.find_type_definition("via.vec3"), "x")
    local lookup_y = sdk.get_native_field(lookup_value, sdk.find_type_definition("via.vec3"), "y")
    local lookdown_y = sdk.get_native_field(lookup_value, sdk.find_type_definition("via.vec3"), "y")
    local lookup_z = sdk.get_native_field(lookup_value, sdk.find_type_definition("via.vec3"), "z")
    local lookdown_z = sdk.get_native_field(lookup_value, sdk.find_type_definition("via.vec3"), "z")
    sdk.set_native_field(lookup_value, sdk.find_type_definition("via.vec3"), "z", lookup_x + offset)
    log.debug("lookup x: " .. lookup_x .. " y: " .. lookup_y .. " z: " .. lookup_z)
    log.debug("lookdown x: " .. lookdown_x .. " y: " .. lookdown_y .. " z: " .. lookdown_z)
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    return retval
end
)