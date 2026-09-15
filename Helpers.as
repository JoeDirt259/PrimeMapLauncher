// Parsers
//

// Parse SearchMap API Response into sorted array of MapIds, sorted by ascending MapId
array<int> buildArrayOfSortedMapIdsFromJsonArray(Json::Value@ theArray) {
    array<int> arrayOfMapIds;
        if (theArray.Length>0) {
        for (int i = theArray.Length - 1; i >= 0; i--){
            Json::Value@ itemJson = theArray[i];
            if (itemJson.HasKey("MapId") && itemJson["MapId"].GetType() == Json::Type::Number) {
                Json::Value@ mapId = itemJson["MapId"];
                int loopingMapId = mapId;
                arrayOfMapIds.InsertLast(loopingMapId);
            }
        }
        arrayOfMapIds.SortAsc();
    }
    return arrayOfMapIds;
}

//
// Notification helpers  
//

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

//
// ---------- prime helpers ----------
//

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