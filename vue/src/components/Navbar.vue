<script setup>
import { RouterLink, useRoute } from 'vue-router'

const route = useRoute()

const links = [
	{ to: '/', label: 'Home' },
	{ to: '/calculator/prop-slip', label: 'Prop Slip' },
	{ to: '/calculator/fuel', label: 'Fuel' },
	{ to: '/calculator/conditions', label: 'Conditions' },
	{ to: '/sessions', label: 'Sessions' }
]
</script>

<template>
	<nav class="nav">
		<div class="brand">
			<div class="brand-mark" />
			<div>
				<h1>Boat Sim</h1>
			</div>
		</div>

		<div class="nav-links">
			<RouterLink
				v-for="link in links"
				:key="link.to"
				:to="link.to"
				:class="{ active: route.path === link.to }"
			>
				{{ link.label }}
			</RouterLink>
		</div>
	</nav>
</template>

<style lang="scss" scoped>
h1 {
	margin: 0;
}

nav {
	background-color: var(--secondary-color);
	text-align: center;
	padding: 0.5rem;
    //-webkit-text-stroke: 0.5px black;

}

.nav-links {
	display: flex;
	gap: 1rem;
	justify-content: center;
	font-weight: 500;
}

.active {
	text-decoration: underline;
	text-underline-offset: 0.25em;
}
</style>
