<script setup>
defineProps({
	title: { type: String, default: '' },
	subtitle: { type: String, default: '' }
})
</script>

<template>
	<section class="card">
		<div v-if="title" class="card-head">
			<h2>{{ title }}</h2>
			<p v-if="subtitle">{{ subtitle }}</p>
		</div>

		<div class="card-body">
			<slot />
		</div>
	</section>
</template>

<style lang="scss" scoped>
.card {
	min-width: 0;
	background: linear-gradient(180deg, var(--surface-color), var(--surface-color-2));
	border: 1px solid var(--border);
	border-radius: 22px;
	box-shadow: var(--shadow);
}

.card-head {
	padding: 1rem 1rem 0.5rem;
}

h2 {
	margin: 0;
	font-size: 1.1rem;
}

p {
	margin: 0.35rem 0 0;
	color: var(--muted-text);
	font-size: 0.92rem;
	line-height: 1.45;
}

.card-body {
	display: flex;
	flex-direction: column;
	gap: 0.75rem;
	padding: 1rem;
}

@media (max-width: 680px) {
	.card {
		border-radius: 18px;
	}

	.card-head,
	.card-body {
		padding-inline: 0.85rem;
	}
}
</style>
