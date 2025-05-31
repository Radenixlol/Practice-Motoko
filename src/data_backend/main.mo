import Json "mo:json";

actor {

    public shared query func greet(name : Text) : async Text {
        let greetings = "Un cambio de saludo ";
        // D.print(greetings # name);
        return greetings # "Hello, " # name # "!!!2222";
    };

    public shared query func greet2(name : Text) : async Text {
        let greetings = "Un cambio de saludo ";
        // D.print(greetings # name);
        return greetings # "Hello, " # name # "!!!3333";
    };
}