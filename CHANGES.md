Changes since last release
Followed all review recommomentaions which included:
Permission:s:Playmap is now called in Main() and Displays Notification and unloads Plugin if user does not have Club Access.
Updated the TMX to v2 api calls
added load from Nadeo Server when possible as default load if OnlineId is returned with the MapId check.
Reworked JSON parsing for v2 API

additionally...
Reduced Retries to 5 and then use SearchMap API as Backup to search for Maps to fix large missing map gaps like the void from 5000ish-15000ish
Added Load Map with TMX Check Bypass 
Added a 2 second timeout on TMX request with automatic cancel and retry up to 3 times, then an offical time out.
Reduced HTTP yield to 150ms from 300ms.  300ms was laggy, and request was always ready in 150ms or less in my testing
Other small internal changes/optimizations
Added Search Map API to get map list as backup to cover large gaps.

Added Permissions::PlayLocalMap() in LaunchMap()
Changed yields to sleep where appropriate


Release History Version/Date
v1.0.0 ????
