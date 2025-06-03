import ExternalTypes "ExternalTypes";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import SharedTypes "../../shared/SharedTypes";

module ExternalService {
    private func actorService(id : SharedTypes.ID) : ExternalTypes.RequestActor {
        return actor (id);
    };

    private func subaccountFromPosition(position : Nat) : ?Blob {
        var quotient = position / 32;
        let remainder = position % 255;
        var i : Nat = 0;
        if (quotient < 32) {
            i := 1;
        } else if (quotient < 255) {
            i := 2;
        } else {
            i := 3;
        };

        var array = Array.init<Nat8>(32, 0);
        array[32 - i] := Nat8.fromNat(remainder);
        return ?Blob.fromArray(Array.freeze(array));
    };

    public func requestBalance(caller : Principal, position : Nat, idCoin : SharedTypes.ID) : async Nat {
        let account : ExternalTypes.Account = {
            owner = caller;
            subaccount = subaccountFromPosition(position);
        };
        let actorReference = actorService(idCoin);
        return await actorReference.icrc1_balance_of(account);
    };

    public func requestTransfer(user : Principal, position : Nat, amount : Nat, idCoin : SharedTypes.ID) : async Result.Result<Nat, Text> {
        let transferArg : ExternalTypes.TransferArg = {
            from_subaccount = subaccountFromPosition(position);
            to = {
                owner = user;
                subaccount = null;
            };
            fee = null;
            created_at_time = ?Nat64.fromIntWrap(Time.now());
            memo = null;
            amount = amount;
        };
        let actorReference = actorService(idCoin);
        let result = await actorReference.icrc1_transfer(transferArg);
        switch (result) {
            case (#Ok(n)) {
                return #ok(n);
            };
            case (#Err(_err)) {
                return #err("Error");
            };
        };

    }

};
