import Foundation

let clubDemoLessonTitle: String = "Unit 2: Art Club"

/// Przykładowa kartka „Play & Learn Club – English Code 1, Unit 2: Art Club” rozpisana w tym samym
/// formacie JSON, który zwraca Claude po zrobieniu zdjęcia.
let clubDemoLessonJSON: String = #"""
{
  "title": "Unit 2: Art Club",
  "theme_emoji": "🎨",
  "vocabulary": [
    {"english": "colouring pencil", "polish": "kredka ołówkowa", "emoji": "✏️", "group": "Unit 2 Vocabulary"},
    {"english": "crayon", "polish": "kredka świecowa", "emoji": "🖍️", "group": "Unit 2 Vocabulary"},
    {"english": "rubber", "polish": "gumka do ścierania", "emoji": "🧽", "group": "Unit 2 Vocabulary"},
    {"english": "glue stick", "polish": "klej w sztyfcie", "emoji": "🧴", "group": "Unit 2 Vocabulary"},
    {"english": "colouring pen", "polish": "pisak / flamaster", "emoji": "🖊️", "group": "Unit 2 Vocabulary"},
    {"english": "sweets", "polish": "słodycze", "emoji": "🍬", "group": "Unit 2 Vocabulary"},
    {"english": "fold", "polish": "składać", "emoji": "📄↩️", "group": "Unit 2 Vocabulary"},
    {"english": "paint pot", "polish": "pojemnik z farbą", "emoji": "🪣", "group": "Unit 2 Vocabulary"},
    {"english": "paintbrush", "polish": "pędzel", "emoji": "🖌️", "group": "Unit 2 Vocabulary"},
    {"english": "pencil case", "polish": "piórnik", "emoji": "👝", "group": "Unit 2 Vocabulary"},
    {"english": "pencil sharpener", "polish": "temperówka", "emoji": "✏️🌀", "group": "Unit 2 Vocabulary"},
    {"english": "ruler", "polish": "linijka", "emoji": "📏", "group": "Unit 2 Vocabulary"},
    {"english": "craft", "polish": "praca plastyczna", "emoji": "✂️", "group": "Unit 2 Vocabulary"},
    {"english": "dark", "polish": "ciemny", "emoji": "🌑", "group": "Experiment Lab"},
    {"english": "light", "polish": "jasny", "emoji": "💡", "group": "Experiment Lab"},
    {"english": "mix", "polish": "mieszać", "emoji": "🥣", "group": "Experiment Lab"},
    {"english": "primary colours", "polish": "kolory podstawowe", "emoji": "🔴🟡🔵", "group": "Experiment Lab"},
    {"english": "secondary colours", "polish": "kolory pochodne", "emoji": "🟠🟢🟣", "group": "Experiment Lab"}
  ],
  "grammar": [
    {
      "title": "There's / There are + and",
      "explanation_pl": "There's (There is) mówimy, gdy jest jedna rzecz. There are – gdy jest ich więcej. „and” znaczy „i”.",
      "examples": [
        {"english": "There's a paintbrush.", "polish": "Jest jeden pędzel.", "emoji": "🖌️"},
        {"english": "There are two crayons.", "polish": "Są dwie kredki świecowe.", "emoji": "🖍️🖍️"},
        {"english": "There are three rulers and two rubbers.", "polish": "Są trzy linijki i dwie gumki do ścierania.", "emoji": "📏📏📏 🧽🧽"}
      ]
    },
    {
      "title": "How many … are there?",
      "explanation_pl": "Tak pytamy „Ile jest…?”. Odpowiadamy: There is one… albo There are four…",
      "examples": [
        {"english": "How many paintbrushes are there?", "polish": "Ile jest pędzli?", "emoji": "🖌️❓"},
        {"english": "There is one paintbrush.", "polish": "Jest jeden pędzel.", "emoji": "🖌️"},
        {"english": "There are four paintbrushes.", "polish": "Są cztery pędzle.", "emoji": "🖌️🖌️🖌️🖌️"}
      ]
    },
    {
      "title": "Present Simple: be – być",
      "explanation_pl": "I am, you are, he / she / it is, we / you / they are. Przeczenie: am not, aren't, isn't. Pytanie: Am I…? Are you…? Is she…?",
      "examples": [
        {"english": "I am happy.", "polish": "Jestem szczęśliwy / szczęśliwa.", "emoji": "😀"},
        {"english": "Is she happy?", "polish": "Czy ona jest szczęśliwa?", "emoji": "👧❓"}
      ]
    },
    {
      "title": "Can – umieć / potrafić",
      "explanation_pl": "Can jest takie samo dla wszystkich osób. Przeczenie to can't. Pytanie: Can you…?",
      "examples": [
        {"english": "I can draw.", "polish": "Umiem rysować.", "emoji": "✍️"},
        {"english": "She can't swim.", "polish": "Ona nie umie pływać.", "emoji": "👧🚫🏊"},
        {"english": "Can you paint?", "polish": "Czy umiesz malować?", "emoji": "🎨❓"},
        {"english": "Yes, I can. / No, I can't.", "polish": "Tak, umiem. / Nie, nie umiem.", "emoji": "👍👎"}
      ]
    }
  ],
  "exercises": [
    {"instruction_pl": "Co to jest?", "question": "", "emoji": "🖌️", "options": ["paintbrush", "ruler", "crayon"], "answer": "paintbrush", "explanation_pl": "Paintbrush to pędzel."},
    {"instruction_pl": "Co to jest?", "question": "", "emoji": "📏", "options": ["rubber", "ruler", "glue stick"], "answer": "ruler", "explanation_pl": "Ruler to linijka."},
    {"instruction_pl": "Co znaczy to słowo?", "question": "crayon", "emoji": "🤔", "options": ["kredka świecowa", "linijka", "pędzel"], "answer": "kredka świecowa", "explanation_pl": "Crayon to kredka świecowa."},
    {"instruction_pl": "Co znaczy to słowo?", "question": "pencil case", "emoji": "🎒", "options": ["temperówka", "piórnik", "słodycze"], "answer": "piórnik", "explanation_pl": "Pencil case to piórnik."},
    {"instruction_pl": "Jak powiesz po angielsku „temperówka”?", "question": "", "emoji": "🤔", "options": ["pencil case", "pencil sharpener", "paint pot"], "answer": "pencil sharpener", "explanation_pl": "Temperówka to pencil sharpener."},
    {"instruction_pl": "Uzupełnij lukę", "question": "There ___ a paintbrush.", "emoji": "🖌️", "options": ["is", "are"], "answer": "is", "explanation_pl": "Jeden pędzel – There is."},
    {"instruction_pl": "Uzupełnij lukę", "question": "There ___ two crayons.", "emoji": "🖍️🖍️", "options": ["is", "are"], "answer": "are", "explanation_pl": "Dwie kredki – There are."},
    {"instruction_pl": "Policz i wybierz odpowiedź", "question": "How many rulers are there?", "emoji": "📏📏📏", "options": ["There is one ruler.", "There are two rulers.", "There are three rulers."], "answer": "There are three rulers.", "explanation_pl": "Są trzy linijki!"},
    {"instruction_pl": "Uzupełnij lukę", "question": "There are three rulers ___ two rubbers.", "emoji": "📏 ➕ 🧽", "options": ["and", "is", "can"], "answer": "and", "explanation_pl": "„and” znaczy „i”."},
    {"instruction_pl": "Uzupełnij lukę", "question": "I ___ happy.", "emoji": "😀", "options": ["am", "is", "are"], "answer": "am", "explanation_pl": "Mówimy: I am."},
    {"instruction_pl": "Uzupełnij lukę", "question": "She ___ happy.", "emoji": "👧", "options": ["am", "is", "are"], "answer": "is", "explanation_pl": "Mówimy: she is."},
    {"instruction_pl": "Uzupełnij lukę", "question": "They ___ in the Art Club.", "emoji": "👦👧🎨", "options": ["am", "is", "are"], "answer": "are", "explanation_pl": "Mówimy: they are."},
    {"instruction_pl": "Odpowiedz: TAK, umiesz!", "question": "Can you paint?", "emoji": "🎨", "options": ["Yes, I can.", "No, I can't.", "Yes, I am."], "answer": "Yes, I can.", "explanation_pl": "Yes, I can – tak, umiem!"},
    {"instruction_pl": "Co znaczy to zdanie?", "question": "She can't swim.", "emoji": "👧", "options": ["Ona umie pływać.", "Ona nie umie pływać.", "Ona jest szczęśliwa."], "answer": "Ona nie umie pływać.", "explanation_pl": "can't = nie umie."},
    {"instruction_pl": "Które to kolory podstawowe?", "question": "primary colours", "emoji": "🎨", "options": ["🔴🟡🔵", "🟠🟢🟣"], "answer": "🔴🟡🔵", "explanation_pl": "Czerwony, żółty i niebieski to kolory podstawowe."},
    {"instruction_pl": "Zmieszaj kolory! Co wyjdzie?", "question": "mix", "emoji": "🔴 ➕ 🟡", "options": ["🟠", "🟢", "🟣"], "answer": "🟠", "explanation_pl": "Czerwony i żółty dają pomarańczowy – to kolor pochodny."}
  ]
}
"""#
