class_name NameGenerator extends Resource

static var CONSONANTS: PackedStringArray = [
	"b",
	"c",
	"cc",
	"ch",
	"d",
	"dh",
	"f",
	"g",
	"gh",
	"h",
	"j",
	"k",
	"l",
	"ld",
	"lg",
	"m",
	"mm",
	"n",
	"nn",
	"nt",
	"p",
	"pt",
	"q",
	"r",
	"rt",
	"s",
	"st",
	"t",
	"th",
	"v",
	"w",
	"wh",
	"x",
	"y",
	"z"
]
static var CONSONANT_COUNT: int = CONSONANTS.size() - 1
static var VOWELS: PackedStringArray = [
	"a",
	"aa",
	"ae",
	"ai",
	"ao",
	"au",
	"e",
	"ea",
	"ee",
	"ei",
	"eo",
	"eu",
	"i",
	"ia",
	"ie",
	"io",
	"iu",
	"o",
	"oa",
	"oe",
	"oi",
	"oo",
	"ou",
	"u",
	"ua",
	"ue",
	"ui",
	"uo",
]
static var VOWEL_COUNT: int = VOWELS.size() - 1

static func GenerateName(a_consonant: bool, a_size: int) -> String:
	var toReturn: String = ""
	for i in range(a_size):
		toReturn += CONSONANTS[randi_range(0, CONSONANT_COUNT)] if a_consonant else VOWELS[randi_range(0, VOWEL_COUNT)]
		a_consonant = !a_consonant
	return toReturn
