-- SERVER-ONLY SECRETS. This file is never sent to players (it isn't AddCSLuaFile'd and has the sv_ prefix).
-- Keep it out of anything you share publicly.

ZAC.Secrets = ZAC.Secrets or {}

-- Discord channel webhook for the cheat-bot logs (flags, ratings, bans, Steam checks, airstuck).
-- To change it: paste a new URL here and restart / change map. "" = no Discord posts.
ZAC.Secrets.DiscordWebhook = ""

-- Discord channel webhook for the SERVER STATUS posts (online, map changes, rounds, every 30 min). "" = off.
ZAC.Secrets.StatusWebhook = ""

-- Steam Web API key for the VAC-ban and Steam-level checks on join (sv_steam.lua).
-- Get one (free) at https://steamcommunity.com/dev/apikey while logged in on Steam, and paste it here.
-- "" = the Steam checks are off. The server console / zac_steam_apikey can also set it (see sv_steam.lua).
ZAC.Secrets.SteamAPIKey = ""
