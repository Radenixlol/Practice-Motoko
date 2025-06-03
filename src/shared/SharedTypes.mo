import Result "mo:base/Result";

module SharedTypes {
    public type Result<Ok, Err> = Result.Result<Ok, Err>;
    public type ID = Text;
    public type NewUser = {
        id: ID;
        username: Text;
        email: Text;
    };
    public type User = {
        id: ID;
        username: Text;
        email: Text;
        isAuthorized: Bool;
    };
    public type Coin = {
        #Point;
        #Token;
    };
    public type FixedAmounts = {
        coin: Coin;
        amount: Nat;
    };
    public type UserHistory = {
        time: Nat;
        coin : Coin;
        coinName: Text;
        amount: Nat;
    };
};
