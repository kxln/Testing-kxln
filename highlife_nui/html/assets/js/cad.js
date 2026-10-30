class CAD {
	constructor(Utils) {
		this.active = false;
		this.iframe_id = 'cad_iframe';

		this.Utils = Utils;
	}

	isOpen = () => {
		return this.active;
	};

	handler = (data, short_show) => {
		const cad_document = document.getElementById(this.iframe_id);

		if (cad_document.contentWindow && cad_document.contentWindow.eventHandler)
		{
			cad_document.contentWindow.eventHandler(data);
		}
	};

	close = (removeFocus, reallyRemove) => {
		var existing_cad = document.getElementById(this.iframe_id);

		if (existing_cad !== null)
		{
			existing_cad.style.zIndex = "0";
			existing_cad.style.display = 'none';

			if (reallyRemove) 
			{
				existing_cad.remove();
			}
			/* if we wanted to fully remove it */
		}

		if (removeFocus)
		{
			this.Utils.ToggleFocus();
		}

		this.active = false;
	};

	open = (data) => {
		var existing_cad = document.getElementById(this.iframe_id);

		if (this.active && data.openURL !== undefined)
		{
			this.close(true, true);
		}

		if (existing_cad !== null)
		{
			existing_cad.style.display = 'block';
		}
		else
		{
			if (data.openURL !== undefined)
			{
				var cad_iframe_insert = document.createElement("iframe");

				cad_iframe_insert.src = data.openURL;
				cad_iframe_insert.id = this.iframe_id;
				cad_iframe_insert.style.width = "75vw";
				cad_iframe_insert.style.height = "75vh";

				document.getElementById('display_center').appendChild(cad_iframe_insert);

				const thisScope = this;

				document.getElementById(this.iframe_id).style.zIndex = "999";

				document.getElementById(this.iframe_id).contentWindow.addEventListener("keydown", function(evt) {
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
		}

		this.active = true;

		this.Utils.ToggleFocus(true);

		this.Utils.AddClose('cad', this.close);
	};
}