local MODE = MODE

MODE.name = "president"
MODE.PrintName = "President"

MODE.randomSpawns = true
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.ForBigMaps = false
MODE.Chance = 0.05
MODE.shouldfreeze = true
MODE.ROUND_TIME = 180

MODE.BodyguardFraction = 0.35

MODE.TaskAreaRadius = 300
MODE.TaskMovePointRadius = 200
MODE.TaskPropAreaRadius = 220
MODE.TaskMinRouteDistance = 500
MODE.TaskMinPropDistance = 1000

if SERVER then
	local flags = FCVAR_REPLICATED + FCVAR_NOTIFY + FCVAR_ARCHIVE

	local function EnsureConVar(name, default, help, min, max)
		if ConVarExists(name) then
			return GetConVar(name)
		end

		return CreateConVar(name, default, flags, help, min, max)
	end

	-- server/admin-side gameplay cvars
	EnsureConVar("hg_president_esp", "1", "Enable president ESP for bodyguards.", 0, 1)
	EnsureConVar("hg_president_tasks", "1", "Enable president task system.", 0, 1)
	EnsureConVar("hg_president_tasks_win_condition", "3", "How many tasks are needed for a task win.", 1, 10)
	EnsureConVar("hg_president_tasks_required", "0", "If 1, president must complete tasks to win. If 0, tasks are optional.", 0, 1)
	EnsureConVar("hg_president_task_staytime", "15", "How long the president must stay inside an area task.", 5, 120)
end

local function GetBoolCVar(name, default)
	local cv = GetConVar(name)
	if not cv then return default end

	return cv:GetBool()
end

local function GetIntCVar(name, default)
	local cv = GetConVar(name)
	if not cv then return default end

	return cv:GetInt()
end

function MODE.GetHaloEnabled()
	return GetBoolCVar("hg_president_esp", true)
end

function MODE.GetTasksEnabled()
	return GetBoolCVar("hg_president_tasks", true)
end

function MODE.GetTasksWinCondition()
	return math.max(GetIntCVar("hg_president_tasks_win_condition", 3), 1)
end

function MODE.GetTasksRequired()
	return GetBoolCVar("hg_president_tasks_required", false)
end

function MODE.GetTaskStayTime()
	return math.max(GetIntCVar("hg_president_task_staytime", 15), 1)
end

function MODE.GetPresident()
	local president = GetNetVar("zp_president", NULL)
	return IsValid(president) and president or NULL
end

function MODE.GetPresidentRagdoll()
	local president = MODE.GetPresident()
	if not IsValid(president) then return NULL end

	local fake = hg.GetCurrentCharacter and hg.GetCurrentCharacter(president) or president
	return IsValid(fake) and fake or president
end

function MODE.GetPresidentRenderEntities()
	local president = MODE.GetPresident()
	if not IsValid(president) then return {} end

	local out = {}
	local fake = hg.GetCurrentCharacter and hg.GetCurrentCharacter(president) or president

	if IsValid(fake) then
		out[#out + 1] = fake
	end

	if IsValid(president) and president ~= fake then
		out[#out + 1] = president
	end

	return out
end

function MODE.GetTaskInfo()
	return {
		name = GetNetVar("zp_task_name", ""),
		done = GetNetVar("zp_task_done", 0),
		need = GetNetVar("zp_task_need", 0),
		shouldend = GetNetVar("zp_task_shouldend", false)
	}
end

function MODE.IsPresident(ply)
	return IsValid(ply) and ply == MODE.GetPresident()
end

function MODE.IsBodyguard(ply)
	return IsValid(ply) and ply ~= MODE.GetPresident() and ply:Team() == 1
end

function MODE.IsCitizen(ply)
	return IsValid(ply) and ply ~= MODE.GetPresident() and ply:Team() == 0
end

function MODE.GuiltCheck(attacker, victim, add, harm, amt)
	return 1, true
end
