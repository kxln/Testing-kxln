class InputContext {
	constructor(Utils) {
		this.active = false;
		this.input_context = document.getElementById('input_context');

		this.Utils = Utils;
	}

	isOpen = () => {
		return this.active;
	};

	handler = (data) => {
		if (this.input_context.contentWindow && this.input_context.contentWindow.eventHandler)
		{
			this.input_context.contentWindow.eventHandler(data);
		}
	};

	close = (removeFocus) => {
		this.handler({
			nui_reference: 'close',
			data: false
		})

		this.Utils.ToggleFocus(false);

		this.Utils.ElementState('input_context', false);

		this.input_context.classList.remove("active");

		this.active = false;
	};

	open = (data, reference) => {
		if (this.active)
		{
			this.close();
		}

		this.Utils.ToggleFocus(true);

		this.handler({
			nui_reference: (reference ? reference : 'init_input'),
			data: data
		})

		this.input_context.classList.add("active");
		
		const thisScope = this;

		if (this.input_context.contentWindow)
		{
			this.input_context.contentWindow.addEventListener("keydown", function(evt) {
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

		const iframeDocument = this.input_context.contentDocument || this.input_context.contentWindow.document;

		// Find a child element within the iframe
		const childElement = iframeDocument.querySelector('input');

		// Do something with the child element
		if (childElement) {
			setTimeout(() => {
				childElement.focus()
			}, 100);
		}

		this.Utils.ElementState('input_context', true);

		this.active = true;

		this.Utils.AddClose('input_context', this.close);
	};
}