class_name OrbitCatalog
extends RefCounted

const NAMES = ["Mooncap lamp", "Pocket constellation", "Botanical bot", "Stargazer bench", "Hello-universe antenna", "Cosmic blooms", "Lunar reading nook", "Orbit tea table", "Satellite birdbath", "Cloud cushion", "Meteor mailbox", "Solar garden arch", "Moonberry basket", "Comet lantern", "Tiny observatory", "Robot music box", "Stardust picnic", "Crystal terrarium"]
const PRICES = [15,20,18,24,16,12,32,26,28,14,18,36,12,20,40,30,26,24]
const RADII = [0.45,0.45,0.5,0.85,0.4,0.7,0.85,0.65,0.5,0.5,0.45,1.0,0.45,0.4,0.7,0.55,0.95,0.6]
const DESCRIPTIONS = ["A warm little pool of moonlight.", "Five points. A thousand wishes.", "Always remembers to water itself.", "Save a seat for someone lovely.", "For messages from very far away.", "A patch of color from another world.", "A soft place for one more chapter.", "Tea tastes better under the stars.", "A splash of hospitality for space birds.", "For landing after a very long day.", "A cheerful home for handwritten hellos.", "A doorway into your growing garden.", "A basket of perfectly peculiar fruit.", "Carry a little evening wherever you go.", "The whole sky, just outside your door.", "A tiny tune with a very big heart.", "Bring snacks. Stay until moonrise.", "A little universe beneath the glass."]
const SUIT_NAMES = ["Coral sunrise", "Seafoam explorer", "Lavender evening", "Golden hour", "Cosmic blue", "Rose quartz"]
const SUIT_COLORS = [Color("f19b84"),Color("9edbd0"),Color("bba6e3"),Color("dfbf70"),Color("7faad8"),Color("d894ae")]

static func entry(kind:int, count:int=0) -> Dictionary:
	return {"kind":kind,"name":NAMES[kind],"count":count,"price":PRICES[kind],"description":DESCRIPTIONS[kind]}

static func entries(inventory:Array=[]) -> Array:
	var result:Array = []
	for i in range(NAMES.size()):
		result.append(entry(i,int(inventory[i]) if i<inventory.size() else 0))
	return result
