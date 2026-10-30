class Babou {
	constructor(){
		this.babou = false;

		this.timer = ms => new Promise(res => setTimeout(res, ms))
	}

	async start(isNylah)
	{
		if (!this.babou)
		{
			this.babou = true;

			var babou_count = 1;

			var which_cat = (isNylah ? 'nylah_' : 'babou_')

			let bab_audio = new Audio((isNylah ? "https://cdn.highliferoleplay.net/fivem/sounds/bitchgirl.ogg" : "https://cdn.highliferoleplay.net/fivem/sounds/ahyeah.ogg"));

			bab_audio.volume = 0.04;
			bab_audio.play();

			await this.timer((isNylah ? 5900 : 11500));

			while (document.getElementById(which_cat + babou_count) != null)
			{
				document.getElementById(which_cat + babou_count.toString()).style.display = 'block';

				await this.timer((isNylah ? 2300 : 1150));

				document.getElementById(which_cat + babou_count.toString()).style.display = 'none';

				babou_count++;
			}

			this.babou = false;
		}
	}
}