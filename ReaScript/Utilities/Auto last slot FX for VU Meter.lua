--[[
**PackageTags**
@about
  - Auto slot FX VU Meter to last position in FX chain
  - Easy to Gain Staging after add new FX
@description Auto last slot FX for VU Meter
@donation https://mtstudio.space/donate
@link
  - MT STUDIO https://mtstudio.space
  - Minh Thi https://youtube.com/@toilamotcaicayy
@version 1.00
**VersionTags**
@author Minh GPThi
@about
  - A helper script to generate sound effects using the ElevenLabs API.
  - Supports generating audio from the text box or from the notes of multiple selected items.
  - Based on the original Hosi - ElevenLabs TTS script.
@changelog
  + v1.0 (2025-09-14)
    - Initial release.
@provides
    [main] . > Auto last slot FX for VU Meter.lua
@reaper_version 7.0
@depends ReaTeam Extensions/API/reaper_imgui.ext
--]]

--[
-- VU-mover toggleable script (version C: move VU immediately on start + monitor)
-- Behavior:
-- Toggle action: turn on/off persistent state (ExtState)
-- When ON:
--     + Quét toàn bộ tracks một lần, đưa plugin VU xuống cuối chain nếu có.
--     + Sau đó monitor, mỗi lần có FX mới -> lại đưa VU xuống cuối.
-- When OFF: stop monitoring.
-- Config: đổi VU_KEYWORD nếu plugin của bạn tên khác.
--]]

-- === CONFIG ===
local VU_KEYWORD = "VU Meter" -- tên plugin VU cần tìm

-- === HELPERS ===
local function find_vu_index(track)
    local fx_count = reaper.TrackFX_GetCount(track)
    local kw = VU_KEYWORD:lower()
    for i = 0, fx_count - 1 do
        local retval, fx_name = reaper.TrackFX_GetFXName(track, i, "")
        if retval and fx_name and fx_name:lower():find(kw, 1, true) then
            return i
        end
    end
    return -1
end

local function move_vu_to_end(track, vu_index)
    local fx_count = reaper.TrackFX_GetCount(track)
    if fx_count <= 1 or vu_index == -1 or vu_index == fx_count - 1 then return end

    -- append copy of VU
    reaper.TrackFX_CopyToTrack(track, vu_index, track, fx_count, false)
    -- delete original VU
    reaper.TrackFX_Delete(track, vu_index)
end

-- === STATE & CONTEXT ===
local EXT_SECTION = "VU_MOVE_SCRIPT"
local EXT_KEY = "running"

local _, _, sectionID, cmdID = reaper.get_action_context() -- toolbar toggle

local function set_toolbar_state(state)
    reaper.SetToggleCommandState(sectionID, cmdID, state and 1 or 0)
    reaper.RefreshToolbar2(sectionID, cmdID)
end

-- fx_state map (guid -> fxcount)
local fx_state = {}
local function init_fx_state_and_cleanup()
    fx_state = {}
    local tr_count = reaper.CountTracks(0)
    for t = 0, tr_count - 1 do
        local tr = reaper.GetTrack(0, t)
        if tr then
            local guid = reaper.GetTrackGUID(tr)
            fx_state[guid] = reaper.TrackFX_GetCount(tr)

            -- cleanup ngay lập tức: đưa VU xuống cuối nếu chưa ở cuối
            local vu_index = find_vu_index(tr)
            if vu_index ~= -1 then
                move_vu_to_end(tr, vu_index)
                fx_state[guid] = reaper.TrackFX_GetCount(tr)
            end
        end
    end
end

-- Monitoring loop
local function monitor_loop()
    if reaper.GetExtState(EXT_SECTION, EXT_KEY) ~= "1" then
        set_toolbar_state(false)
        return
    end

    local tr_count = reaper.CountTracks(0)
    for t = 0, tr_count - 1 do
        local tr = reaper.GetTrack(0, t)
        if tr then
            local guid = reaper.GetTrackGUID(tr)
            local fxcount = reaper.TrackFX_GetCount(tr)
            local last_fxcount = fx_state[guid] or 0

            if fxcount > last_fxcount then
                local vu_index = find_vu_index(tr)
                if vu_index ~= -1 then
                    move_vu_to_end(tr, vu_index)
                    fxcount = reaper.TrackFX_GetCount(tr)
                end
            end

            fx_state[guid] = fxcount
        end
    end

    reaper.defer(monitor_loop)
end

-- Cleanup on exit
reaper.atexit(function()
    reaper.SetExtState(EXT_SECTION, EXT_KEY, "0", true)
    set_toolbar_state(false)
end)

-- === TOGGLE HANDLER ===
local cur = reaper.GetExtState(EXT_SECTION, EXT_KEY)
if cur == "1" then
    reaper.SetExtState(EXT_SECTION, EXT_KEY, "0", true)
    set_toolbar_state(false)
    return
else
    reaper.SetExtState(EXT_SECTION, EXT_KEY, "1", true)
    set_toolbar_state(true)
    init_fx_state_and_cleanup() -- quét + dọn ngay khi bật
    monitor_loop()
end

