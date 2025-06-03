import SharedTypes "../shared/SharedTypes";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Request "service/Request";

persistent actor Persistence {

    // Stable Data
    private stable var usersStable : [(SharedTypes.ID, SharedTypes.User)] = [];
    private stable var fixedAmountsStable : [var SharedTypes.FixedAmounts] = [
        var { amount = 10; coin = #Point },
        { amount = 10; coin = #Token },
    ];
    private stable var userHistoryStable : [(SharedTypes.ID, [(Nat, [SharedTypes.UserHistory])])] = [];

    // Unstable Data
    private transient var users : HashMap.HashMap<SharedTypes.ID, SharedTypes.User> = HashMap.HashMap<SharedTypes.ID, SharedTypes.User>(0, Text.equal, Text.hash);
    private transient var userHistory : HashMap.HashMap<SharedTypes.ID, HashMap.HashMap<Nat, Buffer.Buffer<SharedTypes.UserHistory>>> = HashMap.HashMap<SharedTypes.ID, HashMap.HashMap<Nat, Buffer.Buffer<SharedTypes.UserHistory>>>(0, Text.equal, Text.hash);

    private func isEndpointCanister(caller : Principal) : Bool {
        let endpointPrincipal = Principal.fromText("kdhgfgk");
        return Principal.equal(caller, endpointPrincipal);
    };

    public shared ({ caller : Principal }) func requestPay(user : Principal, position : Nat, coin : SharedTypes.Coin, idCoin : ?Text) : async SharedTypes.Result<Text, Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        let userId : Text = Principal.toText(user);
        if (coin == #Point) {
            let innerMap = switch (userHistory.get(userId)) {
                case (?map) map;
                case null {
                    let newMap = HashMap.HashMap<Nat, Buffer.Buffer<SharedTypes.UserHistory>>(
                        0,
                        Nat.equal,
                        func(n : Nat) : Hash.Hash {
                            return Text.hash(Nat.toText(n));
                        },
                    );
                    userHistory.put(userId, newMap);
                    newMap;
                };
            };

            let buffer = switch (innerMap.get(position)) {
                case (?buf) buf;
                case null {
                    let newBuf = Buffer.Buffer<SharedTypes.UserHistory>(0);
                    innerMap.put(position, newBuf);
                    newBuf;
                };
            };
            let value : SharedTypes.UserHistory = {
                time = Int.abs(Time.now());
                coin = coin;
                coinName = "Point";
                amount = fixedAmountsStable[0].amount;
            };
            buffer.add(value);
            return #ok("Point request processed successfully");
        } else if (coin == #Token) {
            var id : Text = "";
            switch (idCoin) {
                case (null) { return #err("Coin ID is required for Token") };
                case (?n) {
                    if (Text.size(n) == 0) {
                        return #err("Coin ID cannot be empty");
                    };
                    id := n;
                };
            };
            var isTokenTransferAvaible : Bool = true;
            switch (userHistory.get(id)) {
                case null {  isTokenTransferAvaible := true };
                case (?segundoHashMap) {
                    var count = 0;
                    label list for (buffer in segundoHashMap.vals()) {
                        let iterableBuffer = buffer.vals();
                        var next = iterableBuffer.next();
                        while (next != null and count < 2) {
                            let history : SharedTypes.UserHistory = switch (next) {
                                case (?h) h;
                                case null { { time = 0; coin = #Token; coinName = ""; amount = 0 } }; // teorically unreachable
                            };
                            if (history.coin == #Token and history.coinName == id) {
                                count += 1;
                            };
                            next := iterableBuffer.next();
                        };
                        if (count < 2) { 
                            isTokenTransferAvaible := false;
                            break list;
                        };
                    };
                   
                };
            };
            if (not isTokenTransferAvaible) {
                return #err("Token transfer limit reached for this user");
            };
            let balance = await Request.requestBalance(caller, position, id);
            if (balance < fixedAmountsStable[1].amount) {
                return #err("Insufficient balance for Token");
            };
            let resultOfTransfer = await Request.requestTransfer(
                user,
                position,
                fixedAmountsStable[1].amount,
                id,
            );
            let innerMap = switch (userHistory.get(userId)) {
                case (?map) map;
                case null {
                    let newMap = HashMap.HashMap<Nat, Buffer.Buffer<SharedTypes.UserHistory>>(
                        0,
                        Nat.equal,
                        func(n : Nat) : Hash.Hash {
                            return Text.hash(Nat.toText(n));
                        },
                    );
                    userHistory.put(userId, newMap);
                    newMap;
                };
            };

            let buffer = switch (innerMap.get(position)) {
                case (?buf) buf;
                case null {
                    let newBuf = Buffer.Buffer<SharedTypes.UserHistory>(0);
                    innerMap.put(position, newBuf);
                    newBuf;
                };
            };
            let value : SharedTypes.UserHistory = {
                time = Int.abs(Time.now());
                coin = coin;
                coinName = id;
                amount = fixedAmountsStable[1].amount;
            };
            buffer.add(value);
            switch (resultOfTransfer) {
                case (#ok(_n)) {
                    return #ok("Token request processed successfully");
                };
                case (#err(_e)) {
                    return #err("Token transfer failed");
                };
            };
        } else {
            return #err("Invalid coin type");
        };
    };

    public shared query ({ caller : Principal }) func readSpecificUser(userId : SharedTypes.ID) : async SharedTypes.Result<SharedTypes.User, Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        let user : ?SharedTypes.User = users.get(userId);
        let result : SharedTypes.Result<SharedTypes.User, Text> = switch (user) {
            case (null) { #err("User not found") };
            case (?n) { #ok(n) };
        };
        return result;
    };

    public shared query ({ caller : Principal }) func readUsers() : async SharedTypes.Result<[SharedTypes.User], Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        return #ok(Iter.toArray(users.vals()));
    };

    public shared ({ caller : Principal }) func createUser(user : SharedTypes.User) : async SharedTypes.Result<Text, Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        if (not (users.get(user.id) == null)) {
            return #err("User already exists");
        };
        users.put(user.id, user);
        return #ok("User created successfully");
    };

    public shared ({ caller : Principal }) func updateUser(user : SharedTypes.User) : async SharedTypes.Result<Text, Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        if (users.get(user.id) == null) {
            return #err("User not exists");
        };
        users.put(user.id, user);
        return #ok("User updated successfully");
    };

    public shared ({ caller : Principal }) func deleteUser(id : SharedTypes.ID) : async SharedTypes.Result<Text, Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        if (users.get(id) == null) {
            return #err("User not exists");
        };
        users.delete(id);
        return #ok("User deleted successfully");
    };

    public shared query ({ caller : Principal }) func readFixedAmounts() : async SharedTypes.Result<[SharedTypes.FixedAmounts], Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        return #ok(Array.freeze(fixedAmountsStable));
    };

    public shared ({ caller : Principal }) func updateFixedAmount(coin : SharedTypes.Coin, amount : Nat) : async SharedTypes.Result<Text, Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        if (coin == #Point) {
            fixedAmountsStable[0] := { amount = amount; coin = coin };
            return #ok("Fixed amount updated successfully");
        } else if (coin == #Token) {
            fixedAmountsStable[1] := { amount = amount; coin = coin };
            return #ok("Fixed amount updated successfully");
        };
        return #err("Coin not found");
    };

    public shared query ({ caller : Principal }) func readUserHistory(userId : SharedTypes.ID) : async SharedTypes.Result<[(Nat, [SharedTypes.UserHistory])], Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        let user : ?SharedTypes.User = users.get(userId);
        if (user == null) {
            return #err("User not exists");
        };
        let mapUserHistory : ?HashMap.HashMap<Nat, Buffer.Buffer<SharedTypes.UserHistory>> = userHistory.get(userId);
        return switch (mapUserHistory) {
            case null { return #err("This user has no transaction history") };
            case (?history) {
                let mapUserHistoryArray = HashMap.map<Nat, Buffer.Buffer<SharedTypes.UserHistory>, [SharedTypes.UserHistory]>(
                    history,
                    Nat.equal,
                    func(n : Nat) : Hash.Hash {
                        return Text.hash(Nat.toText(n));
                    },
                    func(time : Nat, history : Buffer.Buffer<SharedTypes.UserHistory>) : [SharedTypes.UserHistory] {
                        return Buffer.toArray(history);
                    },
                );
                return #ok(Iter.toArray(mapUserHistoryArray.entries()));
            };
        };
    };

    public shared query ({ caller : Principal }) func readTotalPoints(userId : SharedTypes.ID) : async SharedTypes.Result<Nat, Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        let user : ?SharedTypes.User = users.get(userId);
        if (user == null) {
            return #err("User not exists");
        };
        let mapUserHistory : ?HashMap.HashMap<Nat, Buffer.Buffer<SharedTypes.UserHistory>> = userHistory.get(userId);
        let iterHistory = switch (mapUserHistory) {
            case null { Iter.fromArray([]) };
            case (?history) { history.vals() };
        };
        var totalPoints : Nat = 0;
        for (arrayHistory in iterHistory) {
            for (history in Iter.fromArray(Buffer.toArray(arrayHistory))) {
                if (history.coin == #Point) {
                    totalPoints += history.amount;
                };
            };
        };
        return #ok(totalPoints);
    };

    public shared query ({ caller : Principal }) func readTotalTokens(userId : SharedTypes.ID) : async SharedTypes.Result<[(Text, Nat)], Text> {
        if (not isEndpointCanister(caller)) {
            return #err("Unauthorized access");
        };
        let user : ?SharedTypes.User = users.get(userId);
        if (user == null) {
            return #err("User not exists");
        };
        let mapUserHistory : ?HashMap.HashMap<Nat, Buffer.Buffer<SharedTypes.UserHistory>> = userHistory.get(userId);
        let iterHistory = switch (mapUserHistory) {
            case null { Iter.fromArray([]) };
            case (?history) { history.vals() };
        };
        var totalTokens : HashMap.HashMap<Text, Nat> = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
        for (arrayHistory in iterHistory) {
            for (history in Iter.fromArray(Buffer.toArray(arrayHistory))) {
                if (history.coin == #Token) {
                    let currentAmount = totalTokens.get(history.coinName);
                    switch (currentAmount) {
                        case null {
                            totalTokens.put(history.coinName, history.amount);
                        };
                        case (?amt) {
                            totalTokens.put(history.coinName, amt + history.amount);
                        };
                    };
                };
            };
        };
        let tokenEntries = Iter.toArray(totalTokens.entries());
        if (Array.size(tokenEntries) == 0) {
            return #err("No tokens found for this user");
        } else {
            return #ok(tokenEntries);
        };
    };

    // Updates system functions for stable data management
    system func postupgrade() : () {
        users := HashMap.fromIter<Text, SharedTypes.User>(
            Iter.fromArray(usersStable),
            Array.size(usersStable),
            Text.equal,
            Text.hash,
        );
        var outerMap = Buffer.Buffer<(Text, HashMap.HashMap<Nat, Buffer.Buffer<SharedTypes.UserHistory>>)>(Array.size(userHistoryStable));
        for ((id, historyList) in Iter.fromArray(userHistoryStable)) {
            var historyBuffer = Buffer.Buffer<(Nat, Buffer.Buffer<SharedTypes.UserHistory>)>(0);
            for ((n, list) in Iter.fromArray(historyList)) {
                let tuple = (n, Buffer.fromArray<SharedTypes.UserHistory>(list));
                historyBuffer.add(tuple);
            };
            var innerMap = HashMap.fromIter<Nat, Buffer.Buffer<SharedTypes.UserHistory>>(
                Iter.fromArray(Buffer.toArray(historyBuffer)),
                Array.size(historyList),
                Nat.equal,
                func(n : Nat) : Hash.Hash {
                    return Text.hash(Nat.toText(n));
                },
            );
            outerMap.add((id, innerMap));
        };

        userHistory := HashMap.fromIter<Text, HashMap.HashMap<Nat, Buffer.Buffer<SharedTypes.UserHistory>>>(
            Iter.fromArray(Buffer.toArray(outerMap)),
            Array.size(userHistoryStable),
            Text.equal,
            Text.hash,
        );
    };

    system func preupgrade() : () {
        usersStable := Iter.toArray(users.entries());
        var outerArray = Buffer.Buffer<(SharedTypes.ID, [(Nat, [SharedTypes.UserHistory])])>(userHistory.size());
        for ((id, historyList) in userHistory.entries()) {
            var historyBuffer = Buffer.Buffer<(Nat, [SharedTypes.UserHistory])>(0);
            for ((n, list) in historyList.entries()) {
                let tuple = (n, Buffer.toArray<SharedTypes.UserHistory>(list));
                historyBuffer.add(tuple);
            };
            var innerArray = Buffer.toArray(historyBuffer);
            outerArray.add((id, innerArray));
        };
        userHistoryStable := Buffer.toArray(outerArray);
    };
};
