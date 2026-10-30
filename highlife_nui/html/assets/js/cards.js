class Cards {
	constructor(utils){
		this.active = false;

		this.Utils = utils;

		this.assets = [
			{
				source: "https://cdn.highliferoleplay.net/fivem/cards/chance.jpg",
				className: "chance_card",
				options: { glare: true }
			},
			{
				source: "https://cdn.highliferoleplay.net/fivem/cards/jail_card.jpg",
				className: "jail_card",
				options: { glare: true }
			},
			{
				source: "https://cdn.highliferoleplay.net/fivem/cards/uno_reverse.png",
				className: "uno_reverse_card",
				options: { glare: true }
			},
			{
				source: "https://cdn.highliferoleplay.net/fivem/cards/blueprint_coke_1.png",
				className: "blueprint_coke_1",
				options: { glare: false }
			},
			{
				source: "https://cdn.highliferoleplay.net/fivem/cards/blueprint_weed_1.png",
				className: "blueprint_weed_1",
				options: { glare: false }
			},
			{
				source: "https://cdn.highliferoleplay.net/fivem/cards/warrant.png",
				className: "warrant",
				options: { glare: false }
			},
			{
				source: "https://cdn.highliferoleplay.net/fivem/cards/hunting_map.png",
				className: "hunting_map",
				options: { glare: false }
			},
			{
				source: "https://cdn.highliferoleplay.net/fivem/cards/independence.png",
				className: "independence_card",
				options: { glare: false }
			}
		];

		this.assets.map((asset, i) => {
			if (asset.source) {
				let element = document.createElement('div')

				element.className = `card`
				element.id = `${asset.className}`
				element.innerHTML = `<img src="${asset.source}">`
				element.style.display = 'none';

				document.querySelector('.cards').appendChild(element);

				VanillaTilt.init(document.querySelectorAll(`#${asset.className}`), asset.options);             
			}
		});
	};

	close = () => {
		this.assets.map((asset, i) => {
			if (document.getElementById(asset.className) !== null)
			{
				document.getElementById(asset.className).style.display = 'none';
			}
		});

		this.active = false;
	};

	show_card = (card) => {
		this.close();

		this.active = true;

		this.Utils.ToggleFocus();

		document.getElementById(card).style.display = 'block';

		this.Utils.AddClose('cards', this.close);
	};
}