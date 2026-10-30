class LotteryTicket {
	constructor(Utils) {
		this.active = false;
		this.lottery_element = document.getElementById('lottery_ticket');

		this.Utils = Utils;
	}

	isOpen = () => {
		return this.active;
	};

	handler = (data) => {
		if (this.lottery_element.contentWindow && this.lottery_element.contentWindow.eventHandler)
		{
			this.lottery_element.contentWindow.eventHandler(data);
		}
	};

	close = (removeFocus) => {
		this.handler({
			nui_reference: 'close',
			data: false
		})

		this.Utils.ToggleFocus(false);

		this.Utils.ElementState('lottery_ticket', false);

		this.active = false;
	};

	open = (data, reference) => {
		if (this.active)
		{
			this.close();
		}

		this.handler({
			nui_reference: (reference ? reference : 'open'),
			data: data
		})

		this.Utils.ToggleFocus(true);
		
		const thisScope = this;

		if (this.lottery_element.contentWindow)
		{
			this.lottery_element.contentWindow.addEventListener("keydown", function(evt) {
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

		this.Utils.ElementState('lottery_ticket', true);

		this.active = true;

		this.Utils.AddClose('lottery_ticket', this.close);
	};
}