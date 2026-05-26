local name, addon = ...

local LunaBags = addon.LunaBags
local modules = {}
local frameWorkQueue = {}
local frameWorkFrame

local function CreateBlankModule()
    return {}
end

function LunaBags:QueueFrameWork(callback)
    if type(callback) ~= "function" then
        return
    end
    if not CreateFrame then
        callback()
        return
    end
    frameWorkQueue[#frameWorkQueue + 1] = callback
    if not frameWorkFrame then
        frameWorkFrame = CreateFrame("Frame")
    end
    frameWorkFrame:SetScript("OnUpdate", function(frame)
        local nextWork = table.remove(frameWorkQueue, 1)
        if not nextWork then
            frame:SetScript("OnUpdate", nil)
            return
        end
        nextWork()
        if #frameWorkQueue == 0 then
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

function LunaBags:CreateModule(name)
    if not modules[name] then
        modules[name] = CreateBlankModule()
    end
    return modules[name]
end

function LunaBags:LoadModule(name)
    if not modules[name] then
        modules[name] = CreateBlankModule()
    end
    return modules[name]
end

function LunaBags:RegisterPlugin(plugin)
    if not plugin or type(plugin) ~= "table" or not plugin.name or plugin.name == "" then
        return nil
    end

    self.plugins = self.plugins or {}
    self.pluginsByName = self.pluginsByName or {}
    if self.pluginsByName[plugin.name] then
        return self.pluginsByName[plugin.name]
    end

    table.insert(self.plugins, plugin)
    self.pluginsByName[plugin.name] = plugin

    if addon.Plugins and addon.Plugins.Register then
        addon.Plugins:Register(plugin)
    end

    return plugin
end
