//
//  MorseKeyCodes.swift
//  MorseCodeInputMethod
//
//  Created by Pete Vieira on 9/4/24.
//

import Foundation

/// Keys that are allowed to be use to type Morse symbols
/// See here for more info (https://eastmanreference.com/complete-list-of-applescript-key-codes)
let MorseLetterKeyCodes: [Int64] = [
    12 /*Q*/, 13 /*W*/, 14 /*E*/, 15 /*R*/, 17 /*T*/, 16 /*Y*/, 32 /*U*/, 34 /*I*/, 31 /*O*/, 35 /*P*/,
     0 /*A*/,  1 /*S*/,  2 /*D*/,  3 /*F*/,  5 /*G*/,  4 /*H*/, 38 /*J*/, 40 /*K*/, 37 /*L*/,
     6 /*Z*/,  7 /*X*/,  8 /*C*/,  9 /*V*/, 11 /*B*/, 45 /*N*/, 46 /*M*/
]

let MorseNumberKeyCodes: [Int64] = [
    18 /*1*/, 19 /*2*/, 20 /*3*/, 21 /*4*/, 23 /*5*/, 22 /*6*/, 26 /*7*/, 28 /*8*/, 25 /*9*/
]

let KeyCodeToNumber: [Int64:Int64] = [
    18: 1,
    19: 2,
    20: 3,
    21: 4,
    23: 5,
    22: 6,
    26: 7,
    28: 8,
    25: 9
]
