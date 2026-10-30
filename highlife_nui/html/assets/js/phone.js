class PhoneHandler {
	constructor(Utils) {
		this.active = false;

		this.Utils = Utils;
	}

	isOpen = () => {
		return this.active;
	};

	handler = (data, short_show) => {
		this.phone_element = document.getElementById('iframe_phone');

		if (this.phone_element.contentWindow && this.phone_element.contentWindow.eventHandler)
		{
			this.phone_element.contentWindow.eventHandler(data);
		}
	};

	close = (removeFocus) => {
		this.handler({
			nui_reference: 'phone_visible',
			data: false
		})

		this.handler({
			nui_reference: 'text_focus',
			data: false
		})

		if (removeFocus)
		{
			this.Utils.ToggleFocus();
		}

		this.Utils.ElementState('phone', false);

		fetch('https://highlife/close_phone', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json; charset=UTF-8',
			},
			body: JSON.stringify({
				close: true
			})
		}).then(resp => resp.json()).then(resp => {});

		this.active = false;
	};

	open = (data) => {
		if (this.active)
		{
			this.close();
		}

		this.handler({
			nui_reference: 'phone_visible',
			data: true
		})

		const thisScope = this;

		if (this.phone_element.contentWindow)
		{
			this.phone_element.contentWindow.addEventListener("keydown", function(evt) {
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

		this.Utils.ToggleFocus('partial');

		this.Utils.ElementState('phone', true);

		this.active = true;

		this.Utils.AddClose('phone', this.close);
	};
}