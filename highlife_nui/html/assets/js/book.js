const SPREAD_ASPECT = 4 / 3; // spread width/height
const MAX_SPREAD_W = 1400;
const VIEWPORT_MARGIN = 0.9;

const debounce = (fn, ms = 100) => {
	let t;
	return (...args) => {
		clearTimeout(t);
		t = setTimeout(() => fn.apply(null, args), ms);
	};
};

class Book {
	constructor(utils) {
		this.Utils = utils;
		this.active = false;
	}

	show = (pages, width, height) => {
		$('body').prepend(`
			<div id="book-container">
				<div id="book"></div>
			</div>
		`);

		// Build pages as <div.page><img/></div>
		for (const src of pages) {
			const page = document.createElement('div');
			page.className = 'page';

			const img = new Image();
			img.src = src;
			img.alt = '';
			img.className = 'page-img';

			page.appendChild(img);
			document.getElementById('book').appendChild(page);
		}

		this.active = true;

		// Init (turn.js needs an initial size; we'll immediately size it)
		this.flipbook = $('#book').turn({
			width: 800,
			height: 600,
			acceleration: true,
			gradients: true,
			page: 1,
			// display: 'double', // uncomment if you want explicit double page layout
		});

		const sizeBook = () => {
			const vw = window.innerWidth * VIEWPORT_MARGIN;
			const vh = window.innerHeight * VIEWPORT_MARGIN;

			const targetW = Math.min(vw, MAX_SPREAD_W);
			const hFromW = targetW / SPREAD_ASPECT;

			let spreadW, spreadH;
			if (hFromW <= vh) {
				spreadW = targetW;
				spreadH = hFromW;
			} else {
				spreadH = vh;
				spreadW = spreadH * SPREAD_ASPECT;
			}

			// ---- critical alignment fixes ----
			spreadW = Math.floor(spreadW);
			spreadH = Math.floor(spreadH);

			// make width even so each page is an integer width
			if (spreadW % 2 !== 0) spreadW -= 1;

			$('#book').turn('size', spreadW, spreadH);
		};

		sizeBook();
		window.addEventListener('resize', debounce(sizeBook, 120));

		this.Utils.AddClose('book', this.close);
	};

	close = () => {
		this.flipbook.destroy();

		$('#book-container').remove();

		$.post('https://highlife/close_book', JSON.stringify({}));

		this.active = false;
	};
}