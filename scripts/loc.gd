class_name Loc
extends RefCounted
## Turkish / English text table. Loc.t("key", [args]) uses the language from Settings.

const TR := {
	"title": "Çay Ocağı",
	"tagline": "Boğaz kıyısında küçük bir çay ocağı. Demle, servis et, bahşişi topla.",
	"play": "Oyuna başla", "continue": "Devam et", "best": "En iyi: Gün {0} · {1} altın", "noBest": "Henüz rekor yok",
	"how1": "Bir istasyona tıkla (1-4): çay demle, simit ısıt, kahve pişir. Hazır olunca tekrar tıkla, tepsine girsin.",
	"how2": "Bir masaya tıkla: istenenleri servis et. Kirli bardakları topla, lavaboya (5) götür.",
	"how3": "Müşterilerin sabrı tükenmeden servis yap. Hızlı servis daha çok bahşiş getirir.",
	"how4": "Boşluk: duraklat · Esc: kuyruğu temizle · Sürükle: kaydır · Tekerlek: yakınlaştır.",
	"day": "Gün", "dayOf": "Gün {0}/7", "dayEndless": "Gün {0} ∞", "target": "Hedef", "newThing": "Yeni", "menuToday": "Bugünün menüsü",
	"startDay": "Günü başlat", "today": "Bugün", "tray": "Tepsi", "queue": "Sıra", "clearQ": "temizle",
	"tea": "Çay", "simit": "Simit", "coffee": "Kahve", "ayran": "Ayran", "sink": "Lavabo", "dirty": "Kirli bardak",
	"n_tea": "Çay", "n_simit": "Simit", "n_coffee": "Türk kahvesi", "n_ayran": "Ayran",
	"c_normal": "Müşteri", "c_office": "Aceleci memur", "c_group": "3 kişilik grup", "c_regular": "Müdavim (bahşiş x2)",
	"new1": "Demli çay", "new2": "Sıcak simit", "new3": "Türk kahvesi", "new4": "Soğuk ayran",
	"new5": "Aceleci ofis çalışanı: sabrı kısa", "new6": "3 kişilik grup: büyük sipariş", "new7": "Müdavim: bahşişi iki katı",
	"newE": "Sonsuz vardiya: her gün biraz daha kalabalık",
	"tip1": "Önce çayı demle: demlenirken simit ısıtabilirsin.", "tip2": "Sırayı akıllı kur: tepsiye 3 şey sığar.",
	"tip3": "Kahveyi hazır olunca hemen al, yoksa taşar!", "tip4": "Boş dururken kirli bardakları topla.", "tip5": "Dükkandan yardımcı ve masa al.",
	"paused": "Duraklatıldı", "pausedSub": "Devam etmek için Boşluk tuşu ya da ▶",
	"toastTray": "Tepsi dolu!", "toastBrewing": "Henüz hazır değil", "toastNothing": "Burada yapacak bir şey yok", "toastQueue": "Sıra dolu",
	"toastWrong": "Bu masa onu istemedi", "toastNoOrder": "Henüz sipariş vermedi", "toastTeaReady": "Çay hazır!", "toastSimitReady": "Simit sıcak!",
	"toastCoffeeReady": "Kahve hazır, taşmadan al!", "toastSpill": "Kahve taştı!", "toastAngry": "Müşteri kızıp gitti!", "toastClean": "Kahve ocağı temizlendi",
	"toastWash": "Bardaklar yıkandı", "toastMeow": "Miyav!", "toastApprentice": "Çırak masayı topladı", "toastBrewStart": "Demleniyor...",
	"toastCook": "Kahve pişiyor...", "toastWarm": "Simit ısınıyor...", "toastNothingToWash": "Yıkanacak bardak yok",
	"dayDone": "Gün tamamlandı!", "dayFail": "Hedef tutmadı", "earned": "Kazanılan", "tips": "Bahşiş", "happyC": "Memnun", "angryC": "Kızgın",
	"cont": "Devam", "toShop": "Dükkana git", "shop": "Dükkan", "wallet": "Cüzdan", "nextDay": "Sonraki gün", "buy": "Al", "maxed": "Tamam",
	"retry": "Günü tekrar dene", "menu": "Ana menü", "victory": "Tebrikler!", "victoryTxt": "Yedi günü tamamladın. Çay ocağı artık mahallenin gözdesi!",
	"endless": "Sonsuz vardiya", "total": "Toplam altın", "gameover": "Vardiya bitti", "goTxt": "Bu gün hedefe ulaşamadın. Dükkandaki geliştirmeler bir dahaki denemede işine yarar.",
	"reached": "Ulaşılan gün", "ratingStars": "Yıldız",
	"u_kettle": "İkinci semaver", "u_kettle_d": "İki çaydanlık aynı anda demlenir.",
	"u_tray": "Büyük tepsi", "u_tray_d": "Tepsiye taşıdığın ürün sayısı artar (3 → 5).",
	"u_oven": "Hızlı fırın", "u_oven_d": "Simitler daha çabuk ısınır.",
	"u_apprentice": "Çırak", "u_apprentice_d": "Boş masaları toplayıp bardakları yıkar.",
	"u_table": "Ek masa", "u_table_d": "Bir masa daha: daha çok müşteri.",
	"u_stool": "Rahat tabure", "u_stool_d": "Müşteriler daha sabırlı (+%20 sabır).",
	"langBtn": "EN", "speedT": "Hız", "pauseT": "Duraklat", "soundT": "Ses", "hint": "İpucu", "stars3": "Harika!", "stars2": "Güzel gün", "stars1": "İdare eder",
	"welcome": "Hoş geldin! Önce çay istasyonuna (1) tıkla.",
	"full": "dolu", "passByWait": "Masa yok",
	"settings": "Ayarlar", "back": "Geri", "resume": "Devam et", "volMaster": "Ana ses", "volMusic": "Müzik", "volSfx": "Efektler",
	"language": "Dil", "quality": "Kalite", "qLow": "Düşük", "qHigh": "Yüksek", "fullscreen": "Tam ekran", "on": "Açık", "off": "Kapalı",
	"keys": "Tuşlar", "newGameWarn": "Yeni oyun kayıtlı ilerlemenin üzerine yazar.", "dayTarget": "Hedef: {0} altın",
	"bestRun": "Rekor", "save": "Kaydedildi", "startingCoins": "Başlangıç: {0} altın", "coins": "altın", "openMenu": "Menü",
}

const EN := {
	"title": "Çay Ocağı",
	"tagline": "A tiny tea house by the Bosphorus. Brew, serve, collect tips.",
	"play": "Start game", "continue": "Continue", "best": "Best: Day {0} · {1} coins", "noBest": "No record yet",
	"how1": "Click a station (1-4): brew tea, warm simit, cook coffee. Click again when ready to grab it onto your tray.",
	"how2": "Click a table to serve what they ordered. Collect dirty glasses and bring them to the sink (5).",
	"how3": "Serve before patience runs out. Fast service earns bigger tips.",
	"how4": "Space: pause · Esc: clear queue · Drag: pan · Wheel: zoom.",
	"day": "Day", "dayOf": "Day {0}/7", "dayEndless": "Day {0} ∞", "target": "Target", "newThing": "New", "menuToday": "Today's menu",
	"startDay": "Start the day", "today": "Today", "tray": "Tray", "queue": "Queue", "clearQ": "clear",
	"tea": "Tea", "simit": "Simit", "coffee": "Coffee", "ayran": "Ayran", "sink": "Sink", "dirty": "Dirty glass",
	"n_tea": "Tea", "n_simit": "Simit", "n_coffee": "Turkish coffee", "n_ayran": "Ayran",
	"c_normal": "Customer", "c_office": "Hurried clerk", "c_group": "Group of 3", "c_regular": "Regular (tips x2)",
	"new1": "Fresh brewed tea", "new2": "Warm simit", "new3": "Turkish coffee", "new4": "Cold ayran",
	"new5": "Hurried office worker: short patience", "new6": "Group of 3: big orders", "new7": "Regular: tips double",
	"newE": "Endless shift: a bit busier every day",
	"tip1": "Start the tea first: warm simit while it brews.", "tip2": "Plan your route: the tray holds only 3 items.",
	"tip3": "Grab the coffee as soon as it is ready, or it boils over!", "tip4": "Clear dirty glasses when idle.", "tip5": "Buy an apprentice and extra tables in the shop.",
	"paused": "Paused", "pausedSub": "Press Space or ▶ to resume",
	"toastTray": "Tray is full!", "toastBrewing": "Not ready yet", "toastNothing": "Nothing to do here", "toastQueue": "Queue is full",
	"toastWrong": "That table didn't order it", "toastNoOrder": "No order yet", "toastTeaReady": "Tea is ready!", "toastSimitReady": "Simit is warm!",
	"toastCoffeeReady": "Coffee is ready, grab it!", "toastSpill": "Coffee boiled over!", "toastAngry": "A customer left angry!", "toastClean": "Coffee pot cleaned",
	"toastWash": "Glasses washed", "toastMeow": "Meow!", "toastApprentice": "Apprentice cleared a table", "toastBrewStart": "Brewing...",
	"toastCook": "Cooking coffee...", "toastWarm": "Warming simit...", "toastNothingToWash": "No dirty glasses to wash",
	"dayDone": "Day complete!", "dayFail": "Target missed", "earned": "Earned", "tips": "Tips", "happyC": "Happy", "angryC": "Angry",
	"cont": "Continue", "toShop": "Go to shop", "shop": "Shop", "wallet": "Wallet", "nextDay": "Next day", "buy": "Buy", "maxed": "Maxed",
	"retry": "Retry the day", "menu": "Main menu", "victory": "Congratulations!", "victoryTxt": "You finished all seven days. The tea house is now the pride of the neighbourhood!",
	"endless": "Endless shift", "total": "Total coins", "gameover": "Shift over", "goTxt": "You missed the target today. Upgrades from the shop will help next time.",
	"reached": "Day reached", "ratingStars": "Stars",
	"u_kettle": "Second samovar", "u_kettle_d": "Two kettles brew at the same time.",
	"u_tray": "Bigger tray", "u_tray_d": "Carry more items at once (3 → 5).",
	"u_oven": "Faster oven", "u_oven_d": "Simit warms up quicker.",
	"u_apprentice": "Apprentice", "u_apprentice_d": "Clears tables and washes the glasses.",
	"u_table": "Extra table", "u_table_d": "One more table: more customers.",
	"u_stool": "Comfy stools", "u_stool_d": "Customers are more patient (+20%).",
	"langBtn": "TR", "speedT": "Speed", "pauseT": "Pause", "soundT": "Sound", "hint": "Hint", "stars3": "Brilliant!", "stars2": "Nice day", "stars1": "Good enough",
	"welcome": "Welcome! Click the tea station (1) first.",
	"full": "full", "passByWait": "No table",
	"settings": "Settings", "back": "Back", "resume": "Resume", "volMaster": "Master volume", "volMusic": "Music", "volSfx": "Effects",
	"language": "Language", "quality": "Quality", "qLow": "Low", "qHigh": "High", "fullscreen": "Fullscreen", "on": "On", "off": "Off",
	"keys": "Keys", "newGameWarn": "A new game overwrites your saved progress.", "dayTarget": "Target: {0} coins",
	"bestRun": "Record", "save": "Saved", "startingCoins": "Starting: {0} coins", "coins": "coins", "openMenu": "Menu",
}


## Translate a key. Falls back to Turkish, then to the key itself.
static func t(key: String, args: Array = []) -> String:
	var table: Dictionary = EN if Settings.lang == "en" else TR
	var s: String
	if table.has(key):
		s = table[key]
	elif TR.has(key):
		s = TR[key]
	else:
		s = key
	for i in args.size():
		s = s.replace("{%d}" % i, str(args[i]))
	return s
