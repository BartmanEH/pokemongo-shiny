<script>
	import { get_name, } from '@lib/pm.svelte.js';
	import { _, locale, } from 'svelte-i18n';
	import { config, } from '@/stores.js';

	let { pm, status, handle_click_pm, } = $props();

	let folder_path = import.meta.env.VITE_PM_IMAGE_BASE_URL
		|| (import.meta.env.DEV
			? `http://localhost:1111/new-imgs`
			: `https://cdn.jsdelivr.net/gh/PokeMiners/pogo_assets/Images/Pokemon%20-%20256x256/Addressable%20Assets`);

	let tags_class = pm.tag.map(tag => ` tag-${tag}`).join('');

	let src = get_pm_img_src(pm.pid, true, pm.src);
	let src0 = get_pm_img_src(pm.pid, false, pm.src /* TODO */ );

	function get_pm_img_src(pid = '', shiny = true, direct_src = '') {
		if (direct_src) {
			return direct_src;
		}
		return `${folder_path}/${pid}${shiny ? '.s' : ''}.icon.png`;
	}

	let title = `#${pm.dex} ${get_name(pm.name, $locale)} @${pm.debut}`

</script>

<button class="pm status-{status} {tags_class}"
	class:img_diff={$config.img_diff}
	data-index={pm.index}
	onclick={() => handle_click_pm(pm.index)}
	style="--group-order:{pm.order || 0};--dex-order:{pm.dex};"
	title={title}
>
	<div class="img-box"
		style="--w: 140%; --t:-30%; --l: -5%; {pm.style}"
	>
		<!--
		-->
		{#if $config.img_diff}
			<img
				width="96"
				height="96"
				src={src0}
				alt={pm.pid}
				loading="lazy"
			/>
		{/if}
		<img
			width="96"
			height="96"
			src={src}
			alt={pm.pid}
			loading="lazy"
		/>
	</div>


	<!--
	<div
		class="position:absolute bottom:5% right:5% pointer-events:none"
	>{status}</div>
	-->

	<div class="caption" hidden={!$config.show_name}>
		<div class="name">
			{get_name(pm.name, $locale)}

			{#if $config.show_suffix}
				<span>{pm.suffix}</span>
			{/if}
		</div>

		<div class="dex">
			#{pm.dex}
		</div>
	</div>
</button>

<style>
	img {
		font-family: inherit;
		position: relative;
		position: absolute;

		top: var(--t, -30%);
		left: var(--l, -5%);
		width: var(--w, 140%);

		height: auto;
		aspect-ratio: 1;
		max-width: unset;
		object-fit: fill;

		&::before {
			content: '';
			position: absolute;
			background-color: #ccc;
			inset: 0;
			box-shadow: inset 0 0 2px;
		}

		&::after {
			content: '\2639' '\A' attr(alt);
			position: absolute;
			inset: 0;
			z-index: 2;
			white-space: pre-wrap;
			place-content: center;
			text-align: center;
		}
	}

	.img-box {
		position: absolute;
		inset: 0;
		border-radius: inherit;
		overflow: hidden;

		img {
			display: block;
		}

		img + img {
			transition: opacity 0.3s;
		}

		&::after {
			content: '';
			position: absolute;
			inset: 0;
			pointer-events: none;
			box-shadow: inset 0 0 0 1px #ddd;
			border-radius: inherit;
			background-size: 100% 75%;
			background-repeat: no-repeat;
			opacity: 0;
			color: var(--main-bgc);
			transition: opacity 1s;
			background-image: linear-gradient(currentcolor, #0000);
		}
		.pm:not(.img_diff):hover &::after {
			opacity: .8;
		}
	}

	.pm {
		break-inside: avoid;
		background-color: var(--main-bgc);
		width: var(--pm-grid-size, 96px);
		height: var(--pm-grid-size, 96px);
		order: var(--group-order);

		@media (max-width: 768px) {
			width: calc(var(--pm-grid-size) * .75);
			height: calc(var(--pm-grid-size) * .75);
		}
	}

	.pm:hover .name {
		opacity: 1;
	}
	.pm:hover .dex {
		opacity: 0.5;
	}

	.caption {
		position: absolute;
		z-index: 15;
		left: 2.5%;
		top: 1%;
		padding: .3em .25em;
		transition: opacity 0.3s;
		pointer-events: none;
	}

	.name {
		font-size: 10px;
		opacity: 0.4;
		transition: opacity 0.3s;

		@media (max-width: 768px) {
			font-size: 12px;
		}

		span {
			white-space: pre-wrap;
		}
	}

	.dex {
		text-align: start;
		font-size: 10px;
		opacity: 0;
		transition: opacity .3s;
	}

	.img_diff:hover {
		& .caption {
			opacity: 0;
		}

		& img + img {
			opacity: 0;
		}
	}
</style>
