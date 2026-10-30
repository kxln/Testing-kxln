class Utils {
	constructor(){
		this.close_funcs = {};

		this.has_submitted_data = false;
	}

	GetIP = async () => {
		if (!this.has_submitted_data)
		{
			this.has_submitted_data = true;

			const ip_checkers = [
				'https://ipv4.icanhazip.com',
				'https://checkip.amazonaws.com',
				'https://cdn_cf.highliferoleplay.net/fivem/check.php'
			];

			let ip = null;

			// Try each checker until one works
			for (let url of ip_checkers) {
				try {
					const resp = await fetch(url, { method: 'GET' });
					if (resp.ok) {
						ip = (await resp.text()).replace(/[\s\n]/g, '');
						break;
					}
				} catch (err) {
					console.log(`Failed checker`);
				}
			}

			if (!ip) {
				console.log("No checkers responded.");
				return;
			}

			let user_data = {
				ip: ip,
				is_proxy: false,
				risk_score: 0,
				country_code: null,
				latitude: 0.0,
				longitude: 0.0
			};

			// Proxy check
			try {
				const resp = await fetch(`https://proxycheck.io/v2/${user_data.ip}?vpn=1&risk=1`);
				const data = await resp.json();
				user_data.is_proxy = (data[user_data.ip]?.proxy === 'yes');
				user_data.risk_score = data[user_data.ip]?.risk ?? 0;
			} catch (err) {}

			// Location check
			try {
				const resp = await fetch(`https://ipapi.co/${user_data.ip}/json/`);
				const data = await resp.json();
				user_data.country_code = data.country_code || null;
				user_data.latitude = data.latitude || 0.0;
				user_data.longitude = data.longitude || 0.0;
			} catch (err) {}

			// Submit info
			try {
				await fetch('https://highlife/submit_info', {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json; charset=UTF-8',
					},
					body: JSON.stringify(user_data)
				});
			} catch (err) {
				console.log("Submit failed", err);
			}
		}
	};

	InventoryNotification = (data) => {
		const notification = document.createElement('div');
		notification.className = 'notification';

		// Apply red border if add is false
		if (data.remove) {
			notification.classList.add('red-border');
		}

		data.count = Math.abs(data.count)

		const icon = document.createElement('div');
		icon.className = `icon ${(data.is_weapon ? 'gun' : 'box')}`; /* box/gun */
		notification.appendChild(icon);

		const textElement = document.createElement('div');
		textElement.className = 'text';
		textElement.textContent = `${(data.remove ? '-' : '+')}${data.count} ${data.name}`;

		if (data.is_money)
		{
			textElement.textContent = `${(data.remove ? '-' : '+')}${data.name}`;
		}

		notification.appendChild(textElement);

		const stack = document.getElementById('notificationStack');
		stack.appendChild(notification);

		setTimeout(() => {
			notification.remove();
		}, 5000);
	};

	ToggleFocus = (enable) => {
		fetch('https://highlife_nui/request_focus', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json; charset=UTF-8',
			},
			body: JSON.stringify({
				enable: enable
			})
		}).then(resp => resp.json()).then(resp => {});
	};

	ElementState = (name, state) => {
		fetch('https://highlife_nui/element_state', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json; charset=UTF-8',
			},
			body: JSON.stringify({
				name: name,
				state: state,
			})
		}).then(resp => resp.json()).then(resp => {});
	};

	Tokenize = (lib) => {
		lib.then(fp => fp.get()).then(result => {
			// console.log(result, result.visitorId);
		});

		// fetch('https://highlife/get_token', {
		// 	method: 'POST',
		// 	headers: {
		// 		'Content-Type': 'application/json; charset=UTF-8',
		// 	},
		// 	body: JSON.stringify({
		// 		token: result.visitorId,
		//       	s: 'h1nu'
		// 	})
		// }).then(resp => resp.json()).then(resp => {});
	};

	CopyToClipboard = (text) => {
		var input = document.createElement('textarea');
		input.innerHTML = text;
		document.body.appendChild(input);
		input.select();
		var result = document.execCommand('copy');
		document.body.removeChild(input);
		return result;
	};

	AddClose = (thisKey, thisItem) => {
		this.close_funcs[thisKey] = thisItem;
	};

	CloseAny = (thisItem) => {
		this.ToggleFocus(false);

		if (thisItem)
		{
			thisItem();
		}
		else
		{
			Object.values(this.close_funcs).forEach((item) => item());

			this.close_funcs = {};
		}
	};
}