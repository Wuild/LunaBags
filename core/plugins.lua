local _, ns = ...

local Plugins = {
    registry = {},
}

ns.Plugins = Plugins

local function EnsurePluginConfig()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end
    addon.db.profile.plugins = addon.db.profile.plugins or {}
    return addon.db.profile.plugins
end

function Plugins:Register(plugin, def)
    local id = plugin
    local object = def
    if type(plugin) == "table" then
        object = plugin
        id = plugin.id or plugin.key or plugin.name
    end
    if not id or type(object) ~= "table" then
        return
    end
    object.id = id
    self.registry[id] = object
end

function Plugins:IsEnabled(id)
    local cfg = EnsurePluginConfig()
    local def = self.registry[id]
    if not def then
        return false
    end
    if not cfg then
        return def.defaultEnabled == true
    end
    local value = cfg[id]
    if value == nil then
        return def.defaultEnabled == true
    end
    return value
end

function Plugins:Apply(button, entry, context)
    for id, plugin in pairs(self.registry) do
        if id ~= "trashIcon" then
            if plugin.Apply then
                plugin:Apply(button, entry, context, self:IsEnabled(id))
            elseif plugin.apply then
                plugin.apply(button, entry, context, self:IsEnabled(id))
            end
        end
    end

    local trashPlugin = self.registry.trashIcon
    if trashPlugin then
        if trashPlugin.Apply then
            trashPlugin:Apply(button, entry, context, self:IsEnabled("trashIcon"))
        elseif trashPlugin.apply then
            trashPlugin.apply(button, entry, context, self:IsEnabled("trashIcon"))
        end
    end
end
