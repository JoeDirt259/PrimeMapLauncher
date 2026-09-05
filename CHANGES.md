Changes since last release
Followed all review recommomentaions which included:
Updated the TMX to v2 api calls
added load from Nadeo Server when possible as default load if OnlineId is returned with the MapId check.
Reworked JSON parsing for v2 API
Changed how we handle permission, lack of club access, to basically disabling the plugin with just a notice in the main window
The only optional suggestion I didn't implement was the Map Not Found Notices, as I want the user to be able to visually see and log in real time what maps are skipped, rather than looking back at logs.  If you're searchying for the next Prime Map you are not in game, you are literally just waiting for my plugin to find and load the next map for you, so I see the notices as positive feedback.
Permission::Playmap was moved to a const bool, HAS_PERMISSIONS, the checked in the render() function, and either enables the contents of the plugin window or tells them they need Club Access.
    -as the app relies on the ability to load maps, the plugin has no real function if they dont have this, so I just show them no controls, thus everything is protected.

additionally...
Added Load Map with TMX Check Bypass
Added a 2 second timeout on TMX request with automatic cancel and retry up to 3 times, then an offical time out.
Reduced HTTP yield to 150ms from 300ms.  300ms was laggy, and request was always ready in 150ms or less in my testing
Other small internal changes/optimizations


Release History Version/Date
v1.0.0 ????
