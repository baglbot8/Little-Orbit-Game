class_name Neighborhood
extends RefCounted
## Stateless neighbor writing. Stable IDs: Lumi 0, Bolt 1, Pip 2, Miso 3.
## Planet IDs: Clover 0, Luma 1, Rust 2, The Commons 3, Pebble 4, Honey 5.

const NAMES = ["Lumi", "Bolt", "Pip", "Miso"]
const PLANETS = [1, 2, 4, 5]

# Six favors repeat in order; the caller owns acceptance and round counts.
# Empty tokens mean no pickup. Visits and wishes must occur after acceptance;
# decorating counts the decorations currently placed on Clover.
const QUESTS = [
	[
		{
			"type": "retrieve",
			"title": "A star for the moon garden",
			"request": "My moon garden is missing a little sparkle. Could you find a fallen star on Clover? Look for its golden glow. I'll make something just for you!",
			"reminder": "The fallen star is on Clover, near the garden. No hurry; moonflowers are very patient.",
			"thank_you": "There it is! I'll nestle it beside the moonflowers. Now they'll have a little sky even when they look down.",
			"target": 1,
			"planet": 0,
			"token": "star",
		},
		{
			"type": "collect",
			"title": "Little pools of light",
			"request": "I'd like to mark my garden path with something gentle. Could you gather three crystals from around Luma? Even a sleepy moth should be able to find its way home.",
			"reminder": "Three crystals from around Luma will do. The path only needs a little light.",
			"thank_you": "One by the gate, one at the bend, one beside the watering can. Thank you for helping the small things get home.",
			"target": 3,
			"planet": 1,
			"token": "crystal",
		},
		{
			"type": "decorate",
			"title": "A corner that feels like you",
			"request": "You've spent so much time helping my garden. Will you give Clover a little attention? Have three decorations placed at home, wherever they make you happy. Anything already there counts.",
			"reminder": "Have three decorations placed on Clover. You can choose the spots by feeling; that's how I plant daisies.",
			"thank_you": "Three little choices, and already it's your place. I hope coming home makes your shoulders soften.",
			"target": 3,
			"planet": 0,
			"token": "",
		},
		{
			"type": "visit",
			"title": "The garden next door",
			"request": "Bolt says a tiny flower has appeared near his workshop. Would you visit Rust once after our chat? You needn't bring anything back. I'd just like someone to enjoy his corner of the universe.",
			"reminder": "Take a fresh trip to Rust when you're ready. Even if you've been before, there's always a new little thing to notice.",
			"thank_you": "You went! I love knowing our little worlds have someone wandering between them. It makes the distances feel smaller.",
			"target": 1,
			"planet": 2,
			"token": "",
		},
		{
			"type": "wish",
			"title": "Something small and good",
			"request": "I've been wishing for rain, which is rather practical of me. Would you make a wish at the Commons wishing lawn after our chat? Choose something for yourself. You can keep it secret.",
			"reminder": "Visit the event garden in the Commons and send a little wish from the wishing lawn.",
			"thank_you": "I'll leave a little space in my own wish for yours. No need to tell me what it was.",
			"target": 1,
			"planet": 3,
			"token": "",
		},
		{
			"type": "retrieve",
			"title": "One adventurous seed",
			"request": "My last moonbean seed hitched a ride in Bolt's toolbox. Could you find it on Rust and bring it back? It's a single plump seed. I admire its curiosity, but its pot is ready.",
			"reminder": "The moonbean seed is on Rust. Just the one; it has enough ambition for a whole packet.",
			"thank_you": "Welcome home, little wanderer. And thank you. If it grows toward Rust, we'll know it made a friend there.",
			"target": 1,
			"planet": 2,
			"token": "seed",
		},
	],
	[
		{
			"type": "retrieve",
			"title": "A coil for the watering bot",
			"request": "BEEP. Friendship request! I left a copper coil in the Commons event garden. My watering bot needs it. Could you bring it home?",
			"reminder": "The copper coil is waiting in the Commons event garden. The watering bot is practicing looking helpful meanwhile.",
			"thank_you": "Coil installed. Watering bot delighted. It watered my foot in gratitude. Thank you; the seedlings will appreciate the next attempt.",
			"target": 1,
			"planet": 3,
			"token": "coil",
		},
		{
			"type": "collect",
			"title": "A softer sort of doorbell",
			"request": "My doorbell currently announces visitors like a hull breach. Could you collect three crystals from around Rust? I'd like to build a chime that says hello without alarming the biscuits.",
			"reminder": "Three crystals from around Rust, please. The biscuits have requested a quiet installation.",
			"thank_you": "Ding, ding, dong. Much better. Now a visitor sounds like something to look forward to. You always were.",
			"target": 3,
			"planet": 2,
			"token": "crystal",
		},
		{
			"type": "decorate",
			"title": "Home, with optional symmetry",
			"request": "Workshop advice: a home needs things you like looking at. Have three decorations placed on Clover. Existing ones count, and matching is entirely optional. I own seven different drawer handles.",
			"reminder": "Have three decorations placed at home on Clover. No measuring tape required. I am being very brave about this.",
			"thank_you": "Three decorations in place! Excellent work. A room can be technically complete; a home keeps finding room for you.",
			"target": 3,
			"planet": 0,
			"token": "",
		},
		{
			"type": "visit",
			"title": "Field trip, no clipboard",
			"request": "Lumi recommended looking at something I didn't build. Would you take a fresh trip to Luma after this chat? Consider it research into having a pleasant afternoon. No samples or measurements needed.",
			"reminder": "Visit Luma once after accepting this favor. Previous trips were lovely, but this is a new afternoon.",
			"thank_you": "You made the trip. Good. I'm adding 'go outside and look around' to my maintenance schedule. Right after 'remember to stop working.'",
			"target": 1,
			"planet": 1,
			"token": "",
		},
		{
			"type": "wish",
			"title": "No postage to the stars",
			"request": "I've designed a wish transmitter. Lumi says the Commons wishing lawn already does that. Could you go there and send a little wish after our chat? I'd like to try her method. Fewer screws.",
			"reminder": "Send a little wish at the Commons wishing lawn in the event garden. No equipment required. Still getting used to that.",
			"thank_you": "Wish sent. No tracking number, then. That's all right. Some good things can be on their way without us checking.",
			"target": 1,
			"planet": 3,
			"token": "",
		},
		{
			"type": "retrieve",
			"title": "The missing music-box gear",
			"request": "I dropped a little brass gear while visiting Luma. Could you find it and bring it back? It belongs to my music box, which currently plays three notes and then thinks very hard.",
			"reminder": "One brass gear, somewhere on Luma. The music box and I would both like to know how the tune ends.",
			"thank_you": "There. The whole tune. I made it for quiet evenings, but I think I'd rather hear it with company. Stay for the last verse?",
			"target": 1,
			"planet": 1,
			"token": "gear",
		},
	],
	[
  {
    "type": "collect",
    "title": "Lights for the last delivery",
    "request": "Pip, local courier! My last delivery always arrives after the path goes blue. Could you gather three crystals on Pebble? I'd like to mark the turn beside my moon garden. Yesterday I delivered a letter to a very convincing rock.",
    "reminder": "Three crystals from Pebble, please. The rock has declined further correspondence.",
    "thank_you": "Left at the first glow, home at the third. Perfect! Now I can read the addresses instead of apologizing to the landscape.",
    "target": 3,
    "planet": 4,
    "token": "crystal"
  },
  {
    "type": "visit",
    "title": "A route with a good smell",
    "request": "I'm mapping a route to Miso's bakery on Honey. Would you make a fresh trip there after our chat? I want the route to include a stop worth lingering at. The fastest path isn't always my favorite.",
    "reminder": "Visit Honey once after accepting. Follow the bakery path; you needn't carry anything for me.",
    "thank_you": "You went! I'm drawing a little loaf beside that stop. Maps should tell you where an afternoon gets better.",
    "target": 1,
    "planet": 5,
    "token": ""
  },
  {
    "type": "decorate",
    "title": "An address you can recognize",
    "request": "From orbit, I recognize homes by the things people put outside. Could you have three decorations placed on Clover? The ones already there count. Pick things you like; I'll learn your address from those.",
    "reminder": "Have three decorations placed on Clover. No official mailbox required; I remember the little things.",
    "thank_you": "That's your place! I could find it with the address smudged. A home makes a very good signature.",
    "target": 3,
    "planet": 0,
    "token": ""
  },
  {
    "type": "wish",
    "title": "An envelope without a stamp",
    "request": "I carry other people's hopes in envelopes all day. Will you send a wish of your own at the Commons wishing lawn after our chat? Keep the contents private. Couriers are good at that.",
    "reminder": "Make a fresh wish at the Commons wishing lawn. This delivery doesn't need a satchel.",
    "thank_you": "Off it goes. I keep wanting to check the destination, but this time I'll just watch the sky with you.",
    "target": 1,
    "planet": 3,
    "token": ""
  },
  {
    "type": "visit",
    "title": "Permission to take the scenic route",
    "request": "Lumi says her moonflowers are opening on Luma. Would you take a fresh trip there? I'm practicing putting lovely things on my route even when there's nothing to deliver.",
    "reminder": "Visit Luma after accepting this favor. Looking around is the whole assignment.",
    "thank_you": "You made time for it. Good. I've penciled a garden stop into tomorrow's route. In pen, actually. Being brave.",
    "target": 1,
    "planet": 1,
    "token": ""
  },
  {
    "type": "collect",
    "title": "The return path",
    "request": "I've marked the way into my moon garden, but the return path still disappears at dusk. Could you gather four crystals on Pebble? I'd like guests to stay as long as they want without worrying about finding their boots.",
    "reminder": "Four crystals on Pebble for the return path. I'll put the kettle on while you wander.",
    "thank_you": "There: a way here and a way home. And if you turn around halfway and come back, the kettle will still be warm.",
    "target": 4,
    "planet": 4,
    "token": "crystal"
  }
],
	[
  {
    "type": "collect",
    "title": "A proofing clock that glows",
    "request": "Hello, I'm Miso. The dough rises while I watch the meadow, and sometimes we both forget the time. Could you gather three crystals on Honey? They'll light the little marks on my proofing clock.",
    "reminder": "Three crystals from Honey will help me read the proofing clock. The dough is taking its time.",
    "thank_you": "A soft glow for each mark. Now I can give the dough its full rest without giving it the entire afternoon. Your patience helped this batch.",
    "target": 3,
    "planet": 5,
    "token": "crystal"
  },
  {
    "type": "visit",
    "title": "A baker steps beyond the oven",
    "request": "Pip described Pebble's blue moon garden so carefully I could almost smell it. Would you visit Pebble after our chat? I'd like someone to enjoy it while I mind the oven. Next batch, I'll make time to go myself.",
    "reminder": "Take a fresh trip to Pebble. There's nothing to fetch; this is a little outing.",
    "thank_you": "You saw Pip's corner of the sky. I'm setting out my walking clogs. Bread can cool without an audience.",
    "target": 1,
    "planet": 4,
    "token": ""
  },
  {
    "type": "decorate",
    "title": "Room for breakfast",
    "request": "A loaf tastes different when you eat it somewhere you like. Will you have four decorations placed on Clover? Anything already placed counts. I hope you make a corner where breakfast needn't be hurried.",
    "reminder": "Have four decorations placed on Clover, wherever they feel right to you.",
    "thank_you": "Four things you chose for yourself. That sounds like somewhere worth taking a plate. I'll wrap the bread in a cloth to keep it warm.",
    "target": 4,
    "planet": 0,
    "token": ""
  },
  {
    "type": "wish",
    "title": "The quiet minute before it rises",
    "request": "Between kneading and rising, there's a minute when all you can do is hope. Would you make a wish at the Commons wishing lawn after our chat? Something for you. No need to say it out loud.",
    "reminder": "Send a fresh wish from the Commons wishing lawn. I'll keep a quiet minute here, too.",
    "thank_you": "There. We each left a little room for something good to happen. Mine smells faintly of yeast. Yours can stay a secret.",
    "target": 1,
    "planet": 3,
    "token": ""
  },
  {
    "type": "visit",
    "title": "A bell worth hearing",
    "request": "Bolt told me he's making his workshop doorbell gentler. Could you take a fresh trip to Rust? I like knowing a neighbor has someone coming by, even when nothing needs fixing.",
    "reminder": "Visit Rust once after our chat. You don't need to bring any parts.",
    "thank_you": "A visitor for Bolt! I'll put another bun in tomorrow's basket. He insists crumbs aren't workshop supplies, but they do improve morale.",
    "target": 1,
    "planet": 2,
    "token": ""
  },
  {
    "type": "collect",
    "title": "The late supper window",
    "request": "Sometimes a traveler reaches Honey after I've folded my apron. Could you gather four crystals here? I want to leave a gentle light in the bread window so late arrivals know there's still something saved for them.",
    "reminder": "Four crystals from Honey for the evening window. Late shouldn't have to mean left out.",
    "thank_you": "The window glows like the oven just before dawn. I'll leave a loaf there for whoever needs it. You helped make this place a little more welcoming.",
    "target": 4,
    "planet": 5,
    "token": "crystal"
  }
],
]

# Each friendship tier has twenty variants, so any tier supports a full rotation.
# Lumi notices living things and gradually makes room for the player in her days.
const LUMI_CHATTER = [
	[
		"Hello. I'm Lumi. If you hear a humming sound, it's probably me. The flowers haven't learned the tune yet.",
		"That empty pot is deliberate. I like having room for something I haven't met.",
		"The moonflowers open slowly. I used to check every minute. Now I bring a chair.",
		"I planted a row of silver daisies. They came up in a curve. Apparently they had a better idea.",
		"There's a moth asleep beneath that leaf. I've postponed watering until it wakes.",
		"I name my watering cans. This is Drizzle. The other one leaks, so it's Puddle.",
		"The soil here smells lovely after rain. I wish I could put some of that smell in a letter.",
		"I found a pebble shaped like a seed. Planted it before I noticed. Nothing yet.",
		"Some plants like shade. It took me a while to understand that helping isn't always adding more sunshine.",
		"That flower leans toward the workshop lights. Perhaps it likes listening to Bolt work.",
		"I keep the fallen petals. They're rather good bookmarks, provided the book doesn't mind a little yellow.",
		"My garden labels washed clean in the rain. We're all getting reacquainted.",
		"I came outside to do one thing. Then a beetle crossed the path. I can't remember the thing.",
		"The smallest sprout gets its own stick. Being little is enough work without falling over.",
		"I tried counting the stars once. Lost my place when I sneezed. They were very gracious about it.",
		"There's a patch here where nothing grows. For now, it's where I put my feet.",
		"Moonberry tea goes purple if you leave it too long. I keep forgetting, so purple must be my favorite.",
		"A seed packet says 'easy to grow.' I hope the seeds haven't read it. That's a lot of pressure.",
		"The garden gate squeaks in the wind. I think of it as the garden clearing its throat.",
		"You can look around. Mind the low branch; it introduces itself rather suddenly.",
	],
	[
		"Oh, hello again. I recognized your footsteps before I looked up. You pause at the flowers.",
		"I saved you a moonberry. Then I worried one was a silly amount, so now there's a bowl.",
		"Your little world is easy to spot from here. I find myself looking for it when I water.",
		"The daisies survived my pruning. I celebrated by leaving them completely alone this morning.",
		"Bolt fixed my gate. I miss its squeak a little, but now I can hear you say hello.",
		"I found another pebble seed. This one's on the windowsill. We're trying a less agricultural friendship.",
		"If you ever need a quiet minute, the shade beside the tall pot is particularly good today.",
		"The moth is back. I told it we have a new neighbor. It seemed pleased, though it's hard to tell.",
		"I made too much tea. This used to be a problem. Lately someone lovely tends to walk past.",
		"That bent flower has straightened a little. I've been wanting to tell someone who would notice.",
		"I tried drawing Clover in my garden notebook. It looks like a pea wearing a house. Affectionately.",
		"You're welcome to stop without having a favor to do. The path is for wandering, too.",
		"I left a gap beside the bench for muddy boots. Mine already occupy most of it. We'll manage.",
		"The moonberries ripen unevenly. A very good excuse to take the same walk tomorrow.",
		"I heard your rocket and put the kettle on. Even if you're just passing, tea is never wasted.",
		"The garden looks different when I show it to you. I remember to look up from the weeds.",
		"I tried Bolt's advice about lining up the pots. They looked like they were waiting for an inspection.",
		"There's a new bud by the gate. No grand announcement; I just thought you'd like to know.",
		"I used to wave at every passing light. It's nice having someone particular to wave at.",
		"The path isn't finished, but you don't have to wait for an invitation. Gardens are always in the middle of something.",
	],
	[
		"There you are. I was just saving a story about a very determined snail for you.",
		"Your cup is beside mine. I stopped putting it away because you coming back feels likely now.",
		"I had a gloomy morning. Nothing to fix. It's already easier with you standing here.",
		"I showed the moonflowers your favorite corner. They didn't answer, but several are leaning that way.",
		"Would you sit a moment? We can let the kettle finish talking before either of us starts.",
		"I've started writing your visits in my notebook. Between planting dates. Both seem worth remembering.",
		"That bare patch worried me for weeks. Yesterday we stood there laughing. Perhaps it's growing something after all.",
		"I saved the first ripe moonberry for you. Then I ate the second, purely to check.",
		"I like that you ask about the crooked daisy. Most people notice the biggest flowers first.",
		"The sky looked like your suit this morning. It made getting out of bed a little easier.",
		"I told Bolt you would understand my collection of interesting sticks. Please don't make me sound overconfident.",
		"When something blooms, you're one of the people I want to tell. Even when it's a very small bloom.",
		"You can tell me about an ordinary day. I like knowing which little things happened to you.",
		"I've moved the bench so we can both see Clover. It was worth the astonishing amount of grunting.",
		"I used to practice what to say before visitors arrived. With you, I usually just say where the biscuits are.",
		"A storm flattened the tall flowers. I nearly cried. Then I thought we might prop them up together.",
		"You remembered the moth's leaf. That was such a small kindness. I kept thinking about it afterward.",
		"Some days I only water half the garden. I trust you enough to tell you that.",
		"I've been keeping the oddest fallen petals to show you. This one looks exactly like Bolt's worried face.",
		"Stay until the moonflowers open if you have time. I know their trick, but I still like sharing it.",
	],
	[
		"I put your cup out without thinking. You're part of how the table looks now.",
		"The garden can wait a little. Tell me how you are, before we start talking about what needs doing.",
		"I used to call that the spare chair. Now I catch myself calling it yours.",
		"You don't have to be cheerful here. There's room on the bench for whatever sort of day you've brought.",
		"I found a moonbean sprout growing toward Clover. I told it I understood the impulse.",
		"My favorite part of your visits is when we both forget they're visits and just get on with the afternoon.",
		"I left the last biscuit for you. Then I took a very small corner. That's the whole confession.",
		"When I imagine next spring, you're in it. Usually disagreeing with me about whether we need another pot.",
		"The quiet feels different with you here. I don't keep wondering whether I ought to fill it.",
		"Do you remember when you first came through the gate? I fussed with the same leaf for the entire conversation.",
		"If every flower forgot to bloom this week, I'd still have a reason to set two chairs outside.",
		"I have good news and ridiculous news. You're getting both. That's the privilege of knowing me this well.",
		"I nearly sent you a note saying 'the moth is back.' Then I realized I could just save you a seat.",
		"You know where the tea is. I'll be there in a moment; this seedling has caught my sleeve.",
		"I don't tidy away the unfinished things before you come now. I like being known in the middle of a day.",
		"I made a wish for lots more ordinary afternoons together. Nothing spectacular. Just enough tea and time.",
		"You once said that little flower was lovely. I remember every time I walk past it.",
		"The notebook has more stories about us than planting instructions now. The garden seems to be managing.",
		"If you move the chair, leave it where you're comfortable. I want this corner to fit you, too.",
		"Oh, it's you. Good. I had nothing planned, and you're my favorite person to do that with.",
	],
]

# Bolt starts with workshop observations and learns to say what company means.
const BOLT_CHATTER = [
	[
		"Greetings. I'm Bolt. Workshop rule one: if something whistles, it may be the kettle. Please check before applauding.",
		"This drawer contains spare parts. The other drawer contains parts whose purpose I am still respecting from a distance.",
		"I built a stool with three legs. Very stable. I built the next one with five. Excessively confident.",
		"The watering bot has learned to avoid puddles. A curious ambition for a watering bot.",
		"I sort screws by size, except that one. It has earned a private compartment by being mysterious.",
		"Today's repair list: tighten the gate, mend the lamp, locate the repair list. One item complete.",
		"My clock runs a little slow. It gives afternoons room to breathe. That is my current explanation.",
		"The antenna picks up three stations and somebody humming. I prefer the humming.",
		"I made a biscuit dispenser. It dispenses one biscuit unless you look sad. Then the mechanism becomes generous.",
		"A good hinge is easy to overlook. I try to compliment them during maintenance.",
		"That machine does nothing yet. It does it very reliably.",
		"I tested a self-stirring cup. Tea successful. Table unexpectedly fragrant.",
		"Lumi gave me a plant with no instruction manual. Apparently the plant didn't get one either. We are collaborating.",
		"The workshop lamp flickers when I sing. Electrical fault or music criticism. Investigation ongoing.",
		"I keep a box labeled 'probably useful.' It has become structurally important to the workshop.",
		"My new wrench has a comfortable handle. I have been finding unnecessary things to tighten.",
		"There is no such thing as a spare spring until you have checked where it came from. Learned that sitting down.",
		"I tried polishing the old toolbox. It looked startled. I left a few scratches so it would recognize itself.",
		"The wind chime needs tuning. Currently it sounds like teaspoons having a small disagreement.",
		"Mind the cable near the door. It is temporary. It has been temporary for some time.",
	],
	[
		"Returning neighbor detected. Hello again. I've moved the temporary cable. You inspired an actual deadline.",
		"I adjusted the doorbell volume. Visitors should receive a welcome, not a launch countdown.",
		"The biscuit dispenser recognizes you now. By which I mean I put an extra biscuit in it.",
		"I can spot Clover through the workshop window. Useful for remembering that work is not the entire universe.",
		"Lumi's plant has a new leaf. I checked twice. Nothing was plugged in. Remarkable.",
		"If you hear a pleasant little chime later, the repair worked. If you hear cutlery, please be encouraging.",
		"I made room for a second cup on the workbench. Several screws have lodged a complaint.",
		"You can drop by without anything broken. I am developing procedures for that. Biscuits feature prominently.",
		"I repaired a garden lamp today. Left the tiny dent. Lumi said that's where she recognizes it.",
		"That stool is safe to use. I've sat on it myself. The cushion is a recent and excellent discovery.",
		"I've been testing softer alarm sounds. Current favorite: someone gently saying that the toast is ready.",
		"Your rocket has a familiar note now. I looked up before the window rattled.",
		"I put labels on the tea tins. One says 'the nice one.' Still gathering useful specifications.",
		"The watering bot followed me home. Technically expected. Nevertheless, I felt rather chosen.",
		"I tried taking a break at the Commons. Did not improve any machinery. May repeat.",
		"There are two finished jobs on my list today. I'm telling you before I notice another loose hinge.",
		"I found a blue screw. No idea what it fits, but I thought you might like the color.",
		"The music box can play a whole verse now. You're welcome to hear it while I pretend not to watch your reaction.",
		"I added 'say hello to the neighbors' to my schedule. It keeps being the easiest item to finish.",
		"An uneventful visit is still a successful visit. I have revised my definition of an event.",
	],
	[
		"Ah, you. I have a small triumph to report and nobody else would appreciate quite how small.",
		"Your cup has a hook now. Permanent installation. I measured it twice because it mattered.",
		"I nearly worked through the afternoon again. Then I remembered you might visit and actually sat down.",
		"That rattle has defeated me today. Could we talk about your day while I stop hearing it in my head?",
		"I trust your opinion on the music box. Even if the opinion is 'perhaps slightly less music.'",
		"I saved a crooked little gear to show you. Nothing fits it. I like it anyway. Personal growth, possibly.",
		"The watering bot greeted you before me. Excellent judgment. Slightly disappointing loyalty.",
		"You laughed at my hinge joke last time. I've been trying not to overuse this information.",
		"I used to clear the workbench before visitors. You know which piles are safe to lean on now.",
		"I've found that tea takes exactly long enough for a good conversation to begin. Sensible design.",
		"A repair went badly this morning. I was going to tell you only about the good ones. That seemed unnecessary with you.",
		"I can ask you to pass a wrench without pointing. We are becoming a very efficient pair of people drinking tea.",
		"Lumi says I hum more lately. I blamed the fan belt. It was not a convincing diagnosis.",
		"I've kept your last visit off the repair log. Some things deserve a page without checkboxes.",
		"If you'd like to sit quietly, I can do quiet. The workshop may need a little persuasion.",
		"I moved the lamp so it lights both chairs. Surprisingly satisfying piece of engineering.",
		"When something works at last, I still look toward the door as though you might be there to see it.",
		"I baked biscuits. They are individually unusual. I thought we could investigate the best ones together.",
		"You never make me feel silly for caring about a little machine. Thank you for that.",
		"I have no useful task for you today. I'd still be very glad if you stayed.",
	],
	[
		"There you are. I've put the tools down. Whatever needs fixing can wait until I've heard how you are.",
		"I call it your chair now. No formal naming ceremony. Just happened halfway through sweeping.",
		"You can arrive with a bad day and no explanation. I'll start with the kettle. We can work outward from there.",
		"I tried calculating how much better your visits make the afternoon. Abandoned the numbers. The answer was obvious.",
		"The workshop is still cluttered, but there's always room for you. I keep making sure of that.",
		"Remember the copper coil? I thought you were bringing back a component. Turned out you kept coming back yourself.",
		"I don't rehearse saying this anymore: I missed you. Also, the biscuits. But mostly you.",
		"When I plan something for next season, I leave room for your opinion. Even on the drawer handles.",
		"My favorite sound in the workshop used to be a motor starting. These days it's your hello.",
		"Nothing on today's schedule. I left it that way in case we wanted to do something entirely unproductive.",
		"I made a terrible little tune. You get the first performance and permission to laugh. Both are privileges.",
		"You know which cupboard sticks. You know when I'm worried. I find both facts unexpectedly comforting.",
		"I was going to tidy before you arrived. Then I realized I'd rather spend the time with you.",
		"The music box plays better with someone listening. Yes, technically identical notes. I'm keeping my observation.",
		"If you need help, you don't have to arrive with a plan. We can sit beside the problem for a while first.",
		"I keep the old coil wrapper in my toolbox. Not useful. Just the beginning of a good story.",
		"You can tell me the same story again. I like the bit where you start smiling before the ending.",
		"Lumi asked what I wished for. More afternoons like this. I briefly considered a new drill, but no.",
		"I've learned to leave a job unfinished when it's time for tea with you. Nothing has fallen apart. Quite the opposite.",
		"You don't have to earn your seat here. It's yours on the quiet days, too.",
	],
]


const PIP_CHATTER = [
  [
    "Hello! Pip. Courier, explorer, occasional retriever of my own hat.",
    "My satchel has seven pockets. The important one is whichever I haven't checked.",
    "Pebble looks blue from orbit. Up close it has seventeen kinds of blue and one stubborn yellow flower.",
    "I drew a shortcut on my map. Then I walked it. It's a longcut now.",
    "The antenna isn't for reading thoughts. Mostly it tells me when my hood is caught on a branch.",
    "I carry blank postcards in case the view has something to say.",
    "A letter weighs almost nothing. Funny how carefully you want to hold it.",
    "I label interesting rocks by where I found them. This one is called Inside My Boot.",
    "The moon garden is my landing checklist's final item: stop and look.",
    "My first delivery went around the same moon twice. The letter enjoyed the scenery.",
    "I use a blue pencil for paths and a gold one for places to sit.",
    "Someone addressed a parcel to the nice robot. I had to ask which one.",
    "My helmet makes a tiny echo when I sneeze. Very grand for such a small event.",
    "I packed a compass and three biscuits. Used the biscuits first.",
    "The flowers here close when my shadow passes. I try to walk politely.",
    "There's no north in my satchel. Everything migrates to the bottom.",
    "I once mailed myself a reminder. Lovely to get a letter; forgot what I was reminding myself about.",
    "A good landing is one where the sandwiches stay sandwiches.",
    "I have a stamp shaped like a comet. All my receipts look terribly exciting.",
    "You can wave with both hands here. The gravity gives enthusiasm a little extra time."
  ],
  [
    "I recognized your landing! Your rocket does a little settling sigh.",
    "I've marked Clover in gold now. That's my color for stops I like.",
    "There's a postcard in my pocket for you. Blank, but the intention is very specific.",
    "Miso tucked a bun into my satchel. Everything smells like a successful delivery.",
    "I tried walking my route without checking the map. Found a bench I'd been walking past.",
    "You're welcome in the moon garden. The blue stones are for sitting on, except the wet one.",
    "I found your world through a gap in the flowers. It felt like a window had appeared.",
    "Bolt reinforced my bag clasp. I can carry considerably more unnecessary pebbles.",
    "I keep almost telling you things over the radio before remembering I haven't fitted yours.",
    "A route feels shorter when there's somebody to say hello to at the end.",
    "I saved a particularly round rock for you to inspect. No obligation to be impressed.",
    "My map has a tea stain beside Luma. Lumi says that's accurate.",
    "I delivered everything early today. I'm trying not to fill the spare time with more errands.",
    "That yellow flower opened another petal. You're caught up on the local news.",
    "I put a cushion on the garden step. It's a very small guest room for your feet.",
    "Your address is the one I don't have to look up anymore.",
    "I tried sketching your rocket. The wings came out uneven. It looks pleased with itself.",
    "If I wave while you're taking off, that's goodbye and have a lovely time, both at once.",
    "The satchel's newest pocket is for things I want to show you.",
    "I like that you look at the map with me instead of asking whether I'm lost."
  ],
  [
    "I took the scenic route home because I thought you might be on it.",
    "You can hold the map. I trust the way you notice things.",
    "A parcel went astray this morning. It's found now, but I could use an ordinary conversation.",
    "I've started leaving gaps in my route for afternoons like this.",
    "The moon garden is quiet today. Want to test how long we can hear one pebble roll?",
    "I used to think explorers always knew where to go next. It's a relief to tell you I don't.",
    "I brought two biscuits, and neither is emergency equipment.",
    "Your last postcard is in the pocket nearest my heart. Also nearest the spare pencil.",
    "I nearly radioed the whole neighborhood when that yellow flower seeded. Thought I'd tell you first.",
    "My boots are dusty and my route is done. This is the best part of coming back.",
    "I can say I had a lonely trip without you making it into another assignment.",
    "Let's choose a spot on the map because the name sounds nice.",
    "Miso asked why I take so long near Clover. I told the truth. Nice neighbor.",
    "I've drawn us beside the garden. We're both mostly helmets, but the smiles are accurate.",
    "If your day took a wrong turn, you can stop here before deciding what's next.",
    "I don't mind getting lost with you. I still mind losing the biscuits.",
    "That rock you liked is by the door now. It finally has an address.",
    "I tell the flowers about my route. Lately your name comes up quite a bit.",
    "You noticed my repaired strap. I like not having to point out every little story.",
    "Stay while I sort the letters? You don't have to help. I just like the company."
  ],
  [
    "There you are. Route finished. Tell me everything that happened between our hellos.",
    "I don't write return to sender on your things. I know you'll be back for them.",
    "The map is getting crowded with places we've sat together.",
    "I used to measure a trip in distance. Now I remember who was waiting at the end.",
    "You can borrow my favorite pencil. Yes, the gold one. That's a serious arrangement.",
    "I kept the wrinkled postcard. It survived the rain and still said you were thinking of me.",
    "No deliveries today. Shall we go somewhere with no reason to hurry?",
    "Your seat in the moon garden has acquired a little moss. Very soft. Thoughtful of it.",
    "I know your footsteps even through the helmet. That seems like a lovely use of technology.",
    "If you can't find the words, stay anyway. I've delivered plenty of blank postcards.",
    "We can take the familiar path again. I like seeing what you notice this time.",
    "My satchel is lighter with the letters gone. My afternoon is better with you here.",
    "I leave a gap beside my boots now. Yours fit there beautifully, mud included.",
    "I wished for a safe journey for you. Then for a reason to make one together.",
    "Sometimes I look at Clover just to remind myself you're nearby.",
    "I don't have to be the cheerful courier every minute with you. Thank you for that.",
    "Remember the convincing rock? I still wave. It was there at the beginning.",
    "I put our favorite bench on every edition of the map. Some landmarks are permanent.",
    "Your hello is the part of the route I could find with my eyes closed.",
    "Let's stay until the garden turns silver. I'll put tomorrow's map away."
  ]
]


const MISO_CHATTER = [
  [
    "I'm Miso. Baker. If there's flour on my face, please consider it part of the recipe.",
    "My cap has an orbit. The crumbs occasionally attempt one too.",
    "Honey's meadow smells sweet at dawn. I open the window before I open the flour tin.",
    "I can measure a gram perfectly. A pinch remains a wonderful mystery.",
    "The first bun is for checking. The second is to make sure the first wasn't a fluke.",
    "I made square rolls once. They looked like they had somewhere important to be.",
    "My apron pocket contains a spoon and a very small recipe I can't read without unfolding it.",
    "Bread rises more slowly when I stare. Probably. The research is delicious.",
    "The oven clicks twice when it's ready. I always answer.",
    "I named my sourdough starter Mildred. We have a demanding but productive friendship.",
    "That loaf leans left. The flavor remains centrally located.",
    "I cool buns on the windowsill. The breeze has excellent taste.",
    "Being made of metal doesn't keep my fingers from feeling buttery.",
    "I tried piping stars onto a cake. Discovered several new constellations.",
    "My timer plays three notes. I hum the fourth while I find the oven mitts.",
    "A recipe says knead until smooth. It doesn't specify whether humming helps, so I do.",
    "I keep the broken biscuits in a tin marked beautiful fragments.",
    "The meadow herbs grow toward the kitchen. I appreciate their initiative.",
    "A warm loaf makes a paper bag crackle in a particularly friendly way.",
    "Mind the cooling shelf. The bread has finished baking but hasn't finished being proud."
  ],
  [
    "Hello again. I put a little extra butter out when I heard your rocket.",
    "I remember how you paused at the bread window. That's a very kind review.",
    "Pip delivers the flour with a weather report from every world on the way.",
    "I tried a new glaze. It sticks to the bun and absolutely everything else.",
    "You're welcome before the first batch is ready. Morning is more than bread.",
    "The meadow has daisies today. I put one beside the recipe stand.",
    "Bolt made the timer quieter. Now it sounds like someone clearing their throat about cake.",
    "I've begun baking one more roll than I need. It keeps finding a good home.",
    "Would you believe the crooked loaf sold first? I like remembering that.",
    "I caught myself saving the funniest kitchen mistake to tell you.",
    "There's a stool by the window. Its legs don't match, but they agree on holding you up.",
    "I tried taking my tea outside. Discovered the meadow is larger than the view from the sink.",
    "Your visits tend to land between batches. Or perhaps I notice those minutes more now.",
    "I drew a flower in the flour dust. Sweeping can wait until you've seen it.",
    "Lumi brought herbs. I sent the pot back with a biscuit where the plant had been.",
    "I keep a clean cloth ready for unexpected picnics. It's a hopeful sort of laundry.",
    "The oven is resting. I should copy its example more often.",
    "I learned your hello before I learned your favorite bread. Both are useful things to know.",
    "If the window's open, you can call in. Unless I'm singing; then be merciful.",
    "A quiet bakery with someone visiting still feels nicely busy."
  ],
  [
    "I saved the end slice. You can have it, or we can argue politely over who should.",
    "A batch burned this morning. I've aired the kitchen. Talking to you helps with the rest.",
    "You know which stool wobbles now. That's practically a key to the bakery.",
    "I tried your suggestion. The recipe card has your name in the margin.",
    "Some days I need a rest before the dough does. I'm learning to allow it.",
    "I've put two cups on the shelf nearest the kettle. It makes sense lately.",
    "The best thing I made today might be time to sit with you.",
    "I was going to hide the lopsided cake. Then I thought you'd enjoy its confidence.",
    "Tell me about your day while I fold this cloth. I can listen with my hands busy.",
    "Pip says my window looks warm from orbit. I hope it feels that way from here.",
    "I don't check the timer quite so anxiously when you're around.",
    "I made a little recipe book for experiments. The successful ones get stars; the others get stories.",
    "You never rush the first bite. A baker notices that.",
    "I had no particular reason to make your favorite. Wanting to seemed enough.",
    "The meadow was all gold this morning. I wished you were standing beside me.",
    "You can say you're tired. There are no orders to fill on this stool.",
    "I left flour on the counter because we were talking. It was a good choice.",
    "My cap slipped into the mixing bowl. You get the honest account before I improve the story.",
    "I can tell you when a recipe scares me now. I don't have to look perfectly calibrated.",
    "Let's split this bun before I invent an excuse to give you all of it."
  ],
  [
    "Hello, you. The kettle is on and your place is clear.",
    "I've stopped calling it the visitor's stool. It's yours, even when you're away.",
    "You can come here with a difficult day. We can start with something warm to hold.",
    "The recipe book opens to our favorite page by itself now.",
    "I used to bake extra just in case. These days I call it your portion.",
    "Remember the proofing clock? Every little glow reminds me how this started.",
    "I've learned that company doesn't have to admire every batch. Sometimes it just helps wash the bowl.",
    "If we sit here long enough, the next loaf will be ready. Excellent planning on our part.",
    "You know the flour on my cheek before I do. I feel very well looked after.",
    "I saved you a story and a slightly overdone biscuit. Both improve with tea.",
    "The meadow can be our dining room tonight. I'll bring the cloth with the stubborn jam stain.",
    "There is room for your recipe in my book. Even if the instructions begin with guessing.",
    "I don't tidy the whole bakery before you come. I want to spend that time hearing you laugh.",
    "Your cup has a chip. Shall we keep it? I know exactly where my thumb fits on mine.",
    "I wished for more mornings with people I love at the window. You're in that wish.",
    "When a new loaf works, I imagine your first bite before I write down the recipe.",
    "We can be quiet while the bread cools. It will do enough crackling for all of us.",
    "I thought home was the place with my oven. You've made the definition a little bigger.",
    "There you are. Nothing you need to do. I've already put the butter out.",
    "I'll walk you to your rocket after tea. Unless tea turns into supper again."
  ]
]


static func quest(who: int, round: int) -> Dictionary:
	var neighbor: int = clampi(who, 0, NAMES.size() - 1)
	var cycle: int = maxi(round, 0) % QUESTS[neighbor].size()
	# Return an independent record, so a caller cannot alter future quest text.
	return QUESTS[neighbor][cycle].duplicate(true)


static func chatter(who: int, friendship: int, variant: int) -> String:
	var lines: Array = [LUMI_CHATTER, BOLT_CHATTER, PIP_CHATTER, MISO_CHATTER][clampi(who, 0, NAMES.size() - 1)]
	var tier: Array = lines[_friendship_tier(friendship)]
	return tier[posmod(variant, tier.size())]


static func friendship_name(points: int) -> String:
	return ["Stranger", "Neighbor", "Friend", "Besties"][_friendship_tier(points)]


static func milestone(points: int) -> String:
	# These are narrative unlocks; this data module grants no gameplay rewards.
	match points:
		0:
			return "A new face, a little wave. Every friendship here begins with a hello."
		1:
			return "Neighbor: your footsteps are familiar now. Drop by for workshop news, garden discoveries, and another little favor."
		3:
			return "Friend: a cup is kept for you. Your neighbor shares the unfinished projects and difficult days as well as the good news."
		6:
			return "Besties: the spare chair has become your chair. You're part of future plans, favorite stories, and afternoons that need no occasion."
	return ""


static func _friendship_tier(points: int) -> int:
	if points >= 6:
		return 3
	if points >= 3:
		return 2
	if points >= 1:
		return 1
	return 0
