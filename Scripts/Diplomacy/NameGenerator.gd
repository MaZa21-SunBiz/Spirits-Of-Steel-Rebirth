class_name NameGenerator extends Resource

static var SHARED_CONSONANTS: Dictionary[String, float] = {
	"b": 10.00, "bl":  1.00,
	"c": 10.00, "ch":  1.00,
	"d": 10.00, "dh":  1.00,
	"f": 10.00, "fl":  1.00,
	"g": 10.00, "gh":  1.00, "gr":  1.00,
	"h": 10.00,
	"j": 10.00,
	"k": 10.00, 
	"l": 10.00, "ll":  1.00, 
	"m": 10.00,
	"n": 10.00,
	"p": 10.00, "ph":  1.00, "ps":  1.00, "pt":  1.00,
	"q": 10.00,
	"r": 10.00,
	"s": 10.00, "sh":  1.00, "sm":  1.00, "sn":  1.00, "sp":  1.00, "st":  1.00,
	"t": 10.00, "th":  1.00,
	"v": 10.00,
	"w": 10.00,
	"x":  2.00,
	"y": 10.00,
	"z":  2.00,
}

static var START_CONSONANTS: Dictionary[String, float] = {
	"br":  1.00,
	"dr":  1.00,
	"fr":  1.00,
	"gl":  1.00,
	"kn":  1.00, "kr":  1.00,
	"pl":  1.00, "pr":  1.00,
	"qu":  1.00,
	"sc":  1.00, "sk":  1.00, "sl":  1.00, "sw":  1.00, "sch":  1.00, "str":  1.00, "spl":  1.00, "spr":  1.00,
	"tr":  1.00, "tw":  1.00, "thr":  1.00,
	"wh":  1.00, "wr":  1.00,
}

static var MIDDLE_CONSONANTS: Dictionary[String, float] = {
	"bb":  1.00, "br":  1.00,
	"cc":  1.00, "ck":  1.00,
	"dd":  1.00, "dr":  1.00, "dw":  1.00,
	"ff":  1.00, "fr":  1.00,
	"gg":  1.00, "gl":  1.00, "ght":  1.00,
	"kk":  1.00, "kn":  1.00, "kr":  1.00,
	"ld":  1.00, "lg":  1.00, "lk":  1.00, "lm":  1.00, "lp":  1.00, "lt":  1.00, "lv":  1.00,
	"mm":  1.00, "mp":  1.00,
	"ng":  1.00, "nk":  1.00, "nn":  1.00, "nt":  1.00,
	"pl":  1.00, "pp":  1.00, "pr":  1.00,
	"qu":  1.00,
	"rd":  1.00, "rg":  1.00, "rk":  1.00, "rl":  1.00, "rm":  1.00, "rp":  1.00, "rr":  1.00, "rt":  1.00,
	"sc":  1.00, "sk":  1.00, "sl":  1.00, "ss":  1.00, "sw":  1.00, "sch":  1.00, "str":  1.00, "spl":  1.00, "spr":  1.00,
	"tr":  1.00, "tt":  1.00, "tw":  1.00, "tch":  1.00, "thr":  1.00,
	"wh":  1.00, "wr":  1.00,
	"xt":  1.00,
	"zz":  1.00,
}

static var END_CONSONANTS: Dictionary[String, float] = {
	"cc":  1.00, "ck":  1.00,
	"dd":  1.00,
	"ff":  1.00,
	"gg":  1.00, "gl":  1.00, "ght":  1.00,
	"kk":  1.00, "kn":  1.00, "kr":  1.00,
	"ld":  1.00, "lg":  1.00, "lk":  1.00, "lm":  1.00, "lp":  1.00, "lt":  1.00, "lv":  1.00,
	"mm":  1.00, "mp":  1.00,
	"ng":  1.00, "nk":  1.00, "nn":  1.00, "nt":  1.00,
	"pp":  1.00,
	"qu":  1.00,
	"rd":  1.00, "rg":  1.00, "rk":  1.00, "rl":  1.00, "rm":  1.00, "rp":  1.00, "rr":  1.00, "rt":  1.00,
	"sc":  1.00, "sk":  1.00, "ss":  1.00, "sch":  1.00,
	"tt":  1.00, "tch":  1.00,
	"xt":  1.00,
	"zz":  1.00,
}

static var ALL_CONSONANTS: Dictionary[String, float] = {
	"b":  1.00, "bb":  1.00, "bl":  1.00, "br":  1.00,
	"c":  1.00, "cc":  1.00, "ch":  1.00, "ck":  1.00,
	"d":  1.00, "dd":  1.00, "dh":  1.00, "dr":  1.00, "dw":  1.00,
	"f":  1.00, "ff":  1.00, "fl":  1.00, "fr":  1.00,
	"g":  1.00, "gg":  1.00, "gh":  1.00, "gl":  1.00, "gr":  1.00, "ght":  1.00,
	"h":  1.00,
	"j":  1.00,
	"k":  1.00, "kk":  1.00, "kn":  1.00, "kr":  1.00,
	"l":  1.00, "ld":  1.00, "lg":  1.00, "lk":  1.00, "ll":  1.00, "lm":  1.00, "lp":  1.00, "lt":  1.00, "lv":  1.00,
	"m":  1.00, "mm":  1.00, "mp":  1.00,
	"n":  1.00, "ng":  1.00, "nk":  1.00, "nn":  1.00, "nt":  1.00,
	"p":  1.00, "ph":  1.00, "pl":  1.00, "pp":  1.00, "pr":  1.00, "ps":  1.00, "pt":  1.00,
	"q":  1.00, "qu":  1.00,
	"r":  1.00, "rd":  1.00, "rg":  1.00, "rk":  1.00, "rl":  1.00, "rm":  1.00, "rp":  1.00, "rr":  1.00, "rt":  1.00,
	"s":  1.00, "sc":  1.00, "sh":  1.00, "sk":  1.00, "sl":  1.00, "sm":  1.00, "sn":  1.00, "sp":  1.00, "ss":  1.00, "st":  1.00, "sw":  1.00, "sch":  1.00, "str":  1.00, "spl":  1.00, "spr":  1.00,
	"t":  1.00, "th":  1.00, "tr":  1.00, "tt":  1.00, "tw":  1.00, "tch":  1.00, "thr":  1.00,
	"v":  1.00,
	"w":  1.00, "wh":  1.00, "wr":  1.00,
	"x":  1.00, "xt":  1.00,
	"y":  1.00,
	"z":  1.00, "zz":  1.00,
}

static var VOWELS: Dictionary[String, float] = {
	"a": 35.00,              "ae":  7.50, "ai":  1.00, "ao":  1.00, "au": 12.50, "ay":  1.00,
	"e": 55.00, "ea":  1.00, "ee": 10.00, "ei":  1.00, "eo":  1.00, "eu":  1.00, "ey":  1.00, "eau":  1.00,
	"i": 35.00, "ia":  1.00, "ie":  1.00,              "io":  1.00, "iu":  1.00,              "iou":  1.00,
	"o": 35.00, "oa":  1.00, "oe":  1.00, "oi":  1.00, "oo":  6.00, "ou":  5.00, "oy":  1.00,
	"u": 35.00, "ua":  1.00, "ue":  1.00, "ui":  1.00, "uo":  1.00,              "uy":  1.00, "uou":  1.00,
	"y": 25.00,
}

static func GenerateName(a_consonant: bool, a_size: int) -> String:
	var usedMiddleConsonants: Dictionary[String, float] = MIDDLE_CONSONANTS.merged(SHARED_CONSONANTS)
	var toReturn: String = WeightedRandoms(START_CONSONANTS.merged(SHARED_CONSONANTS) if a_consonant else VOWELS)
	a_consonant = !a_consonant
	for i in range(a_size - 2):
		toReturn += WeightedRandoms(usedMiddleConsonants if a_consonant else VOWELS)
		a_consonant = !a_consonant
	toReturn += WeightedRandoms(END_CONSONANTS.merged(SHARED_CONSONANTS) if a_consonant else VOWELS)
	return toReturn

static func WeightedRandoms(a_options: Dictionary[String, float]) -> String:
	var total: float = 0
	for weight: float in a_options.values():
		total += weight
	var choice: float = randf_range(0, total)
	for option: Variant in a_options:
		choice -= a_options[option]
		if choice <= 0:
			return option
	return ""
