//Settings
[Setting category="General" name="Current/Starting MapID"]
uint Setting_StartId = 1;

[Setting category="General" name="Show In MenuBar"]
bool showInMenuBar = true;

[Setting category="General" name="Show Main Window"]
bool showWindow = true;

[Setting category="Debug" name="Show In Debug Buttons" description="You should not need these.  adds [Load with Bypass TMX Check], and [Load Using SearchMaps API] buttons to main window.  Note: Bypassing TMX Check will not support loading map types such as Royal."]
bool showDebugOptions = false;

// Globals
bool searching = false;
bool searchingMapsList = false;
string statusText = "";
string lastCheckedOnlineMapId = "";
string lastCheckedMapType = "";
uint lastMapSuccessfullyLoaded = 1;

// Global Const
const int MAX_CONSECUTIVE_FAILURES = 5;
const string PluginIcon = Icons::Dodecahedron;
const string MenuTitle = "\\$fe0" + PluginIcon + "\\$z " + Meta::ExecutingPlugin().Name;
const string MenuBarTitle = "\\$fe0" + PluginIcon + "\\$z " + "PM Launcher";

