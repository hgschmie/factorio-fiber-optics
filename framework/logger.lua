------------------------------------------------------------------------
-- Framework logger
------------------------------------------------------------------------
assert(Framework)

----------------------------------------------------------------------------------------------------

---@alias ff2.logger.logger_function fun():...
---@alias ff2.logger.print_function fun():LocalisedString

--- Logging

---@class FrameworkLogger
local FrameworkLogger = {
    PREFIX = '[unset] ',
    LOG_LEVEL = 1,
}

local LOG_LEVELS = {
    [-1] = 'INTERNAL',
    [0] = 'CRIT',
    'ERR/WARN',
    'INFO',
    'DEBUG',
}

---@param level integer
---@param name string
---@param msg string
---@param log_func ff2.logger.logger_function?
function FrameworkLogger.log(level, name, msg, log_func)
    if FrameworkLogger.LOG_LEVEL < level then return end
    log(('%s(%s) [%s] - %s'):format(FrameworkLogger.PREFIX, name, LOG_LEVELS[level], log_func and msg:format(log_func()) or msg))
end

---@type PrintSettings
local PRINT_SETTINGS = {
    sound = defines.print_sound.use_player_settings,
    skip = defines.print_skip.if_visible,
}

--- write msg to console for all member of force or all players
---@param level number
---@param msg_func ff2.logger.print_function
---@param target (LuaPlayer|LuaForce|LuaGameScript)?
function FrameworkLogger.print(level, msg_func, target)
    if FrameworkLogger.LOG_LEVEL < level then return end

    if not target then target = game end
    target.print(msg_func(), PRINT_SETTINGS)
end

---@type PrintSettings
local CONSOLE_SETTINGS = {
    sound = defines.print_sound.use_player_settings,
    skip = defines.print_skip.if_redundant,
}

--- Reply to a synchronous console command, independently of the log level.
--- rcon.print also handles server stdin; do not duplicate it with localised_print.
---@param msg_func ff2.logger.print_function
---@param target CustomCommandData
function FrameworkLogger.console(msg_func, target)
    if target.player_index then
        local player = game.get_player(target.player_index)
        if not player then return end
        player.print(msg_func(), CONSOLE_SETTINGS)
    else
        rcon.print(msg_func())
    end
end

function FrameworkLogger:updateLogLevel()
    local new_log_level = Framework.settings:get_debug_level()

    if new_log_level ~= self.LOG_LEVEL then
        self.log(-1, 'Framework', '==')
        self.log(-1, 'Framework', '== log level changed: %d -> %d (%s).', function()
            local msg = new_log_level > 0 and 'enabled' or 'disabled'
            return self.LOG_LEVEL, new_log_level, msg
        end)
        self.log(-1, 'Framework', '==')
    end

    self.LOG_LEVEL = new_log_level
end

----------------------------------------------------------------------------------------------------

---@param prefix string Default prefix for log messages
---@param default_level integer log level 0..3
return function(prefix, default_level)
    FrameworkLogger.PREFIX = '[' ..prefix .. '] '
    FrameworkLogger.LOG_LEVEL = default_level

    return FrameworkLogger
end
