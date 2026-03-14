<script>
	import Item from '@comp/Item.svelte';
	import Head from '@comp/Head.svelte';
	import Tag from '@comp/Tag.svelte';
	import Footer from '@comp/Footer.svelte';

	import { recorder, } from '@lib/recorder.svelte.js';
	import { pm_data, } from '@lib/pm.svelte.js';
	import { get_item, set_item, } from '@lib/u.js';
	import { _, } from 'svelte-i18n';
	import { status, name, config, } from '@/stores.js';

	let { groups, pms, max_index, } = pm_data;

	let status_map = $state(
		fill_status($status)
	);

	status.subscribe((_status) => {
		status_map = fill_status(_status);
	});

	let status_string = $derived(status_map.join(''));

	let status_counter = $derived.by(() => {
		// Dataset indices are sparse, so count only actual released rows.
		return pms.reduce((all, pm) => {
			let s = Number(status_map[pm.index] || 0);
			all[s] = (all[s] || 0) + 1;
			return all;
		}, [0, 0, 0, 0]);
	});

	const status_visibility = $state(get_item('status_visibility') || [true, true, true, true,]);
	const status_visibility_class = $derived.by(
		() => status_visibility.map(
			(i, index) => i ? `visible-status-${index}` : ''
		).join(' ')
	);
	const visible_groups = $derived.by(() => groups.filter(group =>
		group.pms.some(pm => status_visibility[Number(status_map[pm.index] || 0)])
	));

	$effect(() => {
	  set_item('status_visibility', $state.snapshot(status_visibility));
	});

	// // hacky trigger
	// if ($status !== status_string) {
	// 	status.set(status_string);
	// }

	function handle_click_pm(index = 0) {
		let s = Number(status_map[index] || 0);
		let new_status = (1 + s) % 4;
		status_map[index] = new_status;
		status.set(status_string);
		// console.log('handle_click_pm', {index, new_status});
	}

	function before_unload(event) {
		if (recorder.records?.[0].status !== status_string) {
			console.log(recorder.records?.[0].status);
			console.log(status_string);
			event.preventDefault();
	    event.returnValue = '';
		}
	}

	function fill_status(_status) {
		return _status.slice(0, max_index + 1).padEnd(max_index + 1, '0').split('');
	}

</script>

<svelte:window on:beforeunload={before_unload}/>

<div class="workspace min-height:100svh" id="workspace"
	style="
		--pm-grid-color0:{$config.grid_colors[0]};
		--pm-grid-color1:{$config.grid_colors[1]};
		--pm-grid-color2:{$config.grid_colors[2]};
		--pm-grid-size:{$config.grid_size}px;
		--main-bgc:{$config.main_bgc};
		--main-color:{$config.main_color};
		--max-width:{$config.maxwidth}px;
	"
>
	<Head
		{status_counter}
		{status_visibility}
	/>

	<div class="margin:0|auto|2.5em">
		<Tag />
	</div>

	<input type="checkbox" id="list-locker" class="sr-only-u" bind:checked={$config.locked} />
	<main class="pm-list display:flex flex-wrap:wrap place-content:center margin:0|auto padding:0|3vw|3em
		max-width:{$config.maxwidth}
		{status_visibility_class}"
	>
		{#each visible_groups as group, index}
			<div class="pm-group position:relative display:flex flex-wrap:wrap place-content:center gap:.5em">
				<!--
				<div class="position:absolute color:#0003">
					{group.label}
				</div>
				-->

				{#each group.pms as pm}
					<Item {pm} status={status_map[pm.index]} {handle_click_pm} />
				{/each}

			</div>
		{/each}
	</main>

	<Footer />
</div>



<style>
.workspace {
	color: var(--main-color);
	background-color: var(--main-bgc);
}
#list-locker:checked + .pm-list {
	pointer-events: none;
}

.pm-list {
	gap: calc(var(--pm-grid-size) * .25);

	&:not(.visible-status-0) :global(.pm.status-0),
	&:not(.visible-status-1) :global(.pm.status-1),
	&:not(.visible-status-2) :global(.pm.status-2),
	&:not(.visible-status-3) :global(.pm.status-3) {
		display: none;
	}
}

.pm-group {
	/* content-visibility: auto; */
	/* contain-intrinsic-size: 300px; */
}

</style>
