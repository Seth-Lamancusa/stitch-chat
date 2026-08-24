This guide outlines best practices for designing high-quality functions that are easier to reason about, test, and maintain.

1. Build systems with honest functions
Strive for "honest" functions that access the outside world only through their arguments. This maximizes local reasoning and testability.
Design Principle: Keep the core business logic composed of pure, honest functions. Reserve "dishonest" functions (those sensitive to external state or performing side effects) for the top-most level of your application (18:20-18:50).
Example: Instead of reading a global random number generator (PRNG) inside a particle population function, pass the PRNG as an argument. This allows for reproducible testing by providing a fixed seed when necessary (22:04-26:00).

2. Design empathetic signatures
Your function signature is the primary interface for other developers and should be designed with their needs in mind.
Clarity: Avoid long lists of boolean or ambiguous parameters. Use structs to group arguments to improve readability at the call site (26:22-27:23).
Flexibility: Do not over-constrain inputs. For example, instead of requiring a `std::vector` for a read-only operation, use a `std::span` to allow for a wider range of compatible input containers (27:43-28:44).
Type Safety: Use the type system to enforce invariants. For cases like vector normalization, consider a `NormalizedVec3` type that guarantees the property upon construction, preventing runtime errors later (33:09-34:31).

3. Stay at one level of abstraction
Your function should represent a coherent step in your program's logic. Avoid "zooming in" to low-level implementation details and back out within the same function.
Golden Rule: Every line of your function body should exist at the same level of abstraction. Use function calls to delegate lower-level tasks (37:48-38:35).
Example: If you are searching for an asset, do not manually loop through characters to convert them to lowercase and then perform a raw binary search within the same function. Instead, call specialized functions like `to_lower` and use standard library algorithms, keeping the high-level logic clean and readable (38:42-46:05).
