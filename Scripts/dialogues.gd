class_name Dialogues
## All of Orbi's conversations, keyed by id. A conversation is a list of lines:
##   mood    - "neutral" | "happy" | "sad" | "anger"
##   text    - what Orbi says
##   image   - optional res:// path of a picture shown under the bubble
##   caption - optional text beside the picture (e.g. a source)
##
## Task conversations use the task id as their key, so World can play them
## automatically when that task completes.

const ALL := {
	&"water_garden": [
		{
			mood = "happy",
			text = "Great watering! Plants need just the right amount of water. Too much, and their roots can't breathe!",
		},
		{
			mood = "neutral",
			text = "Astronauts already grow food in space! NASA's Veggie garden on the Space Station has grown lettuce that the crew got to eat.",
			image = "res://Assets/plants.png", # placeholder until we have a real photo
			caption = "Source: NASA",
		},
		{
			mood = "happy",
			text = "Keep our garden happy and one day it could feed the whole base!",
		},
	],

	# --- sleep ---
	&"sleep": [
		{
			mood = "happy",
			text = "Good morning! It's 8 AM, time for a new day on Mars.",
		},
		{
			mood = "neutral",
			text = "Did you know? A day on Mars is called a sol, and it's about 40 minutes longer than a day on Earth!",
			caption = "Source: NASA",
		},
		{
			mood = "happy",
			text = "A rested crew member is a careful crew member. Let's see what the base needs today!",
		},
	],
	&"sleep_locked": [
		{
			mood = "neutral",
			text = "Bedtime already? The plants are still thirsty! Let's water the garden first.",
		},
	],
	&"sleep_not_tired": [
		{
			mood = "happy",
			text = "You just woke up, sleepyhead! There's work to do.",
		},
	],

	# --- solar panels (day 2) ---
	&"fix_solar_intro": [
		{
			mood = "anger",
			text = "Uh-oh! Do you see the lights flickering? Our power is running low!",
		},
		{
			mood = "sad",
			text = "Mars dust settles on our solar panels, like a blanket blocking the Sun. Covered panels can't make electricity.",
		},
		{
			mood = "neutral",
			text = "This is urgent! Head out the west exit. The solar panels are just outside, south of the base.",
		},
	],
	&"fix_solar": [
		{
			mood = "happy",
			text = "The lights are back! Great job, engineer!",
		},
		{
			mood = "neutral",
			text = "Dust is a real problem on Mars. NASA's InSight lander had to stop working in 2022 because its solar panels got too dusty.",
			caption = "Source: NASA",
		},
		{
			mood = "happy",
			text = "But we have you! Clean panels mean power for the lights, the air and the garden.",
		},
	],
	&"solar_ok": [
		{
			mood = "happy",
			text = "The solar panels look clean and shiny today. Nothing to fix!",
		},
	],

	# --- world border ---
	&"border_warning": [
		{
			mood = "anger",
			text = "Hey, hey! Where do you think you're going? Come back!",
		},
		{
			mood = "sad",
			text = "You're the only crew member at the base right now. If you get lost out there, nobody will be left to take care of it.",
		},
		{
			mood = "neutral",
			text = "Mars can have dust storms so big they cover the whole planet! That's why we never wander far from the base.",
			caption = "Source: NASA",
		},
		{
			mood = "happy",
			text = "The base needs you! Let's head back and keep it running.",
		},
	],

	&"border_return": [
		{
			mood = "sad",
			text = "Phew... you went too far out there, so I guided you back to the base.",
		},
		{
			mood = "neutral",
			text = "That trip cost us a few minutes. Let's stay close and take care of the base!",
		},
	],

	# --- watering failures (id = task id + "_" + minigame reason) ---
	&"water_garden_overflow": [
		{
			mood = "anger",
			text = "Whoa, whoa! That's way too much water! Now the soil is all soggy.",
		},
		{
			mood = "sad",
			text = "Roots need air too. When soil is flooded, the water pushes the air out and the roots can't breathe.",
		},
		{
			mood = "neutral",
			text = "Water is super precious on Mars, so let's not waste it. Try again, and keep the pour in the green!",
		},
	],
	&"water_garden_too_slow": [
		{
			mood = "sad",
			text = "Oh no... the plants are still thirsty. Just a few drops won't be enough for them.",
		},
		{
			mood = "neutral",
			text = "Did you know? Astronauts on the Space Station recycle about 98% of their water. Even sweat gets cleaned and reused!",
			caption = "Source: NASA",
		},
		{
			mood = "happy",
			text = "So we have water to give! Pour a little faster next time. You've got this!",
		},
	],
}

static func get_lines(id: StringName) -> Array:
	return ALL.get(id, [])
