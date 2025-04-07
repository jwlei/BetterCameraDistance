local EXCLUDED_AIM = {
    [1] = true,
    [2] = true,
    [11] = true,
    [12] = true
}

local DEBUG = false

local default_config = {
    version = "3.5",
    enabled = true,
    enable_camera = true,
    enable_fov = true,
    fixed_mode = false,
    smoothing = {
        enabled = true,
        factor = 0.1
    },
    presets = {
        {
            camera_distance = {
                x = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 },
                y = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 },
                z = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 }
            },
            fov = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 }
        },
        {
            camera_distance = {
                x = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 },
                y = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 },
                z = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 }
            },
            fov = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 }
        },
        {
            camera_distance = {
                x = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 },
                y = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 },
                z = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 }
            },
            fov = { field = 0.0, boss = 0.0, focus = 0.0, slinger = 0.0 }
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
local primary_camera = nil

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

function log_debug(msg)
    if DEBUG then
        log.debug(msg)
    end
end

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

function upgrade_config(defaults, config)
    local changed = false
    
    for key, default_value in pairs(defaults) do
        if config[key] == nil then
            config[key] = deepcopy(default_value)
            changed = true
        elseif type(default_value) == 'table' then
            if type(config[key]) == 'table' then
                changed = upgrade_config(default_value, config[key]) or changed
            else
                config[key] = deepcopy(default_value)
                changed = true
            end
        end
    end
    
    return changed
end

if json ~= nil then
    local file = json.load_file(configPath)
    if file ~= nil then
        if file.version ~= default_config.version then
            config = file
            if upgrade_config(default_config, config) then
                config.version = default_config.version
                json.dump_file(configPath, config)
            end
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

local current_x, current_y, current_z = nil, nil, nil
local last_camera_mode = ""
local current_camera_position

sdk.hook(sdk.find_type_definition("app.mcCam_OfsDistance"):get_method("getTargetOffset()"),
function(args)
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function(retval)
    if config.enabled and config.enable_camera then
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
        local aim_type = hunter:get_AimType()
        local is_combat_boss = hunter_character:get_IsCombatBoss()

        local target_x, target_y, target_z
        
        if is_aim and EXCLUDED_AIM[aim_type] then
            target_x = config.presets[config.active_preset].camera_distance.x.slinger
            target_y = config.presets[config.active_preset].camera_distance.y.slinger
            target_z = config.presets[config.active_preset].camera_distance.z.slinger
			current_camera_position = "slinger"
        elseif is_aim then
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

        if current_x == nil and current_y == nil and current_z == nil then
            current_x, current_y, current_z = x, y, z
        end

        if last_camera_mode == "" then
            current_x = target_x
            current_y = target_y
            current_z = target_z
        end         
        
        last_camera_mode = current_camera_position

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
            current_x = target_x
            current_y = target_y
            current_z = target_z
        end
			
        sdk.set_native_field(retval, sdk.find_type_definition("via.vec3"), "x", current_x)
        sdk.set_native_field(retval, sdk.find_type_definition("via.vec3"), "y", current_y)
        sdk.set_native_field(retval, sdk.find_type_definition("via.vec3"), "z", current_z)
    end
    return retval
end
)

local current_fov = nil

sdk.hook(sdk.find_type_definition("ace.cCameraParam"):get_method("applyToCameraController(ace.CameraControllerBase)"),
function (args)
    if config.enabled and config.enable_fov then
        local camera_manager = sdk.get_managed_singleton("app.CameraManager")
        local player_camera = camera_manager:get_field("_MasterPlCamera")
        if player_camera == nil then
            return sdk.PreHookResult.CALL_ORIGINAL
        end
        local camera = sdk.to_managed_object(args[3])
        if camera ~= player_camera then
            current_fov = nil
            return sdk.PreHookResult.CALL_ORIGINAL
        end
        local param = sdk.to_managed_object(args[2])
        local hunter_character = player_camera:get_field("_OwnerCharacter")
        local hunter = sdk.get_managed_singleton("app.PlayerManager"):getMasterPlayer():get_ContextHolder():get_Hunter()

        local base_fov = param.FOV

        if current_fov == nil then
            current_fov = base_fov
        end

        local target_fov
        local current_camera_mode

        if ignore_fov then
            target_fov = base_fov
            current_camera_mode = "default"
        else
            local is_aim = hunter:get_IsAim()
            local aim_type = hunter:get_AimType()
            local is_combat_boss = hunter_character:get_IsCombatBoss()

            if is_aim and EXCLUDED_AIM[aim_type] then
                target_fov = config.fixed_mode and config.presets[config.active_preset].fov.slinger or 
                           (base_fov + config.presets[config.active_preset].fov.slinger)
                current_camera_mode = "slinger"
            elseif is_aim then
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
        end
        
        if last_camera_mode == "" then
            current_fov = target_fov
        end
        
        last_camera_mode = current_camera_mode
        
        if config.smoothing and config.smoothing.enabled then
            local smoothing_factor = config.smoothing.factor or 0.1
            if last_camera_mode == "boss" and current_camera_mode == "field" then
                current_fov = current_fov + (target_fov - current_fov) * smoothing_factor/100
            else 
                current_fov = current_fov + (target_fov - current_fov) * smoothing_factor
            end
        else
            current_fov = target_fov
        end
        param.FOV = current_fov  
    end
    return sdk.PreHookResult.CALL_ORIGINAL
end,
function (retval)
    return retval
end)

re.on_draw_ui(function()
    if imgui.tree_node("Better Camera Distance") then
        changed, value = imgui.checkbox("Enabled", config.enabled)
        if changed then
            config.enabled = value
        end

        if config.enabled then
            changed, value = imgui.checkbox("Enable Camera Distance", config.enable_camera)
            if changed then
                config.enable_camera = value
            end

            changed, value = imgui.checkbox("Enable FOV Control", config.enable_fov)
            if changed then
                config.enable_fov = value
            end

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

                imgui.text("Slinger")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.x.slinger = imgui.slider_float("X Value##slinger_x", config.presets[config.active_preset].camera_distance.x.slinger, -40, 40)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##slinger_x") then
                    config.presets[config.active_preset].camera_distance.x.slinger = original_values.presets[config.active_preset].camera_distance.x.slinger
                end
                imgui.same_line()
                if imgui.button("Default##slinger_x") then
                    config.presets[config.active_preset].camera_distance.x.slinger = default_config.presets[config.active_preset].camera_distance.x.slinger
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

                imgui.text("Slinger")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.y.slinger = imgui.slider_float("Y Value##slinger_y", config.presets[config.active_preset].camera_distance.y.slinger, -40, 40)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##slinger_y") then
                    config.presets[config.active_preset].camera_distance.y.slinger = original_values.presets[config.active_preset].camera_distance.y.slinger
                end
                imgui.same_line()
                if imgui.button("Default##slinger_y") then
                    config.presets[config.active_preset].camera_distance.y.slinger = default_config.presets[config.active_preset].camera_distance.y.slinger
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

                imgui.text("Slinger")
                imgui.begin_group()
                changed, config.presets[config.active_preset].camera_distance.z.slinger = imgui.slider_float("Z Value##slinger_z", config.presets[config.active_preset].camera_distance.z.slinger, -40, 40)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##slinger_z") then
                    config.presets[config.active_preset].camera_distance.z.slinger = original_values.presets[config.active_preset].camera_distance.z.slinger
                end
                imgui.same_line()
                if imgui.button("Default##slinger_z") then
                    config.presets[config.active_preset].camera_distance.z.slinger = default_config.presets[config.active_preset].camera_distance.z.slinger
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

                imgui.text("Slinger")
                imgui.begin_group()
                changed, config.presets[config.active_preset].fov.slinger = imgui.slider_float("FOV Value##slinger_fov", config.presets[config.active_preset].fov.slinger, -40, 150)
                imgui.end_group()
                
                imgui.begin_group()
                if imgui.button("Reset##slinger_fov") then
                    config.presets[config.active_preset].fov.slinger = original_values.presets[config.active_preset].fov.slinger
                end
                imgui.same_line()
                if imgui.button("Default##slinger_fov") then
                    config.presets[config.active_preset].fov.slinger = default_config.presets[config.active_preset].fov.slinger
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
