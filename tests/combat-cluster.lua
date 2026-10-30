local frames = {};
local globals = {};
local function widget()
    local w = {scripts = {}, strings = {}, textures = {}};
    function w:SetWidth(v) self.width = v; end
    function w:GetWidth() return self.width; end
    function w:SetHeight(v) self.height = v; end
    function w:SetPoint(point, relative, relativePoint, x, y) self.anchor = {point, relative, relativePoint, x, y}; end
    function w:ClearAllPoints() self.anchor = nil; end
    function w:GetFont() return "test-font", 18; end
    function w:SetFont(_, size) self.fontSize = size; end
    function w:GetStringWidth() return string.len(self.text or "") * 8; end
    function w:SetTexture(path) self.texture = path; end
    function w:CreateTexture() local t = widget(); table.insert(self.textures,t); return t; end
    function w:SetFrameStrata() end
    function w:SetJustifyH() end
    function w:SetNonSpaceWrap() end
    function w:SetText(v) self.text = v; end
    function w:GetText() return self.text; end
    function w:SetOwner() end
    function w:ClearLines() end
    function w:SetAction(slot)
        globals["CombatClusterIconLookupTextLeft1"].text = slot == 1 and "奥术飞弹" or nil;
    end
    function w:SetTextColor(r,g,b) self.color = {r,g,b}; end
    function w:SetAlpha(v) self.alpha = v; end
    function w:Show() self.shown = true; end
    function w:Hide() self.shown = false; end
    function w:RegisterEvent() end
    function w:SetScript(name, f) self.scripts[name] = f; end
    function w:CreateFontString()
        local s = widget(); table.insert(self.strings, s); return s;
    end
    return w;
end
UIParent = widget(); UIParent.width = 1000;
function CreateFrame(kind, name)
    local w = widget(); table.insert(frames,w);
    if (kind == "GameTooltip") then globals[name.."TextLeft1"] = widget(); end
    return w;
end
function GetLocale() return 'enUS'; end
local warnings = 0;
function getglobal(name)
    if (name == "DEFAULT_CHAT_FRAME") then return {AddMessage = function() warnings = warnings + 1; end}; end
    return globals[name];
end
local cvar = '1';
function GetCVar() return cvar; end
function SetCVar(name,value) assert(name == 'CombatDamage'); cvar = value; end
local phase, time, meter = 'ready', 0, {};
function AZS_GetPhase() return phase; end
function AZS_GetRunTime() return time; end
function AZS_GetMeter() return meter; end
function GetNumSpellTabs() return 1; end
function GetSpellTabInfo() return "Skills", nil, 0, 2; end
function GetSpellName(slot, book) assert(book == "spell"); return ({"Fireball", "Cleave"})[slot]; end
function GetSpellTexture(slot, book) assert(book == "spell"); return ({"Interface\\Icons\\fire-icon", "Interface\\Icons\\cleave-icon"})[slot]; end
SlashCmdList = {};
dofile('addons/CombatCluster/IconData.lua');
dofile('addons/CombatCluster/CombatCluster.lua');
local panel, driver = frames[1], frames[2];
local clock = 0;
function GetTime() return clock; end
local function tick(n)
    for i = 1, n or 1 do clock = clock + 0.05; arg1 = 0.05; driver.scripts.OnUpdate(); end
end
local function hit(kind, line)
    event = kind; arg1 = line; driver.scripts.OnEvent();
end
local function damage(i) return panel.strings[i].text; end
local function fontSize(i) return panel.strings[i].fontSize; end
phase = 'playing'; tick(); assert(cvar == '0');
hit('CHAT_MSG_SPELL_SELF_DAMAGE','Your Fireball hits Kobold for 100 fire damage.');
hit('CHAT_MSG_SPELL_SELF_DAMAGE','Your Fireball crits Gnoll for 250 fire damage.');
hit('CHAT_MSG_SPELL_SELF_DAMAGE','Your Cleave hits Gnoll for 30 physical damage.');
tick(4);
assert(damage(1) == '350' and fontSize(1) == 27 and damage(2) == '30' and fontSize(2) == 18);
assert(panel.textures[1].shown and panel.textures[2].shown);
assert(panel.textures[1].anchor[5] > panel.textures[2].anchor[5]);
tick(45); assert(panel.textures[1].alpha < 1);
tick(20); assert(not panel.textures[1].shown and not panel.textures[2].shown and cvar == '0');
-- A later hit of the same spell is a new display, not a lifetime total.
hit('CHAT_MSG_SPELL_SELF_DAMAGE','Your Fireball hits Kobold for 40 fire damage.'); tick(3);
assert(damage(3) == '40' and fontSize(3) == 18);
phase = 'dead'; tick(); assert(cvar == '1' and not panel.shown);
SlashCmdList.COMBATCLUSTER('off'); assert(cvar == '1');
print('CombatCluster events and animation: all checks passed');
