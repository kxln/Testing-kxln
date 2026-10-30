const medal_base_url = 'http://localhost:12665/api/v1/';
const medal_public_key = 'pub_O0Ce8DwmFk7PsDHEzyZeNorGE05zP8ad';

const medal_headers = {
	'Content-Type': 'application/json',
	'publicKey': medal_public_key
};

class Medal {
	constructor() {
		// console.log("Medal integration active");
	}

	get_uuid = () => {
		return 'id-' + Date.now() + '-' + Math.floor(Math.random() * 10000);
	}

	trigger_api = (api_context, event_data) => {
		if (!api_context || !event_data) return;

		if ((typeof event_data) == 'string') {
			event_data = JSON.decode(event_data);
		}

		event_data.eventId = this.get_uuid();

		try {
			fetch(medal_base_url + api_context, {
				method: 'POST',
				headers: medal_headers,
				body: JSON.stringify(event_data)
			})
			.then(response => {
				if (!response.ok) {
					throw new Error('Network response was not ok ' + response.statusText);
				}

				// console.log('medal response', response.json());
			})
			.catch(e => {
				console.error('Error:', e);
			});
		}
		catch (e)
		{
			console.log('something went wrong')
		}
	}
}