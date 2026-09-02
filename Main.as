// Prime Map Launcher — Openplanet plugin for Trackmania (2020)
//
// Enter the starting Track ID, which represents a map to load using Load Current Map
// Or as the last map id you played and use Load Next Prime Map to find the next prime number greater than the starting point.
// Prime Map Launcher will scan prime number and find the next valid prime number map and launch it.
// If a mapID does not exists it will alert you and continue to the next prime number until it finds a valid map.
// After successfully finding a valid map it will update the Current Map ID

[Setting hidden]
int Setting_StartId = 1;

bool searching = false;
string statusText = "";
bool showWindow = true;

const string PluginIcon = Icons::Dodecahedron;
const string MenuTitle = "\\$fe0" + PluginIcon + "\\$z " + Meta::ExecutingPlugin().Name;


void RenderMenu() {
    if (UI::MenuItem(MenuTitle, "", showWindow)) {
        showWindow = !showWindow;
    }
}

void Render() {
    if (!UI::IsOverlayShown() || !showWindow) {
        return; 
    }
    UI::SetNextWindowSize(400, 350, UI::Cond::FirstUseEver);
    if (UI::Begin(MenuTitle, showWindow)) {
        UI::Text("Current/Starting Map ID");
        Setting_StartId = UI::InputInt("##startid", Setting_StartId);
        if (Setting_StartId < 1) Setting_StartId = 1;

        UI::Dummy(vec2(0, 4));
        UI::TextWrapped("Enter a Map ID to Load or Map ID to use as a starting point for Prime Number Map Search.  " + 
        "The plugin will search for the next prime number greater than the starting point and attempt to load it.");

        UI::Dummy(vec2(0, 8));
        UI::Separator();
        UI::Dummy(vec2(0, 4));

        // Launch Current Map Button
        if (UI::Button("Load Current Map")) {
            startnew(LaunchCurrentMap);
        }

        // Launch Next Prime Map Button
        if (UI::Button("Load Next Prime Map")) {
            startnew(FindNextPrimeAndLaunchMap);
        }

        if (searching) {
            UI::Text("Searching...");
            UI::SameLine();
            // cancel button
                if (UI::Button("Cancel Search...")) {
                    searching = false;
                }
            UI::Dummy(vec2(0, 4));
            UI::TextWrapped(statusText);
        } else if (statusText.Length > 0) {
            UI::Dummy(vec2(0, 4));
            UI::TextWrapped(statusText);
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
    while (!IsPrime(candidate)) {
        candidate++;
    }
    return candidate;
}

// ---------- main search+launch coroutine ----------

const int MAX_CONSECUTIVE_FAILURES = 15;

void LaunchCurrentMap() {
    LaunchMap(Setting_StartId);
}

void FindNextPrimeAndLaunchMap() {
    searching = true;
    int newMapId = Setting_StartId;
    int failCount = 0;

    while (failCount < MAX_CONSECUTIVE_FAILURES && searching == true) {
        newMapId = NextPrime(newMapId);
        // Save the new map ID as the new starting point so if we reach max fails or user cancels they can continue without a manual update of mapID
        Setting_StartId = newMapId;

        statusText = "Checking TMX id " + newMapId + "...";
        print("PrimeMapFinder: checking TMX id " + newMapId);

        // Check TMX for valid mapID
        string infoUrl = "https://trackmania.exchange/api/maps/get_map_info/id/" + newMapId;
        Net::HttpRequest@ infoReq = Net::HttpGet(infoUrl);
        while (!infoReq.Finished()) {
            yield(300);
        }

        int code = infoReq.ResponseCode();
        string body = infoReq.String();

        if (code == 200) {
            Json::Value@ info = Json::Parse(body);

            // check the return for valid json with a TrackID
            if (info !is null && info.GetType() == Json::Type::Object && info.HasKey("TrackID")) {
                failCount = 0;
                bool launched = LaunchMap(newMapId);
                if (launched) {
                    // Save launched candidate as new starting point
                    Setting_StartId = newMapId;
                    statusText = "Launched map " + newMapId;
                    NotifyMessage(statusText);
                    searching = false;
                    return;
                } else {
                    failCount++;
                    statusText = "MapID " + newMapId + " found but launch failed.";
                    NotifyError(statusText);
                }
            } else {
                failCount++;
                statusText = "No map with TMX id " + newMapId + ".";
                NotifyError(statusText);
            }
        } else if (code == 404) {
            failCount++;
            statusText = "No map with TMX id " + newMapId + ".";
            NotifyError(statusText);
        } else {
            // any other error code, treat as a request failure and cancel the search
            failCount=-1;
            searching = false;
            statusText = "TMX HTTP request failed with code (" + code + ") for id " + newMapId + ".\nCancelling Search.";
            NotifyError(statusText);
        }
        yield(100);
    }
    if (failCount >= MAX_CONSECUTIVE_FAILURES) {
        statusText = "Search cancelled after " + MAX_CONSECUTIVE_FAILURES + " consecutive failures to find valid Map ID.";
    } else if (failCount == -1) {
        statusText = "Search cancelled due to HTTP request failure.";
    } else if (!searching) {
        statusText = "Search cancelled by user.";
    } 
    NotifyError(statusText);
    searching = false;
}


bool LaunchMap(int mapId) {
    statusText = "Launching mapId " + mapId + "...";
    // NotifyMessage("Launching mapId " + mapId + "...");
    string url;
    url = "https://trackmania.exchange/maps/download/" + mapId;

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
    return true;
}

// Notification helpers  
void NotifyMessage
(const string &in msg) {
    print(msg);
    UI::ShowNotification(MenuTitle, msg, vec4(.3, .9, .1, .3), 5000);
}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(MenuTitle + ": Error", msg, vec4(.9, .3, .1, .3), 5000);
}