class Lockpicking {
	constructor(Utils) {
		this.active = false;
		this.lockpicking_element = document.getElementById('lockpicking');

		this.Utils = Utils;
	}

	handler = (data, short_show) => {
		if (this.lockpicking_element.contentWindow && this.lockpicking_element.contentWindow.eventHandler)
		{
			this.lockpicking_element.contentWindow.eventHandler(data);
		}
	};

	isOpen = () => {
		return this.active;
	};

	close = (removeFocus) => {
		this.handler({
			state: 'end'
		})

		this.Utils.ToggleFocus(false);

		this.Utils.ElementState('lockpicking', false);

		this.active = false;
	};

	open = (data, reference) => {
		if (this.active)
		{
			this.close();
		}

		this.Utils.ToggleFocus(true);

		this.lockpicking_element.focus();
		
		const thisScope = this;

		if (this.lockpicking_element.contentWindow)
		{
			this.lockpicking_element.contentWindow.addEventListener("keydown", function(evt) {
				var isEscape = false;

				if (evt.key !== undefined)
				{
					isEscape = (evt.key === "Escape" || evt.key === "Esc" || evt.key === "F6");
				}
				else
				{
					isEscape = (evt.keyCode === 27);
				}

				if (isEscape)
				{
					thisScope.close(true);
				}
			});
		}

		setTimeout(() => {
			this.lockpicking_element.contentWindow.focus()
		}, 500);

		this.Utils.ElementState('lockpicking', true);

		this.active = true;

		this.Utils.AddClose('lockpicking', this.close);
	};
}