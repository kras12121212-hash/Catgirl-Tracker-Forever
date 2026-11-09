# CatgirlTracker Forever

CatgirlTracker Forever is a roleplay addon for World of Warcraft: Forever. Install the folder `CatgirlTracker_Forever`. The table of contents declares interface `16001`, the title CatgirlTracker Forever, and the account-wide saved table `CatgirlTrackerDB`.

Copy that folder into the Forever `Interface/AddOns` directory. Forever loads this folder. The classic `CatgirlTracker` folder is a local reference and is not part of this repository. The two copies do not share saved data.

The build specification is [docs/CatgirlTracker-Forever-Design.md](docs/CatgirlTracker-Forever-Design.md).

## The three roles

**Kitten.** The character the addon acts on. The guild note on that character contains `owner=First Last`. That name is the Owner. `owner=First-Last` is the same person. A comma ends the name, and only the first two words are kept. When the officer note has text, the client reads the owner from the officer note. When the officer note is empty, `owner=` on the public note still counts. Forever has no realm in a character name. A first name alone is a different character.

**Owner.** One person for that kitten. The Owner opens `/cgcc` and applies gear from that window. A click from anyone else, including the Guild Master, does nothing.

**Guild Master.** One character for the whole guild. Set the name with `/cctmaster First Last`. `First-Last` is the same name. The name starts empty. While it is empty, no character is Guild Master and kittens do not send the weekly report. The name is typed. It is not taken from a guild rank.

## Commands

| Command | What it does |
| --- | --- |
| `/cgcc` | Opens the owner control window. |
| `/cgcc advertise` | Opens the five-line advertise window. |
| `/cctdebug` | Turns debug printing on or off. It starts off. |
| `/cctmodule` | Lists the five modules. `/cctmodule Name` turns that module on or off. |
| `/cctmaster` | Prints the Guild Master name, or says it is not set. |
| `/cctmaster First Last` | Sets the Guild Master. `First-Last` is the same name. |

`/cctcmd` is not a command.

## What a click does

An owner button sends a hidden addon message. The kitten accepts that message only from the Owner, then changes the gear. The sentence shown in the whisper window is not the switch.

After the kitten accepts the message, the roleplay lines still appear for both of you. A heavy gag still tells you that your owner secured a heavy gag. Typing one of those lines by hand does not change the gear.

Guild lines for a headpet, a nap, slacking, or a heel fall can still be posted. They are flavor, and they are on by default. They are not how the addon decides what happened. The addon keeps no guild-chat transcript.

## Owner controls

A draggable **cgcc** button at the top of the screen opens the same window as `/cgcc`. The window has five tabs: Stats, Control, Toys, Discipline, and Settings. Control, Toys, and Discipline keep each group collapsed until you open it. The window opens with no assigned kitten. Kitten actions stay disabled until one is assigned. Stats then says that most functions are not available.

`/cgcc` is the live window for the assigned kitten. It shows what is worn, the timers, the map distance, heat, and submissiveness. If that kitten has never sent a snapshot, the panels say "no snapshot".

The buttons cover the leash, the gags, the blindfold, the earmuffs, both bells, the mittens, chastity with deny and allow, the three heel types, the tracking jewel, force group, toys, and discipline. The hour box starts at 1.5 and is what a timed unlock uses. The maid list is edited from this window. The Nya checkboxes sit on the same window.

A command counts only after the message is accepted and the kitten answers that it applied. This window is the live controls. The weekly scorecard is a separate saved file, and this window does not draw it.

Force group invites the Owner. If the kitten is already in a party, the addon leaves that party and then sends the invite. There is no confirm frame.

While the tracking jewel is off, distance reads unknown, and the discipline buttons warn and do not send.

## Pictures and the binds strip

When gear is applied, a picture pops for five seconds. Removing gear does not pop a picture. The binds strip along the top of the screen shows what is worn right now. It is drawn from the current gear, and you can drag it.

## Advertise

The advertise window holds five lines. Open it with `/cgcc advertise` or the Advertise button. Sending starts off for each character. Lines that do go out still pass through the gag. Advertise is separate from the five modules, and it is separate from the weekly scorecard.

## Maid sync

The Owner's maid list is sent to the kitten as a hidden addon message. The kitten keeps the items and the instructions. An unchanged refresh does not add a task. A real change to the list adds one task on the kitten when the new list is applied, and one task on the Owner after the kitten accepts it. A list that is too large is refused, adds no task, and is not retried.

## The CatNya pet button

A draggable button runs a macro named CatNya. The macro uses the cat-carrier items. The button remembers whether you marked the cat as summoned. Pet tracking starts on. Five minutes after login, one guild flavor line can fire while you are alive. That line is not a row on the weekly report.

## Nya

Nya rewrites outgoing chat. It stays off until Enable Nya is turned on in the owner window. The other Nya checkboxes do nothing while that switch is off.

## What you hear

Heel steps play only while the kitten is walking. They repeat about every seven seconds and stop when the kitten stops. The collar bell waits between two and five minutes. The tail bell jingles about every five or six seconds while the kitten is walking. When the kitten stops, a jingle that is already playing stops. These clips are ogg files. A custom wav does not play.

The kitten hears the sound on this computer. The Owner hears the heels only when close on the map, and hears either bell inside a wider map distance. Inside that distance the sound is full volume. Farther away, the Owner hears nothing. There is no fade.

A party member who has the addon hears the sound too. Party members are not checked for distance, and they are not sent the kitten's position. Someone without the addon hears nothing, because the sound travels as an addon message.

## The weekly report

Each kitten counts the week on their own computer. A week starts on Monday. The label looks like `2026-W45`, taken from that computer's clock. The week in progress, and one finished week behind it, are what can be sent.

When the Guild Master is online, those weeks are written into `CatgirlTrackerDB`. The game draws no scorecard, no copy box, and no leaderboard. The saved file is the report. A week this Guild Master never stored can be noted as missed. A finished week that rolls off the one saved slot can be noted as rotated. Those notes are not printed as a scorecard.

The report includes time worn, tasks, heat, headpets, naps, slacking, and zones. The Owner's accepted commands are stored beside the kitten's own counts.

## Discord

The addon cannot talk to Discord. It opens no webhook and no web request. A companion program, written later, reads `CatgirlTrackerDB` while the game is closed, posts a week, and deletes that week only after Discord has accepted it. The addon does not delete a week on its own.

## What this version leaves out

The layer list, `llist`, `linv`, and the login advertisement that used to read a layer addon are absent. They do not send guild addon messages. Force group is the owner button described above, and that button is in the addon.

There is no cleanup window. Stored lists are capped.

There is no sync debug window. `/cctdebug` prints rate-limited lines.

## Modules

`/cctmodule` lists only these five:

- HeadPetTracker, on
- InnSlackerTracker, on
- PetTracker, on
- MaidTasks, on
- KittenMapShow, off

The map stays off until you enable KittenMapShow. The owner then sees where the kitten is, and about one point a minute of where the kitten walked for the last 30 days. The settings slider picks the day. Hover a pin for the time. Today also shows the current pin. Another day shows only that day's walk. The kitten does not see their own trail.
