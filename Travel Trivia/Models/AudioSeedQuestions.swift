//
//  AudioSeedQuestions.swift
//  Travel Trivia
//
//  Bundled starter packs for the 3 audio genres — Animal Sounds Safari,
//  Sound FX Guess, Name That Tune. Clips live under
//  Travel Trivia/AudioClips/<genre-slug>/ (auto-bundled, this project uses
//  Xcode 16 file-system-synchronized groups) and are resolved at playback
//  time by AudioClipLibrary.
//
//  Sourcing note: the original plan (see the design vault) was Freesound +
//  Zapsplat for animal/SFX clips and Jamendo for music. Both Freesound and
//  Jamendo require a registered API client_id obtained through an account
//  signup flow this automated session could not complete (no working
//  anonymous/demo credential exists for either as of this session — a
//  previously-shared Jamendo "test" client_id came back suspended). Zapsplat
//  was already flagged in the original sourcing decision as needing manual
//  curation, so it was skipped here too, per instructions, rather than
//  silently substituted.
//
//  Every clip below was instead sourced live from the Wikimedia Commons API
//  (public, no key required), which is CC-licensed and requires the same
//  kind of per-clip attribution tracking Freesound would have needed. Real
//  audio, real attribution, real license text — just a different (equally
//  legitimate) CC catalog than originally scoped. If real Freesound/Jamendo
//  credentials become available later, AudioClipLibrary's remote-URL path
//  (see Audio/AudioClipLibrary.swift) is ready to stream from them without
//  reworking this file's shape.
//
//  Expansion pass (2026-07-28): re-attempted Freesound/Jamendo signup —
//  both still require an interactive account (email verification, and in
//  Freesound's case a login-gated "apply for API access" flow) that a
//  headless session can't complete; same fundamental blocker as before, not
//  a temporary outage. Added ~27 more real Wikimedia Commons clips across
//  all 3 genres this pass (12 animals, 13 SFX, 14 tunes — one tune target,
//  Barber of Seville, was dropped when the only usable CC0 clip turned out
//  to be a different aria from the same opera, which would have mismatched
//  the answer text; a few SFX targets — popcorn popping, zipper — had no
//  real recording on Commons, only pronunciation/music files, and were
//  dropped rather than padded with a mismatch).
//
//  Name-that-tune deliberately uses public-domain classical pieces rather
//  than pop songs — sidesteps the sync/performance licensing risk flagged
//  as unresolved in 2026-07-25_question-format-and-content-sourcing.md.
//

import Foundation

nonisolated enum AudioSeedQuestions {
    /// Every audio genre with bundled content, by slug.
    static let packs: [String: [TriviaQuestion]] = [
        "animal-sounds-safari": animalSoundsSafari,
        "sound-fx-guess": soundFXGuess,
        "name-that-tune": nameThatTune,
    ]

    /// Simple three-tier split so each pack still has an easy/medium/hard
    /// spread like the text genres, without hand-authoring difficulty per
    /// clip (there's no natural "harder to guess" signal to sort these by).
    private static func audioDifficulty(index: Int, count: Int) -> Difficulty {
        switch index * 3 / max(count, 1) {
        case 0: .easy
        case 1: .medium
        default: .hard
        }
    }

    // MARK: - animal-sounds-safari
    static let animalSoundsSafari: [TriviaQuestion] = {
        let names: [String: String] = [
            "cat": "Cat",
            "chicken": "Chicken",
            "cow": "Cow",
            "cricket": "Cricket",
            "cuckoo": "Cuckoo",
            "dog": "Dog",
            "elephant": "Elephant",
            "frog": "Frog",
            "horse": "Horse",
            "lion": "Lion",
            "owl": "Owl",
            "rooster": "Rooster",
            "sheep": "Sheep",
            "pig": "Pig",
            "goat": "Goat",
            "donkey": "Donkey",
            "turkey": "Turkey",
            "bee": "Bee",
            "seagull": "Seagull",
            "peacock": "Peacock",
            "parakeet": "Parakeet",
            "penguin": "Penguin",
            "flamingo": "Flamingo",
            "woodpecker": "Woodpecker",
            "canary": "Canary",
        ]
        let attributions: [String: String] = [
            "cat": "\"Meow of a pleading cat.oga\" by Heismark (Public domain), via Wikimedia Commons",
            "chicken": "\"Chickens demanding food.ogg\" by alys (Public domain), via Wikimedia Commons",
            "cow": "\"Single Cow Moo.ogg\" by MichaeltheFox8621 (CC BY-SA 4.0), via Wikimedia Commons",
            "cricket": "\"Field cricket unedited.ogg\" by Thatcher (CC BY-SA 3.0), via Wikimedia Commons",
            "cuckoo": "\"Great Spotted Cuckoo call (Clamator glandarius).ogg\" by João Tomás (CC BY 4.0), via Wikimedia Commons",
            "dog": "\"Barking of a dog 2.ogg\" by Amada44 (CC BY-SA 3.0), via Wikimedia Commons",
            "elephant": "\"Elephant voice - trumpeting.ogg\" by தகவலுழவன் (CC0), via Wikimedia Commons",
            "frog": "\"Single Frog Croak.oga\" by MichaeltheFox8621 (CC BY-SA 4.0), via Wikimedia Commons",
            "horse": "\"Wiehern.ogg\" by Hü. (Public domain), via Wikimedia Commons",
            "lion": "\"Lion raring-sound1TamilNadu178.ogg\" by த*உழவன் (Public domain), via Wikimedia Commons",
            "owl": "\"Strix aluco male.oga\" by Vianney Bajart (CC BY-SA 4.0), via Wikimedia Commons",
            "rooster": "\"Rooster crowing.ogg\" by Filo gèn' (CC BY-SA 4.0), via Wikimedia Commons",
            "sheep": "\"Sheep bleating.ogg\" by earthcalling (Public domain), via Wikimedia Commons",
            "pig": "\"Mudchute pig 1.ogg\" by Secretlondon (CC BY-SA 3.0), via Wikimedia Commons",
            "goat": "\"Herd of goats bleating.ogg\" by stephan (Public domain), via Wikimedia Commons",
            "donkey": "\"157763 felix-blume a-donkey-is-braying-in-his-enclosure-in-south-of-france.wav\" by felix-blume (CC0), via Wikimedia Commons",
            "turkey": "\"Meleagris gallopavo - Wild Turkey XC134155.ogg\" by Jonathon Jongsma (CC BY-SA 3.0), via Wikimedia Commons",
            "bee": "\"Bee buzzing sound (animal noises).opus\" by Free Sounds Library User Spanac (CC BY 3.0), via Wikimedia Commons",
            "seagull": "\"XC707075 - European Herring Gull - Larus argentatus.mp3\" by Sonothèque ADVL (CC0), via Wikimedia Commons",
            "peacock": "\"Indian Peafowl.ogg\" by Gypsypkd (Public domain), via Wikimedia Commons",
            "parakeet": "\"Budgerigar chirping.ogg\" by mary905 (Public domain), via Wikimedia Commons",
            "penguin": "\"20091121 Little Penguin calls at St Kilda Breakwater.ogg\" by Mikeybear (CC BY 3.0), via Wikimedia Commons",
            "flamingo": "\"Greater flamingo call recorded in March 2005 at Mayani, Satara.wav\" by Sharadapte (CC BY-SA 4.0), via Wikimedia Commons",
            "woodpecker": "\"Great Spotted Woodpecker drum.ogg\" by T.Voekler (CC BY-SA 3.0), via Wikimedia Commons",
            "canary": "\"Long-range-Order-in-Canary-Song-pcbi.1003052.s002.oga\" by Markowitz J, Ivie E, Kligler L, Gardner T (CC BY 2.5), via Wikimedia Commons",
        ]
        let keys = ["cat", "chicken", "cow", "cricket", "cuckoo", "dog", "elephant", "frog", "horse", "lion", "owl", "rooster", "sheep",
                    "pig", "goat", "donkey", "turkey", "bee", "seagull", "peacock", "parakeet", "penguin", "flamingo", "woodpecker", "canary"]
        return keys.enumerated().map { index, key in
            let correctText = names[key]!
            // Deterministic distractor pick: the next 5 clips in the pool
            // (wrapping around) — display order gets shuffled per-deal by
            // shufflingOptions, so fixed pick order here is harmless.
            let distractorKeys = (1...5).map { keys[(index + $0) % keys.count] }
            let optionTexts = [correctText] + distractorKeys.map { names[$0]! }
            let options = optionTexts.enumerated().map { i, text in
                AnswerOption(id: "animalSoundsSafari-\(index + 1)-\(i)", text: text)
            }
            return TriviaQuestion(
                id: "animalSoundsSafari-\(index + 1)",
                difficulty: audioDifficulty(index: index, count: keys.count),
                prompt: "Which animal made this sound?",
                options: options,
                correctOptionID: options[0].id,
                mediaFileName: "\(key).m4a",
                attribution: attributions[key]!
            )
        }
    }()

    // MARK: - sound-fx-guess
    static let soundFXGuess: [TriviaQuestion] = {
        let names: [String: String] = [
            "alarm-clock": "Alarm Clock",
            "applause": "Applause",
            "camera-shutter": "Camera Shutter",
            "car-engine": "Race Car Engine",
            "church-bell": "Church Bell",
            "door-knock": "Door Knock",
            "geese-honking": "Geese Honking",
            "keyboard-typing": "Keyboard Typing",
            "police-siren": "Police Siren",
            "train-whistle": "Train Whistle",
            "doorbell": "Doorbell",
            "telephone-ring": "Telephone Ringing",
            "ocean-waves": "Ocean Waves",
            "rain": "Rain",
            "bicycle-bell": "Bicycle Bell",
            "vacuum-cleaner": "Vacuum Cleaner",
            "cash-register": "Cash Register",
            "drum-roll": "Drum Roll",
            "referee-whistle": "Referee Whistle",
            "typewriter": "Typewriter",
            "scissors-snip": "Scissors Cutting",
            "page-turning": "Page Turning",
            "blender": "Blender",
        ]
        let attributions: [String: String] = [
            "alarm-clock": "\"Alarm clock - 01.ogg\" by Mathieu Kappler (CC BY-SA 4.0), via Wikimedia Commons",
            "applause": "\"Clapping hurray (cropped).oga\" by Starlite (Public domain), via Wikimedia Commons",
            "camera-shutter": "\"Canon T50 shutter noise.ogg\" by Francois C (CC BY-SA 3.0), via Wikimedia Commons",
            "car-engine": "\"Benetton-Ford B188 (1988).ogg\" by Edvvc (CC BY-SA 3.0), via Wikimedia Commons",
            "church-bell": "\"Bytom Margaret church John of Nepomuk bell ringing.ogg\" by Adrian Tync (CC BY-SA 4.0), via Wikimedia Commons",
            "door-knock": "\"Knocking on wood or door.ogg\" by stephan (Public domain), via Wikimedia Commons",
            "geese-honking": "\"Geese Honking (loud).ogg\" by U.S. Fish and Wildlife Service (Public domain), via Wikimedia Commons",
            "keyboard-typing": "\"Typing - Model M13 1999.ogg\" by Raymangold22 (CC0), via Wikimedia Commons",
            "police-siren": "\"WWS Policecarsiren.ogg\" by Work With Sounds / Konrad Gutkowski (CC BY 4.0), via Wikimedia Commons",
            "train-whistle": "\"WWS SteamWhistle.ogg\" by Work With Sounds / Konrad Gutkowski (CC BY 4.0), via Wikimedia Commons",
            "doorbell": "\"Sound Effect - Door Bell.ogg\" by Amada44 (CC0), via Wikimedia Commons",
            "telephone-ring": "\"Model 500 Telephone British ring.ogg\" by CianMcCann (CC BY-SA 3.0), via Wikimedia Commons",
            "ocean-waves": "\"Oceanwavescrushing.ogg\" by Luftrum (CC BY 3.0), via Wikimedia Commons",
            "rain": "\"Rain (1).ogg\" by ezwa (Public domain), via Wikimedia Commons",
            "bicycle-bell": "\"Bicycle-bell.wav\" by Xampi8 (CC BY 3.0), via Wikimedia Commons",
            "vacuum-cleaner": "\"Het aanstaan van een stofzuiger - SoundCloud - Beeld en Geluid.ogg\" by Beeld en Geluid (CC BY-SA 3.0), via Wikimedia Commons",
            "cash-register": "\"Cash register.ogg\" by Me (Public domain), via Wikimedia Commons",
            "drum-roll": "\"Drum Roll Intro.ogg\" by Iwan Sounds and DIY (CC0), via Wikimedia Commons",
            "referee-whistle": "\"218318 splicesound referee-whistle-blow-gymnasium.wav\" by SpliceSound (CC0), via Wikimedia Commons",
            "typewriter": "\"WWS Typewriter.ogg\" by Work With Sounds / Konrad Gutkowski (CC BY 4.0), via Wikimedia Commons",
            "scissors-snip": "\"WWS Paper-cuttingscissorsSloveniaPartisanPrintingShop.ogg\" by Work With Sounds / Technical Museum of Slovenia (CC BY 4.0), via Wikimedia Commons",
            "page-turning": "\"Turning a page.ogg\" by planish (Public domain), via Wikimedia Commons",
            "blender": "\"Het vermalen van fruit in een blender - SoundCloud - marloeskunst.ogg\" by marloeskunst (CC BY 3.0), via Wikimedia Commons",
        ]
        let keys = ["alarm-clock", "applause", "camera-shutter", "car-engine", "church-bell", "door-knock", "geese-honking", "keyboard-typing", "police-siren", "train-whistle",
                    "doorbell", "telephone-ring", "ocean-waves", "rain", "bicycle-bell", "vacuum-cleaner", "cash-register", "drum-roll", "referee-whistle", "typewriter", "scissors-snip", "page-turning", "blender"]
        return keys.enumerated().map { index, key in
            let correctText = names[key]!
            // Deterministic distractor pick: the next 5 clips in the pool
            // (wrapping around) — display order gets shuffled per-deal by
            // shufflingOptions, so fixed pick order here is harmless.
            let distractorKeys = (1...5).map { keys[(index + $0) % keys.count] }
            let optionTexts = [correctText] + distractorKeys.map { names[$0]! }
            let options = optionTexts.enumerated().map { i, text in
                AnswerOption(id: "soundFXGuess-\(index + 1)-\(i)", text: text)
            }
            return TriviaQuestion(
                id: "soundFXGuess-\(index + 1)",
                difficulty: audioDifficulty(index: index, count: keys.count),
                prompt: "What sound effect is this?",
                options: options,
                correctOptionID: options[0].id,
                mediaFileName: "\(key).m4a",
                attribution: attributions[key]!
            )
        }
    }()

    // MARK: - name-that-tune
    static let nameThatTune: [TriviaQuestion] = {
        let names: [String: String] = [
            "air-on-g-string": "Air on the G String",
            "blue-danube": "The Blue Danube Waltz",
            "flight-of-the-bumblebee": "Flight of the Bumblebee",
            "four-seasons-spring": "The Four Seasons: Spring",
            "fur-elise": "Für Elise",
            "hall-of-the-mountain-king": "In the Hall of the Mountain King",
            "moonlight-sonata": "Moonlight Sonata",
            "pomp-and-circumstance": "Pomp and Circumstance",
            "ride-of-the-valkyries": "Ride of the Valkyries",
            "swan-lake": "Swan Lake",
            "toccata-fugue": "Toccata and Fugue in D Minor",
            "turkish-march": "Turkish March",
            "william-tell-overture": "William Tell Overture",
            "ode-to-joy": "Ode to Joy",
            "eine-kleine-nachtmusik": "Eine kleine Nachtmusik",
            "canon-in-d": "Canon in D",
            "habanera": "Habanera",
            "1812-overture": "1812 Overture",
            "sugar-plum-fairy": "Dance of the Sugar Plum Fairy",
            "waltz-of-the-flowers": "Waltz of the Flowers",
            "radetzky-march": "Radetzky March",
            "can-can": "Can-Can (Galop Infernal)",
            "gymnopedie": "Gymnopédie No. 1",
            "clair-de-lune": "Clair de Lune",
            "jupiter": "Jupiter (The Planets)",
            "minuet-in-g": "Minuet in G Major",
            "la-donna-e-mobile": "La Donna è Mobile",
        ]
        let attributions: [String: String] = [
            "air-on-g-string": "\"Air (Bach).ogg\" by Unknown (Public domain), via Wikimedia Commons",
            "blue-danube": "\"Polyphon - Donau-Walzer (Johann Strauss).ogg\" by unbekannt, tot seit über 70 Jahren (CC0), via Wikimedia Commons",
            "flight-of-the-bumblebee": "\"Muriel-Nguyen-Xuan-Korsakov-Flight-of-the-bumblebee.flac.oga\" by Play by Muriel Nguyen Xuan, recording by Stéphane Magnenat (CC BY-SA 3.0), via Wikimedia Commons",
            "four-seasons-spring": "\"Vivaldi - Four Seasons 1 Spring mvt 1 Allegro - John Harrison violin.oga\" by Antonio Vivaldi (CC BY-SA), via Wikimedia Commons",
            "fur-elise": "\"For Elise (Für Elise) Beethoven JMC Han.ogg\" by Ludwig van Beethoven (CC BY-SA 4.0), via Wikimedia Commons",
            "hall-of-the-mountain-king": "\"Musopen - In the Hall Of The Mountain King.ogg\" by Grieg, Edvard; Musopen Symphony Orchestra (Public domain), via Wikimedia Commons",
            "moonlight-sonata": "\"Moonlight Sonata (Sharp c minor Sonata) 2nd Movement Beethoven JMC,Han.ogg\" by Ludwig van Beethoven (CC BY-SA 4.0), via Wikimedia Commons",
            "pomp-and-circumstance": "\"Pomp and circumstances No. 1.ogg\" by Edward Elgar (1857–1934) (Public domain), via Wikimedia Commons",
            "ride-of-the-valkyries": "\"Richard Wagner - Ride of the Valkyries.ogg\" by Richard Wagner (1813–1883) (Public domain), via Wikimedia Commons",
            "swan-lake": "\"Peter Ilyich Tchaikovsky-Swan Lake- Extract from Act 3.ogg\" by Ballet Francaise Symphony Orchestra (Public domain), via Wikimedia Commons",
            "toccata-fugue": "\"BachToccataAndFugueInDMinorOpeningPianoHiFi.ogg\" by Opus33 at English Wikipedia (Public domain), via Wikimedia Commons",
            "turkish-march": "\"Rondo Alla Turka.ogg\" by Wolfgang Amadeus Mozart (Public domain), via Wikimedia Commons",
            "william-tell-overture": "\"William Tell Overture - Edison.ogg\" by Edison National Historic Site (Public domain), via Wikimedia Commons",
            "ode-to-joy": "\"Ode to Joy.ogg\" by Ludwig van Beethoven (Public domain), via Wikimedia Commons",
            "eine-kleine-nachtmusik": "\"Mozart K525 Serenade in G Major 1 - Allegro.ogg\" by Wolfgang Amadeus Mozart (Public domain), via Wikimedia Commons",
            "canon-in-d": "\"Kevin MacLeod - Canon in D Major.ogg\" by Kevin MacLeod; original composition by Johann Pachelbel (CC BY 3.0), via Wikimedia Commons",
            "habanera": "\"Habanera.ogg\" by Pracchia-78 (Public domain), via Wikimedia Commons",
            "1812-overture": "\"1812.ogg\" by FortunateTheognis (Public domain), via Wikimedia Commons",
            "sugar-plum-fairy": "\"Tchaikovsky - Dance of the Sugar Plum Fairy - The Nutcracker.ogg\" by Pyotr Ilyich Tchaikovsky (CC BY 3.0), via Wikimedia Commons",
            "waltz-of-the-flowers": "\"P.I. Tchaikovsky's Waltz of the Flowers Performed by The U.S. Army Band, c. 2019.mp3\" performed by the U.S. Army Band (Public domain), via Wikimedia Commons",
            "radetzky-march": "\"Radetzky March.ogg\" performed by the United States Marine Band, composed by Johann Strauss I (Public domain), via Wikimedia Commons",
            "can-can": "\"Jacques Offenbach - Galop Infernal from Orpheus in the Underworld (Can Can) (1858).ogg\" by Gnissah (Public domain), via Wikimedia Commons",
            "gymnopedie": "\"Gymnopedie No. 1..ogg\" by Teknopazzo (CC0), via Wikimedia Commons",
            "clair-de-lune": "\"Clair de lune (Claude Debussy) Suite bergamasque.ogg\" by Claude Debussy (CC BY 3.0), via Wikimedia Commons",
            "jupiter": "\"Holst The Planets Jupiter.ogg\" performed by the United States Air Force Band, composed by Gustav Holst (Public domain), via Wikimedia Commons",
            "minuet-in-g": "\"Minuet in G major, BWV Anh. 114 (played by PLATO GSW).flac\" by Morn (CC0), via Wikimedia Commons",
            "la-donna-e-mobile": "\"La Donna E Mobile Rigoletto.ogg\" by Giuseppe Verdi & Francesco Maria Piave (Public domain), via Wikimedia Commons",
        ]
        let keys = ["air-on-g-string", "blue-danube", "flight-of-the-bumblebee", "four-seasons-spring", "fur-elise", "hall-of-the-mountain-king", "moonlight-sonata", "pomp-and-circumstance", "ride-of-the-valkyries", "swan-lake", "toccata-fugue", "turkish-march", "william-tell-overture",
                    "ode-to-joy", "eine-kleine-nachtmusik", "canon-in-d", "habanera", "1812-overture", "sugar-plum-fairy", "waltz-of-the-flowers", "radetzky-march", "can-can", "gymnopedie", "clair-de-lune", "jupiter", "minuet-in-g", "la-donna-e-mobile"]
        return keys.enumerated().map { index, key in
            let correctText = names[key]!
            // Deterministic distractor pick: the next 5 clips in the pool
            // (wrapping around) — display order gets shuffled per-deal by
            // shufflingOptions, so fixed pick order here is harmless.
            let distractorKeys = (1...5).map { keys[(index + $0) % keys.count] }
            let optionTexts = [correctText] + distractorKeys.map { names[$0]! }
            let options = optionTexts.enumerated().map { i, text in
                AnswerOption(id: "nameThatTune-\(index + 1)-\(i)", text: text)
            }
            return TriviaQuestion(
                id: "nameThatTune-\(index + 1)",
                difficulty: audioDifficulty(index: index, count: keys.count),
                prompt: "Name that tune!",
                options: options,
                correctOptionID: options[0].id,
                mediaFileName: "\(key).m4a",
                attribution: attributions[key]!
            )
        }
    }()

}
