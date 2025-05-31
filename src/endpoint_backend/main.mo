import D "mo:base/Debug";

actor {
  public query func greet(name : Text) : async Text {
    let greetings = "Un cambio de saludo ";
    D.print(greetings # name);
    return greetings # "Hello, " # name # "!!!2222";
  };
};
