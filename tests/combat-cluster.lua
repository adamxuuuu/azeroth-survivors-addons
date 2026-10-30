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
function GetSpellTexture(slot, book) assert(book == "spell"); return ({"fire-icon", "cleave-icon"})[slot]; end
SlashCmdList = {};
dofile('addons/CombatCluster/CombatCluster.lua');
local panel, driver = frames[1], frames[2];
local function tick(n)
    for i = 1, n or 1 do
        time = time + 0.2; arg1 = 0.2; driver.scripts.OnUpdate();
    end
end
local function amount(i) return panel.strings[i].text; end

tick(); assert(cvar == '1' and not panel.shown);
phase = 'playing'; meter = {{name='Fireball',dmg=100}};
tick(); assert(cvar == '0' and not panel.shown); -- late installation seeds historical totals
meter[1].dmg = 120; tick(); meter[1].dmg = 150; tick(); tick(2);
assert(panel.shown and amount(1) == '50');
assert(panel.textures[1].texture == "fire-icon" and panel.textures[1].shown);
assert(panel.textures[1].width == 18 and panel.textures[1].height == 18);
assert(panel.textures[1].anchor[2] == panel);
assert(panel.strings[1].anchor[4] == 24); -- font size + 6px gap
assert(panel.anchor[4] == -200); -- 20 percent inset
assert(table.getn(panel.strings) == 8); -- numbers only, no source labels or heading
assert(not panel.textures[2].shown);
local fireColor = panel.strings[1].color;
tick(11); assert(not panel.shown); -- unchanged snapshots never count twice
meter = {{name='Fireball',dmg=200}, {name='Cleave',dmg=1500}}; tick(4);
assert(amount(1) == '1.5K');
assert(panel.textures[1].texture == "cleave-icon" and panel.textures[2].texture == "fire-icon");
local movedColor = panel.strings[2].color;
for i=1,3 do assert(fireColor[i] == movedColor[i]); end
meter = {{name='Cleave',dmg=1500}}; tick(4);
meter = {{name='Fireball',dmg=200}, {name='Cleave',dmg=1500}}; tick(12);
assert(not panel.shown); -- temporarily missing rows must not replay historical damage
phase='paused'; tick(); assert(not panel.shown and cvar == '0');
phase='dead'; tick(); assert(cvar == '1');
phase='playing'; meter={}; tick();
for i=1,10 do meter[i]={name='Source'..i,dmg=i*100}; end
tick(4); assert(amount(1)=='1.0K' and amount(8)=='600');
assert(panel.textures[8].texture == "Interface\\Icons\\INV_Misc_QuestionMark");
-- Missing icon APIs must not break damage display.
GetSpellTexture = nil; meter[10].dmg = 2000; tick(4);
assert(panel.textures[1].texture == "Interface\\Icons\\INV_Misc_QuestionMark");
AZS_TIMERS = {{name='Source10', icon='timer-icon'}};
meter[10].dmg = 2200; tick(4);
assert(panel.textures[1].texture == 'timer-icon'); -- works with no spellbook texture API
UIParent.width = 1500; meter[10].dmg = 2300; tick(4);
assert(panel.anchor[4] == -300); -- follows resolution changes
-- Browser-style empty spellbook: resolve localized damage source via action tooltip.
GetNumSpellTabs = function() return 0; end;
function GetActionTexture(slot) return slot == 1 and 'arcane-action-icon' or nil; end
meter = {{name='奥术飞弹',dmg=500}}; tick(4);
assert(panel.textures[1].texture == 'arcane-action-icon');
-- Another run is detected even if no terminal phase was sampled.
time=-1; tick(); assert(not panel.shown);
tick(4); assert(not panel.shown);
SlashCmdList.COMBATCLUSTER('off'); assert(cvar=='1' and not panel.shown);
tick(4); assert(cvar=='1');
SlashCmdList.COMBATCLUSTER('on'); tick(); assert(cvar=='0');
driver.scripts.OnEvent(); assert(cvar=='1');
-- Preserve a player who already disabled stock numbers.
cvar='0'; tick(); driver.scripts.OnEvent(); assert(cvar=='0');
AZS_GetMeter=nil; tick(2); assert(warnings==3 and cvar=='0');
print('CombatCluster: all checks passed');
