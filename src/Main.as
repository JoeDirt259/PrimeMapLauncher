// Prime Map Launcher — Openplanet plugin for Trackmania (2020)
//
// Enter the starting Track ID, which represents a map to load using Load Current Map
// Or as the last map id you played and use Load Next Prime Map to find the next prime number greater than the starting point.
// Prime Map Launcher will scan prime number and find the next valid prime number map and launch it.
// If a mapID does not exists it will alert you and continue to the next prime number until it finds a valid map.
// After successfully finding a valid map it will update the Current Map ID

// Testing Notes:
// mapID 3163 is a prime map that does not exist, if we need testing for a non exiting map
// mapID 5040 is last valid map till 15032 so good testing start point for large gaps
// mpaID 15137 is an interesting test as it returns its own map for some reason when it should not
// kinda seems random if the request returns its own numbe or not.. so we'll handle that by just adding some additional maps in the request
// Map Search also randomly adds, number out of sequence.


// Feature Ideas for the Future
/*
Other Possible Ideas:
    -Log Played and Missing Maps to a Log Window, so user can get a report of Map Success at end of day
        -Possible make log text a setting string, so if there is a game crash, the lgo is not lost

*/


//Main Entery Point
void Main() {
    //Attempts to Unload Plugin if user does not have Club Access
        if (!Permissions::PlayLocalMap()) {
            NotifyError("Club Access Required to use this plugin\nUnloading Plugin");
            Meta::Plugin@ self = Meta::ExecutingPlugin();
            Meta::UnloadPlugin(self);
        return;
    }
}

//Renderers

// Main Menu
void RenderMenu() {
    if (UI::MenuItem(MenuTitle, "", showWindow)) {
        showWindow = !showWindow;
    }
}


// Main Window
void Render() {
    if (!UI::IsOverlayShown() || !showWindow) {
        return; 
    }
    UI::SetNextWindowSize(550, 400, UI::Cond::FirstUseEver);
    if (UI::Begin(MenuTitle, showWindow)) {
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
        // Find Prime Via Map Search
        if (UI::Button("Load Next Prime Map(SearchMaps)")) {
        startnew(RunMapListSearch);
        }
        UI::SameLine();
        UI::Text("Find Next Prime Via SearchMap API\n(Slower, but works when there are\nlarge gap of missing maps)");

        if (searching || searchingMapsList) {
            UI::Text("Searching...");
            UI::SameLine();
            // cancel button
                if (UI::Button("Cancel Search...")) {
                    searching = false;
                    searchingMapsList = false;
                    statusText = "Cancelling request...";
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


// Top MeunBar
void RenderMenuMain() {
    if (!showInMenuBar) {
        return;
    }
    if (UI::BeginMenu(MenuBarTitle)) {
        UI::Text("Current Map ID: " + Setting_StartId);
        // UI::Text("Current Map ID:");
        // Setting_StartId = UI::InputUint("##startid", Setting_StartId);
        // Setting_StartId = Math::Clamp(Setting_StartId, 1, 999999);
        if (UI::Button("Load Next Prime Map")) {
            startnew(FindNextPrimeAndLaunchMap);
        }   
        showWindow = UI::Checkbox("Show Main Window",showWindow); 
        showInMenuBar = UI::Checkbox("Show In MenuBar",showInMenuBar); 

        UI::EndMenu();
    }
}
