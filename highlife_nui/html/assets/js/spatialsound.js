class SpatialSound {
	constructor() {
		this.audio_context = new (window.AudioContext || window.webkitAudioContext)();

		this.listener = this.audio_context.listener;

		this.master_gain = this.audio_context.createGain();
		this.master_gain.gain.value = 1.0;
		this.master_gain.connect(this.audio_context.destination);

		this.audio_sources = {};

		this.audio_source_cache = {};
		this.dbPromise = this.initDB();

		this.debug_state = false;
		this.player_id = null;

		this.camera_position = {
			pos: { x: 0.0, y: 0.0, z: 0.0 },
			rot: { x: 0.0, y: 0.0, z: 0.0 },
			instance_reference: null,
			interior_reference: null
		};
	};

	debug = (message) => {
		if (this.debug_state) console.log(message);
	};

	// GTA:  x = right, y = forward, z = up
	// Audio: x = right, y = up, z = towards listener (we treat -z as forward)
	toAudioSpacePos = (pos) => {
		return {
			x: pos.x,
			y: pos.z,
			z: -pos.y
		};
	};

	// ---------- IndexedDB helpers ----------

	initDB = () => {
		return new Promise((resolve, reject) => {
			if (!('indexedDB' in window)) {
				this.debug('IndexedDB not supported, caching disabled');
				return resolve(null);
			}

			const request = indexedDB.open('SpatialSoundCache', 1);

			request.onupgradeneeded = (event) => {
				const db = event.target.result;
				if (!db.objectStoreNames.contains('audio')) {
					db.createObjectStore('audio');
				}
			};

			request.onsuccess = (event) => {
				const db = event.target.result;
				this.debug('IndexedDB opened');
				resolve(db);
			};

			request.onerror = (event) => {
				console.error('IndexedDB error', event.target.error);
				resolve(null);
			};
		});
	};

	getCachedBlob = async (url) => {
		const db = await this.dbPromise;
		if (!db) return null;

		return new Promise((resolve, reject) => {
			const tx = db.transaction('audio', 'readonly');
			const store = tx.objectStore('audio');
			const req = store.get(url);

			req.onsuccess = (e) => {
				resolve(e.target.result || null);
			};

			req.onerror = (e) => {
				console.error('IndexedDB get error', e.target.error);
				resolve(null);
			};
		});
	};

	putCachedBlob = async (url, blob) => {
		const db = await this.dbPromise;
		if (!db) return;

		return new Promise((resolve, reject) => {
			const tx = db.transaction('audio', 'readwrite');
			const store = tx.objectStore('audio');
			const req = store.put(blob, url);

			req.onsuccess = () => resolve();
			req.onerror = (e) => {
				console.error('IndexedDB put error', e.target.error);
				resolve();
			};
		});
	};

	// ---------- Listener (camera) ----------

	setListenerData = (data) => {
		this.camera_position = {
			pos: data.pos,
			rot: data.rot,
			instance_reference: data.instance_reference,
			interior_reference: data.interior_reference ?? null,
		};

		this.player_id = data.player_id;

		const posAudio = this.toAudioSpacePos(this.camera_position.pos);

		// GetFinalRenderedCamRot(2):
		// rot.x = pitch, rot.y = roll, rot.z = yaw
		const pitchRad = (this.camera_position.rot.x || 0) * (Math.PI / 180.0);
		const yawRad   = (this.camera_position.rot.z || 0) * (Math.PI / 180.0);

		const cosPitch = Math.cos(pitchRad);
		const sinPitch = Math.sin(pitchRad);
		const cosYaw   = Math.cos(yawRad);
		const sinYaw   = Math.sin(yawRad);

		const forwardGame = {
			x: -sinYaw * cosPitch,
			y:  cosYaw * cosPitch,
			z:  sinPitch
		};

		const forwardAudio = {
			x: forwardGame.x,
			y: forwardGame.z,
			z: -forwardGame.y
		};

		const upAudio = {
			x: 0.0,
			y: 1.0,
			z: 0.0
		};

		if (this.listener.positionX) {
			this.listener.positionX.value = posAudio.x;
			this.listener.positionY.value = posAudio.y;
			this.listener.positionZ.value = posAudio.z;

			this.listener.forwardX.value = forwardAudio.x;
			this.listener.forwardY.value = forwardAudio.y;
			this.listener.forwardZ.value = forwardAudio.z;

			this.listener.upX.value = upAudio.x;
			this.listener.upY.value = upAudio.y;
			this.listener.upZ.value = upAudio.z;
		} else {
			this.listener.setPosition(posAudio.x, posAudio.y, posAudio.z);
			this.listener.setOrientation(
				forwardAudio.x,
				forwardAudio.y,
				forwardAudio.z,
				upAudio.x,
				upAudio.y,
				upAudio.z
			);
		}

		if (data.sound_positions) {
			this.updateActiveSounds(data);
		}
	};

	// ---------- Audio source creation ----------

	initAudioSource = async (sound_data) => {
		const url = sound_data.data.url;

		if (this.audio_source_cache[url]) {
			return this.audio_source_cache[url];
		}

		const audio = new Audio();
		audio.crossOrigin = "anonymous";

		if (!sound_data.data.is_stream)
		{
			try {
				let blob = await this.getCachedBlob(url);

				if (blob) {
					this.debug('Loaded ' + url + ' from IndexedDB cache');

					audio.src = URL.createObjectURL(blob);
				}
				else {
					this.debug('Fetching ' + url + ' from network');

					const resp = await fetch(url, { cache: 'force-cache' });

					if (!resp.ok) throw new Error('Network error: ' + resp.status);

					blob = await resp.blob();
					audio.src = URL.createObjectURL(blob);

					this.putCachedBlob(url, blob);
				}
			}
			catch (e) {
				console.error('Error using IndexedDB cache for', url, e);

				this.debug('Falling back to direct URL for ' + url);

				audio.src = url;
			}
		}
		else
		{
			audio.src = url;
		}

		this.audio_source_cache[url] = audio;
		return audio;
	};

	// Compute environment mix (direct vs muffled) based on interior reference
	computeEnvMix = (src) => {
		const soundInterior = src.data.interior_reference ?? 0;
		const listenerInterior = this.camera_position.interior_reference ?? 0;

		// If neither has an interior, treat as same
		const bothNone = (soundInterior === 0 && listenerInterior === 0);

		let same = bothNone || (soundInterior !== null && soundInterior === listenerInterior);

		if (same) {
			// Direct, no muffle
			return { direct: 1.0, muffled: 0.0 };
		}

		// Different interior: mostly muffled, a bit of direct
		// tweak these to taste
		return {
			direct: 0.04,
			muffled: 0.9
		};
	};

	startAudioSource = async (sound_data) => {
		const base_audio = await this.initAudioSource(sound_data);
		const this_audio_source = base_audio.cloneNode(true);

		const this_audio_node   = this.audio_context.createMediaElementSource(this_audio_source);
		const this_audio_panner = this.audio_context.createPanner();

		// environment chain
		const directGain   = this.audio_context.createGain();
		const muffledGain  = this.audio_context.createGain();
		const muffledFilter = this.audio_context.createBiquadFilter();

		// final per-sound gain (distance * script * base volume)
		const finalGain = this.audio_context.createGain();

		this.debug('starting');

		this_audio_source.crossOrigin = "anonymous";

		const baseVolume = sound_data.data.volume ?? 1.0;
		const loop = sound_data.data.loop || false;
		const startAt = sound_data.data.start_at_time || 0;

		this_audio_source.loop = loop;
		this_audio_source.currentTime = startAt;

		finalGain.gain.value = baseVolume;

		if (sound_data.data.is_stream) {
			this_audio_panner.panningModel = "HRTF";
		}

		// Panning (direction only, distance handled by our curve)
		this_audio_panner.distanceModel = "inverse";
		this_audio_panner.refDistance   = 1.0;
		this_audio_panner.rolloffFactor = 0.0;
		this_audio_panner.maxDistance   = 999999.0;

		this_audio_panner.coneInnerAngle = 360;
		this_audio_panner.coneOuterAngle = 0;
		this_audio_panner.coneOuterGain  = 0;

		const audioPos = this.toAudioSpacePos(sound_data.data.pos);

		if (this_audio_panner.positionX) {
			this_audio_panner.positionX.value = audioPos.x;
			this_audio_panner.positionY.value = audioPos.y;
			this_audio_panner.positionZ.value = audioPos.z;
		} else {
			this_audio_panner.setPosition(audioPos.x, audioPos.y, audioPos.z);
		}

		// Muffled filter: lowpass like "through a wall"
		muffledFilter.type = "lowpass";
		muffledFilter.frequency.value = 1200; // tweak
		muffledFilter.Q.value = 0.7;

		// Graph:
		// source -> panner ->
		//    -> directGain  \
		//    -> muffledFilter -> muffledGain  -> finalGain -> master
		this_audio_node.connect(this_audio_panner);

		this_audio_panner.connect(directGain);
		this_audio_panner.connect(muffledFilter);

		muffledFilter.connect(muffledGain);

		directGain.connect(finalGain);
		muffledGain.connect(finalGain);

		finalGain.connect(this.master_gain);

		this.audio_sources[sound_data.id] = {
			loaded: false,
			data: sound_data.data,
			node: this_audio_node,
			audio: this_audio_source,
			panner: this_audio_panner,
			// env
			directGain: directGain,
			muffledGain: muffledGain,
			muffledFilter: muffledFilter,
			// final
			gain: finalGain,
			baseVolume: baseVolume,
			scriptVolume: 1.0
		};

		// initial env mix
		const env = this.computeEnvMix(this.audio_sources[sound_data.id]);
		directGain.gain.value  = env.direct;
		muffledGain.gain.value = env.muffled;

		const canplaythroughListener = () => {
			const src = this.audio_sources[sound_data.id];
			if (!src) return;

			src.loaded = true;

			src.audio.addEventListener('playing', () => {
				fetch('https://highlife/SpatialSoundNowPlaying', {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json; charset=UTF-8',
					},
					body: JSON.stringify({
						name: sound_data.data.name
					})
				}).then(resp => resp.json()).then(resp => {});
			});

			src.audio.play().catch(e => {
				console.log(e);
			});
		};

		this_audio_source.canplaythroughListener = canplaythroughListener;
		this_audio_source.addEventListener('canplaythrough', canplaythroughListener);

		this_audio_source.onloadedmetadata = () => {
			if (!sound_data.data.localSound && !sound_data.data.is_stream && (sound_data.source == this.player_id))
			{
				fetch('https://highlife/SpatialSoundSetLength', {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json; charset=UTF-8',
					},
					body: JSON.stringify({
						id: sound_data.id,
						duration: this_audio_source.duration
					})
				}).then(resp => resp.json()).then(resp => {});
			}
		};
	};

	// data.sound_positions: [{ id, pos, volume? }, ...]\
	// data.sound_positions: { [id]: { id, pos, volume? }, ... }
updateActiveSounds = (data) => {
	const positions      = data.sound_positions || {};
	const soundInteriors = data.sound_interiors || {};
	const listenerPos    = this.camera_position.pos;

	for (const this_sound_id in this.audio_sources)
	{
		const src = this.audio_sources[this_sound_id];
		if (!src) continue;

		// --- INTERIOR REFERENCE FROM LUA (optional) ---
		if (soundInteriors.hasOwnProperty(this_sound_id)) {
			src.data.interior_reference = soundInteriors[this_sound_id];
		}

		const sp = positions[this_sound_id] || null;

		let script_controlled_audio = false;

		// We only do distance / positional work if this sound is spatial
		if (src.data.distance && src.panner)
		{
			// --- ENTITY-TRACKED SOUND POSITION ---
			if (src.data.entity != null && sp && sp.pos)
			{
				// Update world position from entity
				src.data.pos = sp.pos;

				const audioPos = this.toAudioSpacePos(src.data.pos);

				if (src.panner.positionX) {
					src.panner.positionX.value = audioPos.x;
					src.panner.positionY.value = audioPos.y;
					src.panner.positionZ.value = audioPos.z;
				} else {
					src.panner.setPosition(audioPos.x, audioPos.y, audioPos.z);
				}

				if (sp.volume != null)
				{
					src.scriptVolume = sp.volume;
					script_controlled_audio = true;
				}
			}
			// --- STATIC SOUND WITH SCRIPT VOLUME OVERRIDE ---
			else if (sp && sp.volume != null)
			{
				src.scriptVolume = sp.volume;
				script_controlled_audio = true;
			}

			if (!script_controlled_audio)
			{
				if (src.scriptVolume == null) {
					src.scriptVolume = 1.0;
				}
			}

			// --- CUSTOM DISTANCE FALLOFF ---
			const maxDist = src.data.distance;
			let distanceFactor = 1.0;

			if (maxDist != null && maxDist > 0.0 && src.data.pos && listenerPos)
			{
				const dx = (src.data.pos.x - listenerPos.x);
				const dy = (src.data.pos.y - listenerPos.y);
				const dz = (src.data.pos.z - listenerPos.z);

				const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);

				if (dist >= maxDist) {
					distanceFactor = 0.0;
				} else {
					const t = dist / maxDist; // 0 at source, 1 at edge
					const oneMinusT = 1.0 - t;
					distanceFactor = oneMinusT * oneMinusT;
				}
			}

			// --- INSTANCE FACTOR ---
			const instanceFactor =
				(src.data.instance_reference == this.camera_position.instance_reference)
					? 1.0
					: 0.0;

			// --- FINAL VOLUME ---
			const base = src.baseVolume ?? src.data.volume ?? 1.0;
			const scriptVol = src.scriptVolume ?? 1.0;

			const finalVol = base * scriptVol * distanceFactor * instanceFactor;

			if (src.gain) {
				src.gain.gain.value = finalVol;
			}

			// --- INTERIOR WET/DRY MIX ---
			const env = this.computeEnvMix(src);
			if (src.directGain && src.muffledGain) {
				src.directGain.gain.value  = env.direct;
				src.muffledGain.gain.value = env.muffled;
			}
		}

		// Remove finished non-loopers
		if (src.loaded && src.audio && src.audio.ended && !src.data.loop)
		{
			this.debug('end');
			this.stopAudioSource({ id: this_sound_id });
		}
	}
};


	tweakFactors = (data) => {
		for (const thisSource in this.audio_sources)
		{
			const src = this.audio_sources[thisSource];
			if (!src || !src.panner) continue;

			if (data.refDistance != null) {
				// no-op for now, since we do manual distance;
				// kept for compatibility if you want to repurpose later
				src.panner.refDistance = data.refDistance;
			}
			if (data.rolloffFactor != null) {
				src.panner.rolloffFactor = 0.0;
			}
		}
	};

	stopAudioSource = (data) => {
		const src = this.audio_sources[data.id];

		if (src)
		{
			src.audio.pause();

			if (src.audio.canplaythroughListener)
			{
				src.audio.removeEventListener('canplaythrough', src.audio.canplaythroughListener);
				src.audio.canplaythroughListener = null;
			}

			try {
				src.node   && src.node.disconnect();
				src.panner && src.panner.disconnect();
				src.directGain && src.directGain.disconnect();
				src.muffledGain && src.muffledGain.disconnect();
				src.muffledFilter && src.muffledFilter.disconnect();
				src.gain   && src.gain.disconnect();
			} catch (e) {}

			if (src.audio.parentNode)
			{
				src.audio.parentNode.removeChild(src.audio);
			}

			src.audio.src = "";
			src.audio.srcObject = null;

			src.node = null;
			src.panner = null;
			src.directGain = null;
			src.muffledGain = null;
			src.muffledFilter = null;
			src.gain = null;
			src.audio = null;

			this.debug("Removed sound " + data.id);

			fetch('https://highlife/SpatialSoundStop', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json; charset=UTF-8',
				},
				body: JSON.stringify({
					id: data.id
				})
			}).then(resp => resp.json()).catch(error => {});

			delete this.audio_sources[data.id];
		}
	};
}
