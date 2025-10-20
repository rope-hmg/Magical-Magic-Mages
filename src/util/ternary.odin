package util

enum Ternary {
    False = -1,
    Unknown,
    True,
}

not :: #force_inline proc(a: Ternary) -> Ternary {
    return Ternary(int(a) * -1)
}

and :: #force_inline proc(a, b: Ternary) -> Ternary {
    return Ternary(min(int(a), int(b)))
}

or :: #force_inline proc(a, b: Ternary) -> Ternary {
    return Ternary(max(int(a), int(b)))
}

xor :: #force_inline proc(a, b: Ternary) -> Ternary {
    return or(and(a, not(b)), and(not(a), b))
}
