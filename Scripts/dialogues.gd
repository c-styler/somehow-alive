class_name Dialogues
## All of Orbi's conversations, keyed by id. A conversation is a list of lines:
##   mood    - "neutral" | "happy" | "sad" | "anger"
##   text    - what Orbi says
##   image   - optional res:// path of a picture shown under the bubble
##   caption - optional text beside the picture (e.g. a source)
## Lines are in Modern Standard Arabic (shown right-to-left by OrbiDialog).
## Text can use {time} (e.g. "6:00 صباحًا") and {day} (e.g. "2"); World fills them in from
## the real clock when the line plays, so dialogue never disagrees with the HUD.
##
## Task conversations use the task id as their key, so World can play them
## automatically when that task completes.

const ALL := {
	&"water_garden": [
		{
			mood = "happy",
			text = "أحسنت السقي! تحتاج النباتات إلى كمية مناسبة تمامًا من الماء، فإذا زادت لا تستطيع جذورها التنفس!",
		},
		{
			mood = "neutral",
			text = "رواد الفضاء يزرعون الطعام في الفضاء فعلًا! فقد نما الخسّ في حديقة «فيجي» التابعة لناسا على متن محطة الفضاء الدولية، وتناوله الطاقم.",
			image = "res://Assets/plants.png", # placeholder until we have a real photo
			caption = "المصدر: ناسا",
		},
		{
			mood = "happy",
			text = "اعتنِ بحديقتنا جيدًا، وقد تُطعم القاعدة كلها يومًا ما!",
		},
	],

	# --- sleep ---
	&"sleep": [
		{
			mood = "happy",
			text = "صباح الخير! الساعة الآن {time}، حان وقت يوم جديد على المريخ.",
		},
		{
			mood = "neutral",
			text = "هل تعلم؟ يُسمّى اليوم على المريخ «سول»، وهو أطول من يوم الأرض بنحو 40 دقيقة!",
			caption = "المصدر: ناسا",
		},
		{
			mood = "happy",
			text = "فرد الطاقم المرتاح فردٌ حريص. لنرَ ما تحتاج إليه القاعدة اليوم!",
		},
	],
	&"sleep_locked": [
		{
			mood = "neutral",
			text = "حان وقت النوم بالفعل؟ ما زالت النباتات عطشى! لنسقِ الحديقة أولًا.",
		},
	],
	&"sleep_locked_fix_solar": [
		{
			mood = "anger",
			text = "لا يمكننا النوم والطاقة منخفضة هكذا! تحتاج المدافئ وأجهزة الهواء إلى الكهرباء طوال الليل.",
		},
		{
			mood = "neutral",
			text = "أصلح الألواح الشمسية أولًا. إنها خارج المخرج الغربي مباشرةً، جنوب القاعدة.",
		},
	],
	&"sleep_not_tired": [
		{
			mood = "happy",
			text = "لقد استيقظت للتو أيها الكسول! هناك عمل ينتظرنا.",
		},
	],

	# --- solar panels (day 2) ---
	&"fix_solar_intro": [
		{
			mood = "anger",
			text = "أوه لا! هل ترى الأضواء ترمش؟ طاقتنا توشك على النفاد!",
		},
		{
			mood = "sad",
			text = "غبار المريخ يتراكم على ألواحنا الشمسية مثل بطانية تحجب الشمس، والألواح المغطّاة لا تستطيع إنتاج الكهرباء.",
		},
		{
			mood = "neutral",
			text = "هذا أمر عاجل! اخرج من المخرج الغربي، فالألواح الشمسية خارج القاعدة مباشرةً من جهة الجنوب.",
		},
	],
	&"fix_solar": [
		{
			mood = "happy",
			text = "عادت الأضواء! عمل رائع أيها المهندس!",
		},
		{
			mood = "neutral",
			text = "الغبار مشكلة حقيقية على المريخ؛ فقد توقف مسبار «إنسايت» التابع لناسا عن العمل عام 2022 لأن الغبار غطّى ألواحه الشمسية.",
			caption = "المصدر: ناسا",
		},
		{
			mood = "happy",
			text = "لكننا محظوظون بوجودك! الألواح النظيفة تعني طاقة للأضواء والهواء والحديقة.",
		},
	],
	&"solar_ok": [
		{
			mood = "happy",
			text = "تبدو الألواح الشمسية نظيفة ولامعة اليوم. لا شيء يحتاج إلى إصلاح!",
		},
	],

	# --- sunset selfie (day 1, 18:00) ---
	&"window_selfie_intro": [
		{
			mood = "happy",
			text = "انظر إلى الساعة، إنها {time}! الشمس تغرب، وغروب الشمس على المريخ مميّز جدًا.",
		},
		{
			mood = "neutral",
			text = "هناك نافذة دائرية في القاعة الكبيرة شرق القاعدة. هيا نلتقط صورة لكل من ينتظرنا على الأرض!",
		},
	],
	&"window_selfie": [
		{
			mood = "happy",
			text = "صورة رائعة! أبدو وسيمًا فيها، أليس كذلك؟",
		},
		{
			mood = "neutral",
			text = "هل لاحظت؟ السماء حول الشمس زرقاء! غروب الشمس على الأرض برتقالي، أما على المريخ فالغبار الناعم يسمح للضوء الأزرق بالمرور قرب الشمس.",
			caption = "المصدر: ناسا",
		},
		{
			mood = "happy",
			text = "يا له من يوم! لنأخذ قسطًا من الراحة، فغدًا يوم جديد على المريخ!",
		},
	],
	&"window_view": [
		{
			mood = "happy",
			text = "يا له من منظر! يبدو المريخ جميلًا من هنا.",
		},
	],
	&"sleep_locked_window_selfie": [
		{
			mood = "sad",
			text = "انتظر، ليس قبل النوم! لم نلتقط صورة الغروب بعد.",
		},
		{
			mood = "neutral",
			text = "النافذة الدائرية في القاعة الكبيرة شرق القاعدة. هيا بنا!",
		},
	],

	# --- world border ---
	&"border_warning": [
		{
			mood = "anger",
			text = "مهلًا، مهلًا! إلى أين أنت ذاهب؟ عُد إلى هنا!",
		},
		{
			mood = "sad",
			text = "أنت فرد الطاقم الوحيد في القاعدة الآن. إذا ضعت في الخارج، فلن يبقى أحد ليعتني بها.",
		},
		{
			mood = "neutral",
			text = "قد تهبّ على المريخ عواصف غبارية ضخمة تغطي الكوكب بأكمله! لهذا لا نبتعد كثيرًا عن القاعدة.",
			caption = "المصدر: ناسا",
		},
		{
			mood = "happy",
			text = "القاعدة تحتاج إليك! لنعد ونحافظ على عملها. وإذا ابتعدت مرة أخرى، فسأعيدك إلى القاعدة بنفسي!",
		},
	],

	&"border_return": [
		{
			mood = "sad",
			text = "يا للراحة... لقد ابتعدت كثيرًا، فأعدتك إلى القاعدة.",
		},
		{
			mood = "neutral",
			text = "كلّفتنا تلك الرحلة بضع دقائق. لنبقَ قريبين ونعتنِ بالقاعدة!",
		},
	],

	# --- watering failures (id = task id + "_" + minigame reason) ---
	&"water_garden_overflow": [
		{
			mood = "anger",
			text = "مهلًا، مهلًا! هذا ماء كثير جدًا! أصبحت التربة مبتلّة تمامًا.",
		},
		{
			mood = "sad",
			text = "الجذور تحتاج إلى الهواء أيضًا. عندما تغمر المياه التربة تطرد الهواء منها، فلا تستطيع الجذور التنفس.",
		},
		{
			mood = "neutral",
			text = "الماء ثمين جدًا على المريخ، فلا نُهدره. حاول مرة أخرى، وأبقِ السكب في المنطقة الخضراء!",
		},
	],
	&"water_garden_too_slow": [
		{
			mood = "sad",
			text = "أوه لا... ما زالت النباتات عطشى. بضع قطرات لن تكفيها.",
		},
		{
			mood = "neutral",
			text = "هل تعلم؟ يعيد رواد الفضاء على محطة الفضاء الدولية تدوير نحو 98% من مياههم، حتى العرق يُنقّى ويُعاد استخدامه!",
			caption = "المصدر: ناسا",
		},
		{
			mood = "happy",
			text = "إذن لدينا ماء نعطيه! اسكب أسرع قليلًا في المرة القادمة. أنت قادر على ذلك!",
		},
	],
}

static func get_lines(id: StringName) -> Array:
	return ALL.get(id, [])
