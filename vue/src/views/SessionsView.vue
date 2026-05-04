<script setup>
import SectionCard from '../components/SectionCard.vue'
</script>

<template>
	<h1 class="page-title">Sessions</h1>
	<p class="page-subtitle">
		This will become the place for setup notes, logged runs, and CSV export.
	</p>

	<div class="page-stack">
		<SectionCard title="Session log" subtitle="Planned for real run data, not guessed setup claims.">
			<div class="empty-state">
				<p>No sessions recorded yet.</p>
				<p>
					Future logs should save the raw inputs, calculated slip, conditions, and crew notes so
					advice can be based on GC Racing runs instead of fake precision.
				</p>
			</div>
		</SectionCard>
	</div>
</template>

<style scoped>
.empty-state {
	display: flex;
	flex-direction: column;
	gap: 0.65rem;
	padding: 1rem;
	border-radius: 16px;
	border: 1px dashed rgba(255, 255, 255, 0.18);
	background: rgba(255, 255, 255, 0.03);
	color: var(--muted-text);
	line-height: 1.5;
}

p {
	margin: 0;
}
</style>
