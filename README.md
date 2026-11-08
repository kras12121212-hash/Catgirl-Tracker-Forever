# Catgirl Tracker Forever

A roleplay addon for World of Warcraft: Forever. One kitten wears the gear. One Owner drives that kitten. One Guild Master collects a weekly progress report from every kitten.

The addon is not written yet. This repository is the clean start. The build plan is [docs/CatgirlTracker-Forever-Design.md](docs/CatgirlTracker-Forever-Design.md). The older classic addon is not part of this repository.

## The three people

**Kitten.** The character the addon acts on. The guild note on that character says `owner=Name`. That name is the Owner.

**Owner.** One person for that kitten. The Owner opens `/cgcc` and uses it to apply a gag, a blindfold, mittens, heels, bells, a leash, chastity, toys, locks, and maid tasks. A click from anyone else, including the Guild Master, does nothing.

**Guild Master.** One character for the whole guild. Every kitten sends that character a weekly progress report. The name is a setting. It starts empty, and it is not taken from the guild rank unless you type that character's name. The Guild Master does not see the report inside the game. The client only saves it.

## What a click does

The Owner's button does not use the sentence in the whisper window as the switch. It sends a hidden addon message. The kitten's addon accepts that message only from the Owner, then changes the gear.

After the kitten accepts it, the same roleplay whispers still appear for both of you. A heavy gag still reads along the lines of "Your owner has secured a heavy gag in place." The kitten still answers with the old reply. Those lines are for the two of you to read. Typing one of them by hand does not change anything.

Guild chat lines for a headpet, a nap, or slacking can still be posted. They are flavor. They are not how the addon decides what happened.

## What you hear

Heel steps and both bells play only while the kitten is walking. When the kitten stops, the sound stops for the kitten, for the Owner, and for anyone in the party who has the addon.

The Owner hears the heels only when close, inside a small distance on the map. The Owner hears either bell inside a wider distance. Inside that distance the sound is full volume. Farther away, the Owner hears nothing. There is no fade.

A party member who has the addon hears the sound too. Someone without the addon hears nothing, because it is an addon message and not a sound in the world. Party members are not checked for distance, and they are not sent the kitten's position.

## The weekly report

Each kitten counts the week on their own computer. A week starts on Monday. The label looks like `2026-W45`. The week that is in progress, and one finished week behind it, are what can be sent.

When the Guild Master logs in, those two weeks arrive and are written into the addon's saved file. A third week that was never received is not replayed. Its totals are gone. The file can still say that the week was missed.

The report includes time worn, tasks, heat, headpets, naps, slacking, and zones. The Owner's accepted commands are stored beside the kitten's own counts, so a later reward can prefer the Owner's number for those commands.

The Owner's window stays the live controls: what is worn, the timers, the distance, heat, and submissiveness. It is not a weekly scoreboard.

## Discord

The addon cannot talk to Discord. A companion program, written later, reads the saved file while the game is closed, posts a week, and deletes that week only after Discord has accepted it. The addon does not delete the file on its own, and it does not keep every week forever.

## Where the addon will live

Forever uses the modern addon interface, number `16001`. The new folder will be `CatgirlTracker_Forever`, next to the classic `CatgirlTracker` folder, not inside it. Forever will not load the classic copy. Classic will not load this one.
