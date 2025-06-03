import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Bool "mo:base/Bool";
import Json "mo:json";
import { string; number; schemaObject } "mo:json"; //JSON Schema Types
import SharedTypes "../shared/SharedTypes";
import Data "canister:data_backend";

actor {

  private let userRequestSchema = schemaObject(
    [
      ("position", number()),
      ("coin", string()),
      ("idCoin", string()),
    ],
    ?["coin"],
  );

  private func isOwner(_user : Principal) : Bool {
    return true;
    // let owner : Principal = Principal.fromText("djhhdbfdfhkjd");
    // return Principal.equal(user, owner);
  };

  private func isAuthorizedUser(user : Principal) : async Bool {
    let result : SharedTypes.Result<SharedTypes.User, Text> = await Data.readSpecificUser(Principal.toText(user));
    switch (result) {
      case (#ok(user)) {
        return user.isAuthorized;
      };
      case (#err(_error)) {
        return false;
      };
    };
  };

  public shared ({ caller : Principal }) func requestPay(userRequest : Text) : async SharedTypes.Result<Text, Text> {
    if (not (await isAuthorizedUser(caller))) {
      return #err("Unauthorized user");
    };
    switch (Json.parse(userRequest)) {
      case (#ok(parsed)) {
        switch (Json.validate(parsed, userRequestSchema)) {
          case (#ok()) {
            var position : Nat = 0;
            switch (Json.getAsNat(parsed, "position")) {
              case (#ok(pos)) {
                if (pos <= 0) {
                  return #err("Position cannot be 0 or negative");
                };
                position := pos;
              };
              case (#err(_e)) { return #err("Position is not valid") };
            };
            var coin : SharedTypes.Coin = #Point;
            switch (Json.getAsText(parsed, "coin")) {
              case (#ok(coinText)) {
                switch (coinText) {
                  case ("Point") { coin := #Point };
                  case ("Token") { coin := #Token };
                  case (_) { return #err("Invalid coin type") };
                };
              };
              case (#err(_e)) { return #err("Coin is not valid") };
            };
            var idCoin : ?Text = null;
            if (coin == #Token) {
              idCoin := switch (Json.getAsText(parsed, "idCoin")) {
                case (#ok(id)) { ?id };
                case _ { return #err("idCoin is required") };
              };
            };
            let result = await Data.requestPay(caller, position, coin, idCoin);
            switch (result) {
              case (#ok(_n)) {
                return #ok("Request processed successfully");
              };
              case (#err(_e)) {
                return #err("Error processing request");
              };
            };
            return #ok("Request processed successfully");
          };
          case (#err(_e)) {
            return #err("Invalid JSON format");
          };
        };
      };
      case (#err(_e)) {
        return #err("Invalid JSON format");
      };
    };
  };

  public shared composite query ({ caller : Principal }) func readSpecificUser(userId : SharedTypes.ID) : async SharedTypes.Result<SharedTypes.User, Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    return await Data.readSpecificUser(userId);
  };

  public shared composite query ({ caller : Principal }) func readUsers() : async SharedTypes.Result<[SharedTypes.User], Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    return await Data.readUsers();
  };

  public shared ({ caller : Principal }) func createUser(newUser : SharedTypes.NewUser) : async SharedTypes.Result<Text, Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    let user : SharedTypes.User = {
      id = newUser.id;
      username = newUser.username;
      email = newUser.email;
      isAuthorized = true;
    };
    return await Data.createUser(user);
  };

  public shared ({ caller : Principal }) func updateUser(user : SharedTypes.User) : async SharedTypes.Result<Text, Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    return await Data.updateUser(user);
  };

  public shared ({ caller : Principal }) func deleteUser(id : SharedTypes.ID) : async SharedTypes.Result<Text, Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    return await Data.deleteUser(id);
  };

  public shared composite query ({ caller : Principal }) func readFixedAmountss() : async SharedTypes.Result<[SharedTypes.FixedAmounts], Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    return await Data.readFixedAmounts();
  };

  public shared ({ caller : Principal }) func updateFixedAmount(coin : SharedTypes.Coin, amount : Nat) : async SharedTypes.Result<Text, Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    return await Data.updateFixedAmount(coin, amount);
  };

  public shared composite query ({ caller : Principal }) func readUserHistory(userId : SharedTypes.ID) : async SharedTypes.Result<[(Nat, [SharedTypes.UserHistory])], Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    return await Data.readUserHistory(userId);
  };

  public shared composite query ({ caller : Principal }) func readTotalPoints(userId : SharedTypes.ID) : async SharedTypes.Result<Nat, Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    return await Data.readTotalPoints(userId);
  };

  public shared composite query ({ caller : Principal }) func readTotalTokens(userId : SharedTypes.ID) : async SharedTypes.Result<[(Text, Nat)], Text> {
    if (not (isOwner(caller))) {
      return #err("Unauthorized user");
    };
    return await Data.readTotalTokens(userId);
  };

};
