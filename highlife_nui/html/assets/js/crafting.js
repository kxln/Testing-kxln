class Crafting {
	constructor(Utils) {
		this.active = false;
		this.crafting_element = document.getElementById('crafting');

		this.Utils = Utils;
	}

	handler = (data, short_show) => {
		if (this.crafting_element.contentWindow && this.crafting_element.contentWindow.eventHandler)
		{
			this.crafting_element.contentWindow.eventHandler(data);
		}
	};

	isOpen = () => {
		return this.active;
	};

	close = (removeFocus) => {
		this.handler({
			nui_reference: 'crafting_hide',
		});

		this.Utils.ToggleFocus(false);

		this.crafting_element.classList.remove("active");

		this.Utils.ElementState('crafting', false);

		this.active = false;
	};

	open = (data, reference) => {
		if (this.active)
		{
			this.close();
		}

		this.handler({
			nui_reference: 'crafting_show',
		});

		this.Utils.ToggleFocus(true);

		this.crafting_element.focus();
		
		const thisScope = this;

		if (this.crafting_element.contentWindow)
		{
			this.crafting_element.contentWindow.addEventListener("keydown", function(evt) {
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

		this.Utils.ElementState('crafting', true);

		this.active = true;

		this.Utils.AddClose('crafting', this.close);
	};
}