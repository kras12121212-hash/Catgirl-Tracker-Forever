-- Roleplay lines. Same keys and format strings as the classic catalog.
-- This file does not send chat.

local ADDON_NAME, CCT = ...

CCT.Messages = {
    -- HeadPetTracker
    HEADPET_SPANKED = "Was a bad kitten, and got spanked by %s.",
    HEADPET_EARPINCH = "Was a bad kitten, and got pinched in the ear by %s.",
    HEADPET_GOOD = "Was a good kitten, and received a %s from %s.",

    -- InnSlackerTracker
    INN_SLACKING = "Was caught slacking off in the inn again, nya!",

    -- PetTracker
    PET_SUMMON_GOOD = "Was a good kitten, and remembered to summon their cat",
    PET_SUMMON_BAD = "Was a bad kitten, and forgot to summon their cat",

    -- NapTracker (guild + optional debug say)
    NAP_WOKE_EARLY = "Was told to take her kitty nap, but was a cranky kitten that got up too early",
    NAP_OVERSLEPT = "Was told to take a nap, but decided to sleep all day! Bad, lazy kitten!",
    NAP_SLEPT_AS_TOLD = "Was a good kitten, and took a nap as instructed. Make sure to give her headpets and praise, nya!",
    NAP_DID_NOT_SLEEP = "Was told to take a nap, but did not listen, and should be punished by her owner.",
    NAP_DEBUG_WOKE_EARLY = "DEBUG: WokeUpToEarly",
    NAP_DEBUG_OVERSLEPT_MOVE = "DEBUG: Overslept (after move)",
    NAP_DEBUG_SLEPT_AS_TOLD = "DEBUG: SleptAsTold",
    NAP_DEBUG_OVERSLEPT_NOMOVE = "DEBUG: Overslept (no move)",
    NAP_DEBUG_DID_NOT_SLEEP = "DEBUG: DidNotSleep",

    -- Gag
    GAG_HEAVY = "Has been gagged with a huge gag, NYA!!! She's already whimpering... );",
    GAG_SMALL = "Has been gagged with a small gag. Hopefully that will be a lesson.",
    GAG_FULLBLOCK = "She has been fully masked and gagged... Not a sound can escape now! Nya~",
    GAG_INFLATABLE = "An inflatable gag is now in place. She can still mumble... For now.",
    GAG_INFLATE = "Inflated the gag. She's even more muffled now.",
    GAG_DEFLATE = "Deflated the gag slightly. She can mumble a bit more.",
    GAG_REMOVE = "Has been ungagged. She may speak freely again~",
    GAG_NYAMASK = "Has been been masked with a cute kitty mask. She's meowing every sentence! UwU",

    -- Leash
    LEASH_APPLY = "You have clipped the leash onto %s... There's no escape now, nya~",
    LEASH_REMOVE = "The leash slips free from %s. She's free... For now, nya~",

    -- Layer group invites
    LAYER_OWNER_INVITE_SENT = "Invited you to my group nya~",
    LAYER_OWNER_NEED_LEAVE = "curespbonding: I'm in a group and need to leave before inviting you nya~",
    LAYER_LIST_RESPONSE = "%s is on layer %s",
    LAYER_LIST_MISSING = "%s Missing Nova World Buffs or not Determined Yet",
    LAYER_INVITE_FULL = "Tryed to invite \"%s\" but has kitty brain and does not realise The group is already full nya !",
    LAYER_INVITE_NOT_OWNER = "Tryed to invite \"%s\" but is not even the owner of their group kitty brain strikes again nya ....",
    LAYER_INVITE_PROMISE = "%s is curently in a group but promises to invite you to layer change in %d minutes nya !",
    LAYER_INVITE_LEAVE = "%s was good Kitty and invited \"%s\" to a new layer nya !",
    LAYER_INVITE_BUSY = "Sorry %s does not have time to invite you right now nya.....",
    LAYER_INVITE_SUCCESS = "%s was sucefully invited to the requested layer.",
    LAYER_LOGIN_ANNOUNCE = "Uses CatGirlTracker V1.3 get it in our nya Discord. Use Llist  and then Linv6 to get layer 6 invite even without Addonn nya!. but the Addon can do a lot nya more~",

    -- Blindfold
    BLINDFOLD_LIGHT = "Oh nyo! A blurry light blindfold... I should better behave, or it may get worse!",
    BLINDFOLD_KITTY = "Wearing a cute kitty blindfold... Vision limited, nya~",
    BLINDFOLD_FULL = "Can't see anything! It's all black, nya!",
    BLINDFOLD_REMOVE = "Blindfold removed... Finally, I can see again, nya~",

    -- PawMittens
    PAW_MITTENS_SAY = "Oh no, looks like kitten has trouble using her spells thanks to these paws, nya!",
    PAW_MITTENS_RESPONSE_SQUEAKING = "Squeaking paw mittens have been locked onto your kitten's paws. They swap her spells briefly every 30 seconds, and squeak whenever she casts.",
    PAW_MITTENS_RESPONSE_LOCKED = "Tight paw mittens have been locked onto your kitten's paws. They are reinforced, so she cannot use her paws properly, or extend her claws at all.",
    PAW_MITTENS_REMOVE = "Your paw mittens have been removed. Your paws and claws are free again, nya~",

    -- LockingkittenHeels
    HEELS_PROGRESS = "Yay, \"%s\" is making progress learning how to walk in her \"%s\", she just reached level \"%d\"!",
    HEELS_FAIL = "Oh no.. \"%s\" just fell trying to walk in her \"%s\", she should be more careful and take it slow, or she will be stuck at level \"%d\" forever, nya~",
    HEELS_RESPONSE_MAID = "Maid heels (3 cm) were equipped and securely locked in place. The higher the heel, the harder it is to walk.",
    HEELS_RESPONSE_HIGH = "High heels (8 cm) were equipped and securely locked in place. The higher the heel, the harder it is to walk.",
    HEELS_RESPONSE_BALLET = "Ballet boots (12 cm) were equipped and securely locked in place. The higher the heel, the harder it is to walk.",
    HEELS_RESPONSE_GENERIC = "Heels are fitted and locked shut.",
    HEELS_REMOVE = "Your heels have been removed. Your feet are free again.",

    -- Chastity
    CHASTITY_BELT_APPLY = "A chastity belt has been locked in place. Your kitten's pleasure is sealed away.",
    CHASTITY_BELT_REMOVE = "The chastity belt has been removed. Your kitten can feel again.",
    CHASTITY_BELT_DENY = "The chastity belt is set to Deny Orgasm. She will be kept on the edge.",
    CHASTITY_BELT_ALLOW = "The chastity belt is set to Allow Orgasm. She may climax if she earns it.",
    CHASTITY_BRA_APPLY = "A chastity bra has been locked in place. Her chest is sealed and denied.",
    CHASTITY_BRA_REMOVE = "The chastity bra has been removed. Her chest is free again.",
    CHASTITY_DENY_SHOCK = "Your kitten almost Reached climax but the Magic Chastity Belt keept her in check with a harsh shock to her pussy.",

    -- Toys
    TOY_APPLY = "%s has been applied to your kitten.",
    TOY_REMOVE = "%s has been removed from your kitten.",
    TOY_VIBE_SET = "%s vibration set to intensity %d.",
    TOY_INFLATE_SET = "%s inflated to stage %d.",
    TOY_DEFLATE_SET = "%s deflated to stage %d.",
    TOY_SHOCK = "%s shock (intensity %d) delivered.",
    TOY_BLOCKED_BELT = "%s cannot be changed while a chastity belt is locked.",
    TOY_BLOCKED_BRA = "%s cannot be changed while a chastity bra is locked.",
    TOY_NOT_APPLIED = "%s is not currently applied.",

    -- Discipline
    DISCIPLINE_ACTION = "%s on %s (strength %d).",
    DISCIPLINE_BLOCKED_BELT = "%s cannot be used on %s while a chastity belt is locked.",
    DISCIPLINE_BLOCKED_BRA = "%s cannot be used on %s while a chastity bra is locked.",
    DISCIPLINE_TOO_FAR = "You are near your Kitten Nya!",

    -- Discipline (per-action blocked messages)
    DISCIPLINE_SPANK_HAND_BLOCKED_BELT = "%s cannot be used on %s while a chastity belt is locked.",
    DISCIPLINE_SPANK_HAND_BLOCKED_BRA = "%s cannot be used on %s while a chastity bra is locked.",
    DISCIPLINE_PINCH_BLOCKED_BELT = "%s cannot be used on %s while a chastity belt is locked.",
    DISCIPLINE_PINCH_BLOCKED_BRA = "%s cannot be used on %s while a chastity bra is locked.",
    DISCIPLINE_VIBRATING_WAND_BLOCKED_BELT = "%s cannot be used on %s while a chastity belt is locked.",
    DISCIPLINE_VIBRATING_WAND_BLOCKED_BRA = "%s cannot be used on %s while a chastity bra is locked.",
    DISCIPLINE_SHOCK_WAND_BLOCKED_BELT = "%s cannot be used on %s while a chastity belt is locked.",
    DISCIPLINE_SHOCK_WAND_BLOCKED_BRA = "%s cannot be used on %s while a chastity bra is locked.",
    DISCIPLINE_CROP_BLOCKED_BELT = "%s cannot be used on %s while a chastity belt is locked.",
    DISCIPLINE_CROP_BLOCKED_BRA = "%s cannot be used on %s while a chastity bra is locked.",
    DISCIPLINE_PADDLE_BLOCKED_BELT = "%s cannot be used on %s while a chastity belt is locked.",
    DISCIPLINE_PADDLE_BLOCKED_BRA = "%s cannot be used on %s while a chastity bra is locked.",
    DISCIPLINE_HEART_CROP_BLOCKED_BELT = "%s cannot be used on %s while a chastity belt is locked.",
    DISCIPLINE_HEART_CROP_BLOCKED_BRA = "%s cannot be used on %s while a chastity bra is locked.",
    DISCIPLINE_WHIP_BLOCKED_BELT = "%s cannot be used on %s while a chastity belt is locked.",
    DISCIPLINE_WHIP_BLOCKED_BRA = "%s cannot be used on %s while a chastity bra is locked.",

    -- Discipline (per-strength messages)
    DISCIPLINE_SPANK_HAND_1 = "%s on %s (strength %d).",
    DISCIPLINE_SPANK_HAND_2 = "%s on %s (strength %d).",
    DISCIPLINE_SPANK_HAND_3 = "%s on %s (strength %d).",
    DISCIPLINE_SPANK_HAND_4 = "%s on %s (strength %d).",
    DISCIPLINE_SPANK_HAND_5 = "%s on %s (strength %d).",

    DISCIPLINE_PINCH_1 = "%s on %s (strength %d).",
    DISCIPLINE_PINCH_2 = "%s on %s (strength %d).",
    DISCIPLINE_PINCH_3 = "%s on %s (strength %d).",

    DISCIPLINE_VIBRATING_WAND_1 = "%s on %s (strength %d).",
    DISCIPLINE_VIBRATING_WAND_2 = "%s on %s (strength %d).",
    DISCIPLINE_VIBRATING_WAND_3 = "%s on %s (strength %d).",

    DISCIPLINE_SHOCK_WAND_1 = "%s on %s (strength %d).",
    DISCIPLINE_SHOCK_WAND_2 = "%s on %s (strength %d).",
    DISCIPLINE_SHOCK_WAND_3 = "%s on %s (strength %d).",
    DISCIPLINE_SHOCK_WAND_4 = "%s on %s (strength %d).",
    DISCIPLINE_SHOCK_WAND_5 = "%s on %s (strength %d).",

    DISCIPLINE_CROP_1 = "%s on %s (strength %d).",
    DISCIPLINE_CROP_2 = "%s on %s (strength %d).",
    DISCIPLINE_CROP_3 = "%s on %s (strength %d).",

    DISCIPLINE_PADDLE_1 = "%s on %s (strength %d).",
    DISCIPLINE_PADDLE_2 = "%s on %s (strength %d).",
    DISCIPLINE_PADDLE_3 = "%s on %s (strength %d).",

    DISCIPLINE_HEART_CROP_1 = "%s on %s (strength %d).",
    DISCIPLINE_HEART_CROP_2 = "%s on %s (strength %d).",
    DISCIPLINE_HEART_CROP_3 = "%s on %s (strength %d).",

    DISCIPLINE_WHIP_1 = "%s on %s (strength %d).",
    DISCIPLINE_WHIP_2 = "%s on %s (strength %d).",
    DISCIPLINE_WHIP_3 = "%s on %s (strength %d).",

    -- Toys (per-toy messages)
    TOY_DILDO_APPLY = "Dildo applied to your kitten.",
    TOY_DILDO_REMOVE = "Dildo removed from your kitten.",
    TOY_DILDO_VIBE_1 = "Dildo vibration set to intensity 1.",
    TOY_DILDO_VIBE_2 = "Dildo vibration set to intensity 2.",
    TOY_DILDO_VIBE_3 = "Dildo vibration set to intensity 3.",
    TOY_DILDO_VIBE_4 = "Dildo vibration set to intensity 4.",
    TOY_DILDO_VIBE_5 = "Dildo vibration set to intensity 5.",
    TOY_DILDO_SHOCK_1 = "Dildo shock intensity 1 delivered.",
    TOY_DILDO_SHOCK_2 = "Dildo shock intensity 2 delivered.",
    TOY_DILDO_SHOCK_3 = "Dildo shock intensity 3 delivered.",

    TOY_INFLATABLE_BUTPLUG_APPLY = "Inflatable Butplug applied to your kitten.",
    TOY_INFLATABLE_BUTPLUG_REMOVE = "Inflatable Butplug removed from your kitten.",
    TOY_INFLATABLE_BUTPLUG_INFLATE_1 = "Inflatable Butplug inflated to stage 1.",
    TOY_INFLATABLE_BUTPLUG_INFLATE_2 = "Inflatable Butplug inflated to stage 2.",
    TOY_INFLATABLE_BUTPLUG_INFLATE_3 = "Inflatable Butplug inflated to stage 3.",
    TOY_INFLATABLE_BUTPLUG_INFLATE_4 = "Inflatable Butplug inflated to stage 4.",
    TOY_INFLATABLE_BUTPLUG_INFLATE_5 = "Inflatable Butplug inflated to stage 5.",
    TOY_INFLATABLE_BUTPLUG_DEFLATE_1 = "Inflatable Butplug deflated to stage 1.",
    TOY_INFLATABLE_BUTPLUG_DEFLATE_2 = "Inflatable Butplug deflated to stage 2.",
    TOY_INFLATABLE_BUTPLUG_DEFLATE_3 = "Inflatable Butplug deflated to stage 3.",
    TOY_INFLATABLE_BUTPLUG_DEFLATE_4 = "Inflatable Butplug deflated to stage 4.",
    TOY_INFLATABLE_BUTPLUG_DEFLATE_5 = "Inflatable Butplug deflated to stage 5.",

    TOY_INFLATABLE_DILDO_APPLY = "Inflatable Dildo applied to your kitten.",
    TOY_INFLATABLE_DILDO_REMOVE = "Inflatable Dildo removed from your kitten.",
    TOY_INFLATABLE_DILDO_INFLATE_1 = "Inflatable Dildo inflated to stage 1.",
    TOY_INFLATABLE_DILDO_INFLATE_2 = "Inflatable Dildo inflated to stage 2.",
    TOY_INFLATABLE_DILDO_INFLATE_3 = "Inflatable Dildo inflated to stage 3.",
    TOY_INFLATABLE_DILDO_INFLATE_4 = "Inflatable Dildo inflated to stage 4.",
    TOY_INFLATABLE_DILDO_INFLATE_5 = "Inflatable Dildo inflated to stage 5.",
    TOY_INFLATABLE_DILDO_DEFLATE_1 = "Inflatable Dildo deflated to stage 1.",
    TOY_INFLATABLE_DILDO_DEFLATE_2 = "Inflatable Dildo deflated to stage 2.",
    TOY_INFLATABLE_DILDO_DEFLATE_3 = "Inflatable Dildo deflated to stage 3.",
    TOY_INFLATABLE_DILDO_DEFLATE_4 = "Inflatable Dildo deflated to stage 4.",
    TOY_INFLATABLE_DILDO_DEFLATE_5 = "Inflatable Dildo deflated to stage 5.",

    TOY_SMALL_BUTPLUG_APPLY = "Small Butplug applied to your kitten.",
    TOY_SMALL_BUTPLUG_REMOVE = "Small Butplug removed from your kitten.",

    TOY_LARGE_BUTPLUG_APPLY = "Large Butplug applied to your kitten.",
    TOY_LARGE_BUTPLUG_REMOVE = "Large Butplug removed from your kitten.",

    TOY_TAILL_BUTPLUG_APPLY = "Taill Butplug applied to your kitten.",
    TOY_TAILL_BUTPLUG_REMOVE = "Taill Butplug removed from your kitten.",

    TOY_VIBES_PUSSY_APPLY = "Vibes Pussy applied to your kitten.",
    TOY_VIBES_PUSSY_REMOVE = "Vibes Pussy removed from your kitten.",
    TOY_VIBES_PUSSY_VIBE_1 = "Vibes Pussy vibration set to intensity 1.",
    TOY_VIBES_PUSSY_VIBE_2 = "Vibes Pussy vibration set to intensity 2.",
    TOY_VIBES_PUSSY_VIBE_3 = "Vibes Pussy vibration set to intensity 3.",
    TOY_VIBES_PUSSY_VIBE_4 = "Vibes Pussy vibration set to intensity 4.",
    TOY_VIBES_PUSSY_VIBE_5 = "Vibes Pussy vibration set to intensity 5.",

    TOY_VIBES_NIPPLES_APPLY = "Vibes Nipples applied to your kitten.",
    TOY_VIBES_NIPPLES_REMOVE = "Vibes Nipples removed from your kitten.",
    TOY_VIBES_NIPPLES_VIBE_1 = "Vibes Nipples vibration set to intensity 1.",
    TOY_VIBES_NIPPLES_VIBE_2 = "Vibes Nipples vibration set to intensity 2.",
    TOY_VIBES_NIPPLES_VIBE_3 = "Vibes Nipples vibration set to intensity 3.",
    TOY_VIBES_NIPPLES_VIBE_4 = "Vibes Nipples vibration set to intensity 4.",
    TOY_VIBES_NIPPLES_VIBE_5 = "Vibes Nipples vibration set to intensity 5.",

    TOY_VIBES_EARS_APPLY = "Vibes Ears applied to your kitten.",
    TOY_VIBES_EARS_REMOVE = "Vibes Ears removed from your kitten.",
    TOY_VIBES_EARS_VIBE_1 = "Vibes Ears vibration set to intensity 1.",
    TOY_VIBES_EARS_VIBE_2 = "Vibes Ears vibration set to intensity 2.",
    TOY_VIBES_EARS_VIBE_3 = "Vibes Ears vibration set to intensity 3.",
    TOY_VIBES_EARS_VIBE_4 = "Vibes Ears vibration set to intensity 4.",
    TOY_VIBES_EARS_VIBE_5 = "Vibes Ears vibration set to intensity 5.",
    TOY_VIBES_EARS_SHOCK_1 = "Vibes Ears shock intensity 1 delivered.",
    TOY_VIBES_EARS_SHOCK_2 = "Vibes Ears shock intensity 2 delivered.",
    TOY_VIBES_EARS_SHOCK_3 = "Vibes Ears shock intensity 3 delivered.",

    TOY_NIPPLE_PIERCINGS_APPLY = "Nipple Piercings applied to your kitten.",
    TOY_NIPPLE_PIERCINGS_REMOVE = "Nipple Piercings removed from your kitten.",
    TOY_NIPPLE_PIERCINGS_VIBE_1 = "Nipple Piercings vibration set to intensity 1.",
    TOY_NIPPLE_PIERCINGS_VIBE_2 = "Nipple Piercings vibration set to intensity 2.",
    TOY_NIPPLE_PIERCINGS_VIBE_3 = "Nipple Piercings vibration set to intensity 3.",
    TOY_NIPPLE_PIERCINGS_VIBE_4 = "Nipple Piercings vibration set to intensity 4.",
    TOY_NIPPLE_PIERCINGS_VIBE_5 = "Nipple Piercings vibration set to intensity 5.",
    TOY_NIPPLE_PIERCINGS_SHOCK_1 = "Nipple Piercings shock intensity 1 delivered.",
    TOY_NIPPLE_PIERCINGS_SHOCK_2 = "Nipple Piercings shock intensity 2 delivered.",
    TOY_NIPPLE_PIERCINGS_SHOCK_3 = "Nipple Piercings shock intensity 3 delivered.",

    TOY_EAR_PIERCINGS_APPLY = "Ear Piercings applied to your kitten.",
    TOY_EAR_PIERCINGS_REMOVE = "Ear Piercings removed from your kitten.",
    TOY_EAR_PIERCINGS_VIBE_1 = "Ear Piercings vibration set to intensity 1.",
    TOY_EAR_PIERCINGS_VIBE_2 = "Ear Piercings vibration set to intensity 2.",
    TOY_EAR_PIERCINGS_VIBE_3 = "Ear Piercings vibration set to intensity 3.",
    TOY_EAR_PIERCINGS_VIBE_4 = "Ear Piercings vibration set to intensity 4.",
    TOY_EAR_PIERCINGS_VIBE_5 = "Ear Piercings vibration set to intensity 5.",
    TOY_EAR_PIERCINGS_SHOCK_1 = "Ear Piercings shock intensity 1 delivered.",
    TOY_EAR_PIERCINGS_SHOCK_2 = "Ear Piercings shock intensity 2 delivered.",
    TOY_EAR_PIERCINGS_SHOCK_3 = "Ear Piercings shock intensity 3 delivered.",

    TOY_PUSSY_LIPPS_PIERCINGS_APPLY = "Pussy Lipps Piercings applied to your kitten.",
    TOY_PUSSY_LIPPS_PIERCINGS_REMOVE = "Pussy Lipps Piercings removed from your kitten.",
    TOY_PUSSY_LIPPS_PIERCINGS_VIBE_1 = "Pussy Lipps Piercings vibration set to intensity 1.",
    TOY_PUSSY_LIPPS_PIERCINGS_VIBE_2 = "Pussy Lipps Piercings vibration set to intensity 2.",
    TOY_PUSSY_LIPPS_PIERCINGS_VIBE_3 = "Pussy Lipps Piercings vibration set to intensity 3.",
    TOY_PUSSY_LIPPS_PIERCINGS_VIBE_4 = "Pussy Lipps Piercings vibration set to intensity 4.",
    TOY_PUSSY_LIPPS_PIERCINGS_VIBE_5 = "Pussy Lipps Piercings vibration set to intensity 5.",
    TOY_PUSSY_LIPPS_PIERCINGS_SHOCK_1 = "Pussy Lipps Piercings shock intensity 1 delivered.",
    TOY_PUSSY_LIPPS_PIERCINGS_SHOCK_2 = "Pussy Lipps Piercings shock intensity 2 delivered.",
    TOY_PUSSY_LIPPS_PIERCINGS_SHOCK_3 = "Pussy Lipps Piercings shock intensity 3 delivered.",
}


function CCT.Msg(key, ...)
    local template = CCT.Messages and CCT.Messages[key]
    if not template then
        return tostring(key or "")
    end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, template, ...)
        if ok then
            return formatted
        end
    end
    return template
end
