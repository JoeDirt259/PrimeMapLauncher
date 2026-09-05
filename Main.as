// Prime Map Launcher — Openplanet plugin for Trackmania (2020)
//
// Enter the starting Track ID, which represents a map to load using Load Current Map
// Or as the last map id you played and use Load Next Prime Map to find the next prime number greater than the starting point.
// Prime Map Launcher will scan prime number and find the next valid prime number map and launch it.
// If a mapID does not exists it will alert you and continue to the next prime number until it finds a valid map.
// After successfully finding a valid map it will update the Current Map ID

// Testing Notes:
// mapID 3163 does not exist, if we need testing for a non exiting map


const bool HAS_PERMISSIONS = Permissions::PlayLocalMap();

[Setting hidden]
uint Setting_StartId = 1;

bool searching = false;
string statusText = "";
bool showWindow = true;
string lastCheckedOnlineMapId = "";

const string PluginIcon = Icons::Dodecahedron;
const string MenuTitle = "\\$fe0" + PluginIcon + "\\$z " + Meta::ExecutingPlugin().Name;


// Feature Ideas for the Future
//
//TODO: possibly, add Main() and check HAS_PERMISSIONS there, and notify with error if no permissions and just unload the plugin at that point.
/*
Other Possible Ideas:
    -Log Played and Missing Maps to a Log Window, so user can get a report of Map Success at end of day
        -Possible make log text a setting string, so if there is a game crash, the lgo is not lost

*/
void RenderMenu() {
    if (UI::MenuItem(MenuTitle, "", showWindow)) {
        showWindow = !showWindow;
    }
}

void Render() {
    if (!UI::IsOverlayShown() || !showWindow) {
        return; 
    }

    UI::SetNextWindowSize(550, 350, UI::Cond::FirstUseEver);
    if (UI::Begin(MenuTitle, showWindow)) {
        if (!HAS_PERMISSIONS) { 
            UI::Text("Club Access is required for this plugin.");
        }
        else {
            UI::TextWrapped("Enter a Map ID to Load or Map ID to use as a starting point for Prime Number Map Search.  " + 
                "The plugin will search for the next prime number greater than the starting point and attempt to load it.\n" + 
                "Will load directly from Nadeo if possible, otherwise will load from TMX");
            UI::Dummy(vec2(0, 8));
            UI::Text("Current/Starting Map ID");
            Setting_StartId = UI::InputUint("##startid", Setting_StartId);
            Setting_StartId = Math::Clamp(Setting_StartId, 1, 999999);
            UI::Dummy(vec2(0, 4));
            UI::Separator();
            UI::Dummy(vec2(0, 4));
            // Launch Current Map Button, check for TMX existence first, if it does not exist alert the user and do not attempt to launch the map
            if (UI::Button("Load Current Map")) {
            startnew(LaunchCurrentMapCheckExistenceFirst);
            }
            UI::SameLine();
            UI::Text("Load Map With TMX Existence Check");
            // Launch Current Map Button, bypass TMX check for existence, just attempt to launch the map
            if (UI::Button("Load Current Map/Bypass TMX Check")) {
                startnew(LaunchCurrentMap);
            }
            UI::SameLine();
            UI::Text("Kicks to Main Menu if map does not exist.");
            // Launch Next Prime Map Button
            if (UI::Button("Load Next Prime Map")) {
                startnew(FindNextPrimeAndLaunchMap);
            }
            UI::SameLine();
            UI::Text("Launch next Existing Prime Map");
            if (searching) {
                UI::Text("Searching...");
                UI::SameLine();
                // cancel button
                    if (UI::Button("Cancel Search...")) {
                        searching = false;
                        statusText = "Cancelling request...";
                    }
                UI::Dummy(vec2(0, 4));
                UI::TextWrapped(statusText);
            } else if (statusText.Length > 0) {
                UI::Dummy(vec2(0, 4));
                UI::TextWrapped(statusText);
            }
        }
    }
    UI::End();
}

// ---------- prime helpers ----------

bool IsPrime(int n) {
    if (n < 2) return false;
    if (n < 4) return true;
    if (n % 2 == 0) return false;
    for (int i = 3; i * i <= n; i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

int NextPrime(int afterThis) {
    int candidate = afterThis + 1;
    if (candidate != 2 && candidate % 2 == 0) {
        candidate++;
    }
    while (!IsPrime(candidate)) {
        candidate += 2;
    }
    return candidate;
}

// ---------- main search+launch coroutine ----------

const int MAX_CONSECUTIVE_FAILURES = 15;

void LaunchCurrentMap() {
    // Attempt to launch the map for the current map ID without checking if it exists first
    LaunchMap(Setting_StartId);
}

void LaunchCurrentMapCheckExistenceFirst() {
    // Check if map exists for the current map ID before attempting to launch it
    // Have to Set searching to true so that the DoesMapExistForMapId function can check if the user has cancelled the search
    searching = true;
    int result = DoesMapExistForMapId(Setting_StartId);
    searching = false;
    if (result == 1) {
        LaunchMapFromIdOrNadeoServer(Setting_StartId, lastCheckedOnlineMapId);
        return;
    }
    else if (result == 0) {
        statusText = "No map with TMX id " + Setting_StartId + ".";
    }
    else if (result == -1) {
        statusText = "TMX HTTP request cancelled by user.";
    }
    else if (result == -2) {
        statusText = "TMX HTTP request timeout.";
    }
    NotifyError(statusText);
}

void FindNextPrimeAndLaunchMap() {
    searching = true;
    int newMapId = Setting_StartId;
    int failCount = 0;

    while (failCount < MAX_CONSECUTIVE_FAILURES && searching == true) {
        newMapId = NextPrime(newMapId);
        // Save the new map ID as the new starting point so if we reach max fails or user cancels they can continue without a manual update of mapID
        Setting_StartId = newMapId;

        // check if map exists with retry and timeout
        int doesMapExist = DoesMapExistForMapId(newMapId);
        if (doesMapExist == 1) {
            failCount = 0;
            LaunchMapFromIdOrNadeoServer(newMapId, lastCheckedOnlineMapId);
            // Save launched candidate as new starting point
            Setting_StartId = newMapId;
            searching = false;
            return;
        } else if (doesMapExist == 0) {
            failCount++;
            statusText = "No map with TMX id " + newMapId + ".";
            NotifyError(statusText);
        } else if (doesMapExist == -1) {
            // user cancelled the search
            failCount=-1;
            searching = false;
            statusText = "TMX HTTP request cancelled by user\nCancelling Search.";
            NotifyError(statusText);
        } else if (doesMapExist == -2) {
           // request timeout and cancel the search
            searching = false;
            statusText = "TMX HTTP request timeout or error\nCancelling Search.";
             NotifyError(statusText);
        }
        yield(100);
    }
    if (failCount >= MAX_CONSECUTIVE_FAILURES) {
        statusText = "Search cancelled after " + MAX_CONSECUTIVE_FAILURES + " consecutive failures to find valid Map ID.";
    } else if (failCount == -1) {
        statusText = "Search cancelled by user.";
    } else if (!searching) {
        statusText = "Search cancelled due to HTTP request failure.";

    } 
    NotifyError(statusText);
    searching = false;
}

void LaunchMapFromIdOrNadeoServer(int mapId, string onlineMapId) {
    if (onlineMapId.Length > 0) {
        LaunchMapFromOnlineId(mapId, onlineMapId);
    } else {
        LaunchMap(mapId);
    }
}

bool LaunchMapFromOnlineId(int mapId, string onlineMapId) {
    // statusText = "Attempting to launch mapId: " + mapId + " from Nadeo Server OnlineMapId: " + onlineMapId;
    statusText = "Attempting to launch mapId: " + mapId + " from Nadeo Server";
    yield(); // yield and allow display updates
    string url;

    // "https://core.trackmania.nadeo.live/maps/" + map.OnlineMapId + "/file" to app.ManiaTitleControlScriptAPI.PlayMap
    url = "https://core.trackmania.nadeo.live/maps/" + onlineMapId + "/file";  // Nadeo Server OnlineMapId URL
    if (!Permissions::PlayLocalMap()) {
        statusText = "Cannot Load Map.  Club access required";  
        NotifyError(statusText);
        return false;
    }
    // change the menu page to avoid main menu bug where 3d scene not redrawn correctly (which can lead to a script error and `recovery restart...`)
    auto app = cast<CGameManiaPlanet>(GetApp());
    app.BackToMainMenu();
    while (!app.ManiaTitleControlScriptAPI.IsReady) yield(100);
    while (app.Switcher.ModuleStack.Length < 1 || cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) yield(100);
    UI::HideOverlay();
    app.ManiaTitleControlScriptAPI.PlayMap(url,"","");
    statusText = "Launched mapId: " + mapId + " from Nadeo Server";
    NotifyMessage(statusText);
    return true;
}

void LaunchMap(int mapId) {
    statusText = "Attempting to launch mapId " + mapId + " from TMX Server";
    yield(); // yield and allow display updates
    string url;

    url = "https://trackmania.exchange//mapgbx/" + mapId; // v2 api
    // Moved to const bool HAS_PERMISSIONS and Render() to enable plugin or alert user they need club access, so does not seem necessary here any more. 
    // if (!Permissions::PlayLocalMap()) {
    //     statusText = "Cannot Load Map.  Club access required";  
    //     NotifyError(statusText);
    //     return false;
    // }
    // change the menu page to avoid main menu bug where 3d scene not redrawn correctly (which can lead to a script error and `recovery restart...`)
    auto app = cast<CGameManiaPlanet>(GetApp());
    app.BackToMainMenu();
    while (!app.ManiaTitleControlScriptAPI.IsReady) yield(100);
    while (app.Switcher.ModuleStack.Length < 1 || cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) yield(100);
    UI::HideOverlay();
    app.ManiaTitleControlScriptAPI.PlayMap(url,"","");
    statusText = "Launched mapId: " + mapId + " from TMX Server";
    NotifyMessage(statusText);
}

// Notification helpers  
void NotifyMessage
(const string &in msg) {
    print(msg);
    UI::ShowNotification(MenuTitle, msg, vec4(.3, .9, .1, .3), 5000);
    yield(); // yield and allow display updates

}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(MenuTitle + ": Error", msg, vec4(.9, .3, .1, .3), 5000);
    yield(); // yield and allow display updates

}



int DoesMapExistForMapId(int mapId) {
// Returns 1 if map exists, 0 if map does not exist, -1 user canceled the search, -2 if request failed/timed out
// assumes seardching is true before calling TmxMapInfoRequestWithRetry so that the request can check if the user has cancelled the search
// we should clean this global searching var stuff up at some point.. but it works for now.. haha,.. this is what shitty code looks like when you're learning a new language and API
// will also set the global LastCheckedOnlineMapId to the OnlineMapId if it exists, otherwise it will be set to an empty string

    statusText = "Checking TMX for mapId " + mapId;
    lastCheckedOnlineMapId = ""; // reset the last checked online map id before making the request
    yield(); // yield and allow display updates
    string mapUrl = "https://trackmania.exchange/api/maps?id=" + mapId + "&fields=MapId%2COnlineMapId";  // new api
    Net::HttpRequest@ mapReq = TmxMapInfoRequestWithRetry(mapUrl);
    yield();  // yield for display updates, even though TMXMapInfoRequestWithRetry will yield internally, we are just adding this to be safe
    if (mapReq !is null) {
        int code = mapReq.ResponseCode();
        if (code == 200) {
            // check the return json for valid json with a MapId
            Json::Value@ info = mapReq.Json();
            if (info !is null && info.GetType() == Json::Type::Object && ResultsHaveMapId(info)) { 
                statusText = "TMX Found MapId:" + mapId;
                if (lastCheckedOnlineMapId.Length > 0) {
                    statusText += " OnlineMapId:" + lastCheckedOnlineMapId;
                }
                yield();
                return 1;
            }
            else {
                return 0; // map does not exist
            }
        }
        else if (code == 404) {
            statusText = "No map with TMX id " + mapId + ".";
            NotifyError(statusText);
        } else {
            // any other error code, treat as a request failure and cancel the search
            searching = false;
            statusText = "TMX HTTP request failed with code (" + code + ") for id " + mapId + ".\nCancelling Search.";
            NotifyError(statusText);
            return -2; // request failed
        }
    }
    // reqeuest was null or failed, check if user cancelled the search or if it was a timeout
    if (searching) {
        searching = false;
        return -2; // request timed out
    }
    // if we get here it means the request cancelled by user
    return -1;
}

bool ResultsHaveMapId(Json::Value@ theJson) {   
    // Look for MapId in results.. will only exist if the map exists.
    // we could go further and verify that the MapId matches the requested mapId, but for now we will just check if it exists in the results, as that seems redundant
    // sets global lastCheckedOnlineMapId to the OnlineMapId if it exists, otherwise it will be set to an empty string

    // verify "Results" exists in json and is an array
    if (theJson.HasKey("Results") && theJson["Results"].GetType() == Json::Type::Array) {
        Json::Value@ resultsArray = theJson["Results"];
        // Verify that the array has at least one object
        if (resultsArray.Length > 0) {
            Json::Value@ firstResult = resultsArray[0];
            // Check for MapId
            if (firstResult.HasKey("MapId")) {
                lastCheckedOnlineMapId = ResultsHaveOnlineMapId(theJson);
                return true;
            }
        } 
    } 
    return false;
}

string ResultsHaveOnlineMapId(Json::Value@ theJson)
    {   
    // Look for OnlineMapId in results
    // Returns the OnlineMapId if it exists, otherwise returns null

    // verify "Results" exists in json and is an array
    if (theJson.HasKey("Results") && theJson["Results"].GetType() == Json::Type::Array) {
        Json::Value@ resultsArray = theJson["Results"];
        // Verify that the array has at least one object
        if (resultsArray.Length > 0) {
            Json::Value@ firstResult = resultsArray[0];
            // Check for MapId
            if (firstResult.HasKey("OnlineMapId")) {
                return firstResult["OnlineMapId"];
            }
        } 
    } 
    return "";
}



Net::HttpRequest@ TmxMapInfoRequestWithRetry(const string &in url, uint maxAttempts = 3, uint64 timeoutMs = 2000) {
    // Returns the finished request on success, or null if all attempts failed/timed out.
    // If null is returned, the caller can check the global searching variable to determine if the user cancelled the search or if it was a timeout.
    // global searching variable is set to false if the user cancels the search, left at true if the request timed out.
    
    for (uint attempt = 0; attempt < maxAttempts; attempt++) {
        Net::HttpRequest@ req = Net::HttpGet(url);
        uint64 start = Time::Now;
        bool timedOut = false;
        yield(150); // give the request some time
        bool simulateTimeout = false; // set to true to simulate a timeout for testing
        while ((!req.Finished() && searching) || simulateTimeout) {
            if (Time::Now - start > timeoutMs) {
                req.Cancel();
                timedOut = true;
                break;
            }
            yield(150);
        }
        if (!searching) {
            statusText = "TMX request cancelled by user for URL: " + url;
            NotifyError(statusText);
            return null; // user cancelled the search
        }
        if (!timedOut && req.ResponseCode() == 200) {
            return req; // success
        }
        if (attempt < maxAttempts - 1) {
            statusText = "TMX request attempt " + (attempt + 1) + " failed for URL: " + url + "\nretrying...";
            NotifyError(statusText);
        }
    }
    // leave searching true so we we can decide if this was user cancelled or a timeout, but we will return null to indicate failure
    statusText = "TMX request failed after " + maxAttempts + " attempts for URL: " + url;
    NotifyError(statusText);
    return null; // timed out on all attempts return null
}