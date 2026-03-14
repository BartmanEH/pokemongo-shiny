// import pm_local_csv_url from '@data/pm.csv?url';
import raw_names from '@data/name.csv';
import { csv2json, fetch_data, get_item, confirm_to_reset, } from '@lib/u.svelte.js';
import { recorder, } from '@lib/recorder.svelte.js';
import { session, DEFAULT_PM_DATA_SOURCE, LOCAL_PM_DATA_SOURCE } from '@lib/config.svelte.js';

class PokemonManager {
	groups = $state([]);
	tags = $state([]);
	is_loading = $state(true);
	error = $state(null);
	pid_with_tags = $state(new Map());
	status_length_by_family = $state(new Map());

	async init() {
		this.is_loading = true;
		this.error = null;

		try {
			// Step 1: Basic setup
			const { groups, tags, pid_with_tags, status_length_by_family } = await fetch_pms_data();

			this.groups = groups;
			this.tags = tags;
			this.pid_with_tags = pid_with_tags;
			this.status_length_by_family = status_length_by_family;

			// Step 2: Data priority logic (The core sequence)
			// Priority 1: URL session (already parsed in config.svelte.js)
			if (session.status) {
				this.fn_overwrite_status(session.status);
			} else {
				// Priority 2: Latest record
				await recorder.init();

				if (recorder.records && recorder.records.length > 0) {
					// Use the first record (index 0)
					this.fn_overwrite_status(recorder.records[0].status);
					session.name = recorder.records[0].name;
				}
				// Priority 3: Default empty (already set by handle_pms)
			}

		} catch (err) {
			this.error = "Failed to load data: " + err.message;
		} finally {
			this.is_loading = false;
		}
	}

	sorted_pms = $derived.by(() => {
		return this.groups
			.flatMap(group => group[1] || [])
			.toSorted((a, b) => a._gidx - b._gidx || a._pidx - b._pidx);
	});

	// status_counts uses the pre-sorted list, making it much faster
	status_counts = $derived.by(() => {
		const counts = { 0: 0, 1: 0, 2: 0, 3: 0 };
		this.sorted_pms.forEach(pm => {
			const s = Number(pm.status || 0);
			if (counts[s] !== undefined) counts[s]++;
		});
		return counts;
	});

	status_summary = $derived.by(() => {
		const counts = this.status_counts;
		return [
			{ label: 'none',  count: counts[0], },
			{ label: 'met',   count: counts[1] + counts[2] + counts[3], },
			{ label: 'own',   count: counts[2] + counts[3], },
			{ label: 'extra', count: counts[3], },
		];
	});

	status_percent = $derived.by(() => {
		const counts = this.status_counts;
		const total = counts[0] + counts[1] + counts[2] + counts[3];
		return {
			seen: 100 * (counts[1] + counts[2] + counts[3]) / total,
			captured: 100 * (counts[2] + counts[3]) / total,
		};
	});

	status_string = $derived.by(() => {
		const grouped_map = new Map();

		this.sorted_pms.forEach(pm => {
			if (!grouped_map.has(pm._gidx)) {
				const _array_len = this.status_length_by_family.get(pm._gidx);
				grouped_map.set(pm._gidx, Array(_array_len).fill(0));
			}
			grouped_map.get(pm._gidx)[pm._pidx] = pm.status ?? 0;
		});
		return Array.from(grouped_map, ([key, values]) => `${key}.${values.join('')}`).join('-');
	});

	/**
	 * Overwrite status from a serialized string (e.g., "1.012-4.001")
	 * Optimized to avoid nested sorting and ensure O(n) complexity
	 */
	fn_overwrite_status(status_str = '1.000-4.000') {
		if (!status_str || typeof status_str !== 'string') return;

		// 1. Create a flat lookup map for O(1) access
		// Key format: "_gidx_positionInGroup"
		const status_lookup = new Map();
		const sections = status_str.split('-');

		sections.forEach(section => {
			const [idx1, statuses] = section.split('.');
			if (idx1 && statuses) {
				statuses.split('').forEach((s, i) => {
					status_lookup.set(`${idx1}_${i}`, Number(s));
				});
			}
		});

		// 2. Update status by matching _gidx and sequence
		// We assume groups are already structured by _gidx
		this.groups.forEach(group => {
			const pms = group[1]; // Based on your handle_pms structure [key, pms_array]
			if (!Array.isArray(pms)) return;

			pms.forEach(pm => {
				// Use the absolute _pidx (position in family) instead of loop index
				const g_idx = pm._gidx;
				const p_idx = pm._pidx;

				const new_val = status_lookup.get(`${g_idx}_${p_idx}`);
				if (new_val !== undefined) {
					pm.status = new_val;
				}
			});
		});
	}

	// totalPms = $derived(this.groups.reduce((sum, g) => sum + g.pms.length, 0));

	// // 提供一個方法讓使用者切換遠端點
	// async switchSource(newUrl) {
	// 	localStorage.setItem('pokemon_api_url', newUrl);
	// 	await this.init(); // 重新走一遍撈取流程
	// }
}

export const pokemonStore = new PokemonManager();

function infer_source_type(source_url = '') {
	return /\.csv(?:$|[?#])/i.test(source_url) ? 'csv' : 'json';
}

function get_source() {
	const source_url = get_item('config.source_url.url');
	const source_type = get_item('config.source_url.type');

	if (source_url && source_type) {
		return { url: source_url, type: source_type };
	}

	if (import.meta.env.VITE_PM_SOURCE_URL) {
		return {
			url: import.meta.env.VITE_PM_SOURCE_URL,
			type: import.meta.env.VITE_PM_SOURCE_TYPE || infer_source_type(import.meta.env.VITE_PM_SOURCE_URL),
		};
	}

	return DEFAULT_PM_DATA_SOURCE || LOCAL_PM_DATA_SOURCE;
}

async function fetch_pms_data() {
	const source = get_source();
	const response = await fetch(source.url);

	if (!response.ok) throw new Error('Network response was not ok');

	let raw_data;
	// Handle format based on file extension
	if (source.type === 'csv') {
		const text = await response.text();
		raw_data = csv2json(text);
	} else {
		raw_data = await response.json();
	}

	return handle_pms(raw_data);
}


function handle_pms(pms) {
	const names = raw_names.reduce((all, item) => {
		let { dex, ...name } = item;
		all[+dex] = name;
		return all;
	}, []);

	const today = new Date();

	const all_groups = new Map();
	const tags = {};
	const pid_with_tags = new Map();
	const status_length_by_family = new Map();

	let _fdex = 0;
	let _fcounter = 0;

	pms.filter(Boolean).forEach(pm => {
		const debut = (pm.debut || '').trim();
		const debut_timing = +(new Date(debut));
		const is_tombstone = debut && Number.isNaN(debut_timing);

		if (!is_tombstone && !(debut_timing < today)) {
			return;
		}

		// if (pm.family_dex !== '1' && pm.family_dex !== '422') {
		// 	return
		// }

		{ // get status index key
			if (_fdex === pm.family_dex) {
				_fcounter += 1;
			} else {
				_fdex = pm.family_dex;
				_fcounter = 1;
			}
			pm._gidx = Number(pm.family_dex);
			pm._pidx = Number(_fcounter - 1);
			// pm.key = `${pm.family_dex}.${_fcounter}`;
		}
		// Reserve the original family status position before tombstone rows are skipped.
		status_length_by_family.set(pm._gidx, Math.max(status_length_by_family.get(pm._gidx) || 0, pm._pidx + 1));

		if (is_tombstone) {
			return;
		}

		const dex = +(pm.pid.match(/pm(\d+)/)?.[1]);

		pm.dex = dex;
		pm.name = names[dex];
		// pm.time_order = debut_timing / 1000 + dex;
		pm.status = '0';

		{ // tags
			pm.tag = [...new Set(
					[
						`🧬gen${get_gen(dex) ?? 1}`,
						...(pm.tag || '').split(/\=/),
						...get_default_tags(pm.pid, dex)
					]
				)].filter(Boolean);

			// collect tags
			pm.tag.forEach(tag => {
				if (!tags[tag]) {
					tags[tag] = [];
				}
				tags[tag].push(pm.pid);
			});

			pid_with_tags.set(pm.pid, pm.tag);
		}

		{ // suffix, replace | to a newline
			if (pm.suffix) {
				pm.suffix = pm.suffix.replace(/\|/g, '\n');
			}
		}

		{ // grouping~
			const group_id = `${pm.family_dex}.${pm.group}`;
			if (!all_groups.has(group_id)) {
				// Initialize with an empty array if family not seen yet
				all_groups.set(group_id, []);
			}

			all_groups.get(group_id).push(pm);
		}
	});

	return {
		groups: Array.from(all_groups).sort(sort_by_group_id),
		tags,
		pid_with_tags,
		status_length_by_family,
	};
}

function get_gen(dex_num = 0) {
	get_gen._range = get_gen._range || [ 0, 151, 251, 386, 493, 649, 721, 809, 905, 1025, ];
	const index = get_gen._range.findIndex(limit => limit >= dex_num);
	if (index > 0) return index;
	// if dex error return undefined
}

function sort_by_group_id (a, b) {
	return a[0].localeCompare(b[0], undefined, {
		numeric: true,
		sensitivity: 'base' // Case-insensitive: "p" and "P" are treated the same
	});
};

function get_default_tags(pid = '', dex = 1) {
	let tags = [];
	// if (!tags.includes('costume')) {
	// 	tags.push('-costume');
	// }
	// if (!tags.includes('baby')) {
	// 	tags.push('-baby');
	// }
	switch (pid.split('.f')[1]) {
		case 'HISUIAN':
			tags.push('📍hisuian');
			break;
		case 'GALARIAN':
			tags.push('📍galarian');
			break;
		case 'ALOLA':
			tags.push('📍alola');
			break;
		case 'MEGA':
			tags.push('🏷️mega');
			break;
		case 'ORIGIN':
			tags.push('🏷️origin');
			break;
		case 'DYNAMAX':
			tags.push('🏷️dynamax');
			break;
		case 'GIGANTAMAX':
			tags.push('🏷️gigantamax');
			break;
		default:
			break;
	}

	switch (dex) {
		case 25:
		case 26:
		case 172:
			tags.push('🐣pika');
			break;
		case 201:
			tags.push('🐣unown');
			break;
		case 327:
			tags.push('🐣spinda');
			break;
		case 133:
		case 134:
		case 135:
		case 136:
		case 196:
		case 197:
		case 470:
		case 471:
		case 700:
			tags.push('🐣eevee');
			break;
		default:
			break;
	}

	return tags;
}

export function get_name(names, lang = 'en') {
	return names?.[lang] || names?.en || '';
}
