class_name NameGenerator extends Resource

static var CONSONANTS: PackedStringArray = [
	"b", "bb", "bl", "br",
	"c", "cc", "ch", "ck",
	"d", "dd", "dh", "dr", "dw",
	"f", "ff", "fl", "fr",
	"g", "gg", "gh", "gl", "gr", "ght",
	"h",
	"j",
	"k", "kk", "kn", "kr",
	"l", "ld", "lg", "lk", "ll", "lm", "lp", "lt", "lv",
	"m", "mm", "mp",
	"n", "ng", "nk", "nn", "nt",
	"p", "ph", "pl", "pp", "pr", "ps", "pt",
	"q", "qu",
	"r", "rd", "rg", "rk", "rl", "rm", "rm", "rp", "rr", "rt",
	"s", "sc", "sh", "sk", "sl", "sm", "sn", "sp", "ss", "st", "sw", "sch", "str", "spl", "spr",
	"t", "th", "tr", "tt", "tw", "tch", "thr",
	"v",
	"w", "wh", "wr",
	"x", "xt",
	"y",
	"z", "zz",
]
static var CONSONANT_COUNT: int = CONSONANTS.size() - 1
static var VOWELS: PackedStringArray = [
	"a",       "ae", "ai", "ao", "au", "ay",
	"e", "ea", "ee", "ei", "eo", "eu", "ey", "eau",
	"i", "ia", "ie",       "io", "iu",       "iou",
	"o", "oa", "oe", "oi", "oo", "ou", "oy",
	"u", "ua", "ue", "ui", "uo",       "uy", "uou",
	"y",
]
static var VOWEL_COUNT: int = VOWELS.size() - 1

static func GenerateName(a_consonant: bool, a_size: int) -> String:
	var toReturn: String = ""
	for i in range(a_size):
		toReturn += CONSONANTS[randi_range(0, CONSONANT_COUNT)] if a_consonant else VOWELS[randi_range(0, VOWEL_COUNT)]
		a_consonant = !a_consonant
	return toReturn
