class Radio {
	constructor(Utils) {
		this.streamElement = null;

		this.utils = Utils;
	};

	start = (eventData) => {
		if (this.streamElement == null)
		{
			this.streamElement = new Audio('https://cast.highliferoleplay.net/listen/hlfm/radio.mp3');
			this.streamElement.type = 'audio/mpeg';

			this.setVolume(eventData);

			try {
				this.streamElement.play();
			}
			catch (err) {}
		}
		else
		{
			this.setVolume(eventData);
		}
	};

	setVolume = (eventData) => {
		if (this.streamElement !== null)
		{
			if (eventData.volume > 0.0)
			{
				this.streamElement.volume = eventData.volume;
			}
			else {
				this.streamElement.volume = 0.0;
			}
		}
	};

	stop = () => {
		if (this.streamElement !== null)
		{
			this.streamElement.volume = 0;
		}
	};
}