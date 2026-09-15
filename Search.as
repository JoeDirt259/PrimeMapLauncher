// Button Actions
//

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
    lastMapSuccessfullyLoaded = Setting_StartId;

    while (failCount < MAX_CONSECUTIVE_FAILURES && searching == true) {
        newMapId = NextPrime(newMapId);
        // Save the new map ID as the new starting point so if we reach max fails or user cancels they can continue without a manual update of mapID
        // check if map exists with retry and timeout
        int doesMapExist = DoesMapExistForMapId(newMapId);
        if (doesMapExist == 1) {
            failCount = 0;
            Setting_StartId = newMapId;
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
        sleep(100);
    }
    if (failCount >= MAX_CONSECUTIVE_FAILURES) {
        searching = false;
        statusText = "Search cancelled after " + MAX_CONSECUTIVE_FAILURES + " consecutive failures to find valid Map ID.\nLaunching SearchMap API to Find Next Valid Prime Map Instead";
        NotifyError(statusText);
        yield();
        RunMapListSearch();
        return;
    } else if (failCount == -1) {
        statusText = "Search cancelled by user.";
    } else if (!searching) {
        statusText = "Search cancelled due to HTTP request failure.";
    } 
    searching = false;
    NotifyError(statusText);
}

//
// Launch Functions
//

void LaunchMapFromIdOrNadeoServer(int mapId, const string &in onlineMapId) {
    if (onlineMapId.Length > 0) {
        LaunchMapFromOnlineId(mapId, onlineMapId);
    } else {
        LaunchMap(mapId);
    }
}

bool LaunchMapFromOnlineId(int mapId, const string &in onlineMapId) {
    if (!Permissions::PlayLocalMap()) {
        statusText = "Cannot Load Map.  Club access required";  
        NotifyError(statusText);
        return false;
    }
    // statusText = "Attempting to launch mapId: " + mapId + " from Nadeo Server OnlineMapId: " + onlineMapId;
    statusText = "Attempting to launch mapId: " + mapId + " from Nadeo Server";
    yield(); // yield and allow display updates
    string url;
    // "https://core.trackmania.nadeo.live/maps/" + map.OnlineMapId + "/file" to app.ManiaTitleControlScriptAPI.PlayMap
    url = "https://core.trackmania.nadeo.live/maps/" + onlineMapId + "/file";  // Nadeo Server OnlineMapId URL
    // change the menu page to avoid main menu bug where 3d scene not redrawn correctly (which can lead to a script error and `recovery restart...`)
    auto app = cast<CGameManiaPlanet>(GetApp());
    app.BackToMainMenu();
    while (!app.ManiaTitleControlScriptAPI.IsReady) sleep(100);
    while (app.Switcher.ModuleStack.Length < 1 || cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) sleep(100);
    UI::HideOverlay();
    app.ManiaTitleControlScriptAPI.PlayMap(url,"","");
    statusText = "Launched mapId: " + mapId + " from Nadeo Server";
    NotifyMessage(statusText);
    return true;
}

void LaunchMap(int mapId) {
    if (!Permissions::PlayLocalMap()) {
        statusText = "Cannot Load Map.  Club access required";  
        NotifyError(statusText);
        return;
    }
    statusText = "Attempting to launch mapId " + mapId + " from TMX Server";
    yield(); // yield and allow display updates
    string url;

    url = "https://trackmania.exchange//mapgbx/" + mapId; // v2 api
    // change the menu page to avoid main menu bug where 3d scene not redrawn correctly (which can lead to a script error and `recovery restart...`)
    auto app = cast<CGameManiaPlanet>(GetApp());
    app.BackToMainMenu();
    while (!app.ManiaTitleControlScriptAPI.IsReady) sleep(100);
    while (app.Switcher.ModuleStack.Length < 1 || cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) sleep(100);
    UI::HideOverlay();
    app.ManiaTitleControlScriptAPI.PlayMap(url,"","");
    statusText = "Launched mapId: " + mapId + " from TMX Server";
    NotifyMessage(statusText);
}

//
// Search Functions
//

void RunMapListSearch() {
    // Uses Map Search API to search for primes.
    // We get some random results from Map Search At Times
    int nextValidPrime = Setting_StartId;
    bool done=false;
    searchingMapsList = true;
    int attempts = 0;
    int maxAttemptsBeforeCancel = 8;

   do  {
        nextValidPrime = NextExistingPrimeMapOrMapIdHigherThanOurPrimeFromSearchMapListApi(nextValidPrime);
        if (nextValidPrime<0) {
            // Error on MapList Processing - lets bump out
            // status text has already been updated by MapProcessor
            searchingMapsList = false;
        }
        else if (IsPrime(nextValidPrime)) {
            Setting_StartId = nextValidPrime;
            statusText = "Found Next Valid Prime Map At " + nextValidPrime;
            done = true;
            searchingMapsList = false;
            LaunchCurrentMapCheckExistenceFirst();
        }
        attempts++;
        if (attempts>maxAttemptsBeforeCancel) {
            statusText = "Failed To Find Next Prime after " + maxAttemptsBeforeCancel + " Additional Missing Maps.\nSomething feels wrong.\nYou can manually continue by using a Starting MapId of " + nextValidPrime;
            NotifyError(statusText);
            searchingMapsList = false;
        }
        sleep(10);
   }
   while (!done && searchingMapsList);
}

// after seeing MAX_CONSECUTIVE_FAILURES number of failure to find maps we will use this to skip large gaps of missing maps
// the Current MapId MUST EXIST or the API fails
// Takes Last Map Loaded, hopefully the last or starting map was a good map #
int NextExistingPrimeMapOrMapIdHigherThanOurPrimeFromSearchMapListApi(int currentMapId) {
    // Returns NextExistingPrimeMap Number or MapID higher(pass large missing map gaps) to use as a new starting point
    // -1 if we receceive an empyt map list
    // -2 if we the request fails or time outs

    // Outline
    // Next Prime
    // Number of Maps Between Current and Next Prime
    // Grab that many maps, and theoretically we should get a map # thats exists higher than the last might id we can use to generate a new prime # from or use if
    // it happens to be prime with this same search
    // or we get the next valid prime using this higher valid map number as our new starting point.

    //API Example
    //https://trackmania.exchange/api/maps?before=36929&count=10&fields=MapId
    int newMapId = 0;
    int nextPrimeMapId = NextPrime(currentMapId);
    int numberOfMapsToGet = nextPrimeMapId-currentMapId+10; // results sometimes include self or a few randoms that dont belong there from API.. so we add 10 to hopefully 
    searching = true; // activates cancel button and required for TmxMapInfoRequestWithRetry
    string reqUrl = "https://trackmania.exchange/api/maps?before=" + currentMapId + "&count=" + numberOfMapsToGet + "&fields=MapId";
    // statusText = "Searching for next valid mapID with url " + reqUrl;
    statusText = "Searching via Map Search API...";
    yield();
    Net::HttpRequest@ mapListReq = TmxMapInfoRequestWithRetry(reqUrl);
    if (mapListReq !is null) {
            int code = mapListReq.ResponseCode();
            if (code == 200) {
                // parse the return json for valid json with an Array of MapIds
                Json::Value@ infoJson = mapListReq.Json();
                if (infoJson !is null && infoJson.GetType() == Json::Type::Object) { 
                    if (infoJson.HasKey("Results") && infoJson["Results"].GetType() == Json::Type::Array) {
                        array<int> sortedArrayOfMapId = buildArrayOfSortedMapIdsFromJsonArray(infoJson["Results"]);
                        // Either find the prime we're looking for or find a valid mapID higher than the prime we're looking for return that as a new starting point
                        if (sortedArrayOfMapId.Length>0) {
                            for (uint i = 0 ; i < sortedArrayOfMapId.Length ; i++) {
                                int aMapId = sortedArrayOfMapId[i];
                                    if (aMapId>=nextPrimeMapId) {
                                        // Either we found our prime or we have a new starting point
                                        newMapId = aMapId;
                                        searching = false;
                                        return newMapId;
                                    }
                            }
                        }
                        else {
                            searching = false;
                            statusText = "Starting mapID must be valid or we get no results from Map List API.\nCheck Starting MapId";
                            NotifyError(statusText);
                            return -1;
                        }
                    } 
                    // Response from API does not reach expected MAPID value and thus is invalid or didnt have a Results Array, either way this should not happen unless we get unexpected results from API
                    statusText = "Unexpected API Response.  Cancelling Search.  If Error Persists, please note starting MapId and contact developer.";
                    NotifyError(statusText);
                    return -1;

                }
                else {
                    // Invalid JSON
                    searching = false;
                    statusText = "Search Map HTTP Request Received Invalid Response";
                    NotifyError(statusText);
                    return -1; 
                }

            }
            else {
                // any other request code is an error, treat as a request failure and cancel the search
                // searching = false;
                statusText = "TMX HTTP request failed with code (" + code + ") for url " + reqUrl + ".\nCancelling Search.";
                NotifyError(statusText);
                searching = false;
                return -2; // request failed
            }
    }
    // Null Request Response
    if (searching) {
        searching = false;
        statusText="User Cancelled Search.";
        NotifyError(statusText);
    }
    else {
        statusText="Invalid Response from Search Map API Server.";
        NotifyError(statusText);
    }
    return -1; 
}



int DoesMapExistForMapId(int mapId) {
// Checks TMX v2 API for existence of mapId and OnlineMapId
// Returns 1 if map exists, 0 if map does not exist, -1 user canceled the search, -2 if request failed/timed out
// assumes seardching is true before calling TmxMapInfoRequestWithRetry so that the request can check if the user has cancelled the search
// we should clean this global searching var stuff up at some point.. but it works for now.. haha,.. this is what shitty code looks like when you're learning a new language and API
// will also set the global LastCheckedOnlineMapId to the OnlineMapId if it exists, otherwise it will be set to an empty string

    statusText = "Checking TMX for mapId " + mapId;
    lastCheckedOnlineMapId = ""; // reset the last checked online map id before making the request
    yield(); // yield and allow display updates
    // Example API Call
    // https://trackmania.exchange/api/maps?id=123&fields=MapId%2COnlineMapId
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
        sleep(150); // give the request some time
        bool simulateTimeout = false; // set to true to simulate a timeout for testing
        while ((!req.Finished() && searching) || simulateTimeout) {
            if (Time::Now - start > timeoutMs) {
                req.Cancel();
                timedOut = true;
                break;
            }
            sleep(150);
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