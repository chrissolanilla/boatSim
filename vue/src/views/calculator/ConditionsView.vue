<script setup>
import { useBoatSimStore } from '../../store/boatSim'

import SectionCard from '../../components/SectionCard.vue'
import MetricCard from '../../components/MetricCard.vue'
import InfoTip from '../../components/InfoTip.vue'
import NumberInput from '../../components/NumberInput.vue'

const store = useBoatSimStore()

const roughnessHelp =
	'Heuristic: roughness = wave height (ft) / wave period (sec). Higher values mean steeper, shorter-period chop.\n\nRule of thumb bands here: <0.30 manageable, 0.30-0.60 moderate, >=0.60 steep/rough.'

const airHelp =
	'This is guidance only. Hot + humid air is less dense and can reduce power vs a cool, dry baseline run.'

const waterHelp =
	'Based on roughness (height/period). Short period for a given height usually feels harsher than long rolling swell.'
</script>

<template>
	<h1 class="page-title">Conditions</h1>
	<p class="page-subtitle">This page is estimates and setup notes, not exact physics.</p>

	<div class="page-stack">
		<SectionCard title="Inputs" subtitle="Basic air and water conditions.">
			<NumberInput v-model="store.conditions.tempF" label="Air temp (F)" step="1" />
			<NumberInput v-model="store.conditions.humidity" label="Humidity (%)" step="1" />
			<NumberInput v-model="store.conditions.windSpeed" label="Wind speed (mph)" step="1" />
			<NumberInput v-model="store.conditions.waveHeight" label="Wave height (ft)" step="0.1" />
			<NumberInput v-model="store.conditions.wavePeriod" label="Wave period (sec)" step="0.1" />
		</SectionCard>

		<SectionCard title="Readout" subtitle="Use as guidance, not exact truth.">
			<div class="metric-stack narrow">
				<MetricCard
					label="Roughness"
					:value="store.roughness.toFixed(2)"
					:tone="store.roughnessTone"
					:help="roughnessHelp"
				/>
			</div>

			<div class="note" :class="store.weatherTone">
				<div class="note-head">
					<span>Air</span>
					<InfoTip :text="airHelp" />
				</div>
				<div class="note-body">{{ store.weatherMessage }}</div>
			</div>

			<div class="note" :class="store.waveTone">
				<div class="note-head">
					<span>Water</span>
					<InfoTip :text="waterHelp" />
				</div>
				<div class="note-body">{{ store.waveMessage }}</div>
			</div>
		</SectionCard>
	</div>
</template>

<style scoped>
.note {
	padding: 0.9rem 1rem;
	border-radius: 14px;
	background: rgba(255, 255, 255, 0.04);
	border: 1px solid rgba(255, 255, 255, 0.07);
	margin-bottom: 0.75rem;
	line-height: 1.5;
	color: var(--muted-text);
}

.note.good {
	border-color: rgba(63, 211, 140, 0.35);
}

.note.warn {
	border-color: rgba(255, 177, 74, 0.35);
}

.note.bad {
	border-color: rgba(255, 110, 122, 0.35);
}

.note-head {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 0.75rem;
	margin-bottom: 0.35rem;
	color: rgba(255, 255, 255, 0.82);
	font-weight: 700;
}

.note-body {
	color: var(--muted-text);
}

.flex {
	display: flex;
	flex-direction: column;
    gap: 1rem;
}
</style>
